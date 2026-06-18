//
//  FSDiscoverView.swift
//  Feather
//
//  The store front: every app from the user's catalogs in one
//  friendly, browsable place.
//

import SwiftUI
import CoreData
import AltSourceKit
import NukeUI

// MARK: - View
struct FSDiscoverView: View {
	@StateObject private var _viewModel = SourcesViewModel.shared

	@State private var _searchText = ""
	@State private var _selectedSourceID: NSManagedObjectID?
	@State private var _selectedApp: FSDiscoverApp?
	@State private var _isCatalogManagerPresenting = false

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	// MARK: Body
	var body: some View {
		NavigationStack {
			Group {
				if _sources.isEmpty {
					FSEmptyStateView(
						systemImage: "sparkles",
						title: .localized("Nothing here yet"),
						message: .localized("Add an app catalog and every app it offers will show up right here."),
						actionTitle: .localized("Add a Catalog")
					) {
						_isCatalogManagerPresenting = true
					}
				} else if _allApps.isEmpty {
					_loadingState
				} else {
					_storeFront
				}
			}
			.navigationTitle(.localized("Discover"))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						_isCatalogManagerPresenting = true
					} label: {
						Image(systemName: "square.grid.2x2")
					}
					.accessibilityLabel(.localized("Manage Catalogs"))
				}
			}
			.searchable(text: $_searchText, prompt: .localized("Search apps"))
			.refreshable {
				await _viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(item: $_selectedApp) { entry in
				FSAppDetailView(source: entry.source, app: entry.app)
			}
			.sheet(isPresented: $_isCatalogManagerPresenting) {
				FSCatalogManagerView()
			}
		}
		.task(id: Array(_sources)) {
			await _viewModel.fetchSources(_sources)
		}
	}

	// MARK: Store front
	@ViewBuilder
	private var _storeFront: some View {
		ScrollView {
			LazyVStack(spacing: 24) {
				if _searchText.isEmpty {
					if !_featuredApps.isEmpty {
						_featuredCarousel
					}
					_catalogChips
				}

				LazyVStack(spacing: 4) {
					if !_searchText.isEmpty {
						FSSectionHeader(
							title: .localized("Results"),
							subtitle: .localized("%lld apps", arguments: _filteredApps.count)
						)
						.padding(.horizontal, 20)
						.padding(.bottom, 6)
					}

					ForEach(_filteredApps) { entry in
						FSDiscoverRowView(entry: entry) {
							_selectedApp = entry
						}
					}
				}

				Color.clear.frame(height: 24)
			}
			.padding(.top, 8)
		}
		.scrollDismissesKeyboard(.interactively)
		.overlay {
			if !_searchText.isEmpty && _filteredApps.isEmpty {
				FSEmptyStateView(
					systemImage: "magnifyingglass",
					title: .localized("No matches"),
					message: .localized("Nothing in your catalogs is called “%@”.", arguments: _searchText)
				)
			}
		}
	}

	@ViewBuilder
	private var _loadingState: some View {
		VStack(spacing: 14) {
			ProgressView()
			Text(.localized("Loading your catalogs…"))
				.font(.system(.subheadline, design: .rounded).weight(.medium))
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	// MARK: Featured
	@ViewBuilder
	private var _featuredCarousel: some View {
		VStack(spacing: 12) {
			FSSectionHeader(
				title: .localized("Featured"),
				subtitle: .localized("Hand-picked from your catalogs")
			)
			.padding(.horizontal, 20)

			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 14) {
					ForEach(_featuredApps) { entry in
						FSFeaturedCardView(entry: entry) {
							_selectedApp = entry
						}
					}
				}
				.padding(.horizontal, 20)
			}
		}
	}

	// MARK: Catalog filter
	@ViewBuilder
	private var _catalogChips: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				_chip(title: .localized("All Apps"), isSelected: _selectedSourceID == nil) {
					_selectedSourceID = nil
				}

				ForEach(_sources, id: \.objectID) { source in
					_chip(
						title: source.name ?? .localized("Catalog"),
						isSelected: _selectedSourceID == source.objectID
					) {
						_selectedSourceID = _selectedSourceID == source.objectID ? nil : source.objectID
					}
				}
			}
			.padding(.horizontal, 20)
		}
	}

	@ViewBuilder
	private func _chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
		Button {
			FSTheme.lightImpact()
			withAnimation(.snappy) { action() }
		} label: {
			Text(title)
				.font(.system(.subheadline, design: .rounded).weight(.semibold))
				.foregroundStyle(isSelected ? Color.white : Color.primary)
				.padding(.horizontal, 14)
				.padding(.vertical, 7)
				.background(
					Capsule().fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
				)
		}
		.buttonStyle(.plain)
	}

	// MARK: Data
	private var _allApps: [FSDiscoverApp] {
		_sources.flatMap { source -> [FSDiscoverApp] in
			guard let repo = _viewModel.sources[source] else { return [] }
			return repo.apps.map {
				FSDiscoverApp(sourceID: source.objectID, source: repo, app: $0)
			}
		}
	}

	private var _filteredApps: [FSDiscoverApp] {
		var apps = _allApps

		if let selected = _selectedSourceID, _searchText.isEmpty {
			apps = apps.filter { $0.sourceID == selected }
		}

		guard !_searchText.isEmpty else { return apps }

		return apps.filter {
			$0.app.currentName.localizedCaseInsensitiveContains(_searchText)
				|| ($0.app.currentDescription?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	/// Sources can flag featured apps; otherwise the first app of
	/// each catalog gets the spotlight.
	private var _featuredApps: [FSDiscoverApp] {
		var featured: [FSDiscoverApp] = []

		for source in _sources {
			guard let repo = _viewModel.sources[source] else { continue }

			if let ids = repo.featuredApps, !ids.isEmpty {
				let apps = repo.apps
					.filter { ids.contains($0.id) }
					.prefix(2)
					.map { FSDiscoverApp(sourceID: source.objectID, source: repo, app: $0) }
				featured.append(contentsOf: apps)
			} else if let first = repo.apps.first {
				featured.append(FSDiscoverApp(sourceID: source.objectID, source: repo, app: first))
			}
		}

		return Array(featured.prefix(8))
	}
}

// MARK: - Model
struct FSDiscoverApp: Identifiable {
	let sourceID: NSManagedObjectID
	let source: ASRepository
	let app: ASRepository.App

	var id: String { "\(sourceID).\(app.currentUniqueId)" }
}

// MARK: - Row
struct FSDiscoverRowView: View {
	let entry: FSDiscoverApp
	let onTap: () -> Void

	var body: some View {
		HStack(spacing: 14) {
			Button(action: onTap) {
				HStack(spacing: 14) {
					FSRemoteAppIconView(url: entry.app.iconURL, size: 58)

					VStack(alignment: .leading, spacing: 2) {
						Text(entry.app.currentName)
							.font(.system(.body, design: .rounded).weight(.semibold))
							.foregroundStyle(.primary)
							.lineLimit(1)
						Text(entry.app.currentDescription ?? .localized("An awesome application"))
							.font(.footnote)
							.foregroundStyle(.secondary)
							.lineLimit(2)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)

			FSGetButton(app: entry.app)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 8)
	}
}

// MARK: - Featured card
struct FSFeaturedCardView: View {
	let entry: FSDiscoverApp
	let onTap: () -> Void

	private var _tint: Color {
		entry.app.tintColor ?? entry.source.tintColor ?? FSTheme.accent
	}

	var body: some View {
		Button(action: onTap) {
			VStack(alignment: .leading, spacing: 0) {
				Spacer(minLength: 0)

				HStack(spacing: 12) {
					FSRemoteAppIconView(url: entry.app.iconURL, size: 52)

					VStack(alignment: .leading, spacing: 1) {
						Text(entry.app.currentName)
							.font(.system(.headline, design: .rounded).weight(.bold))
							.foregroundStyle(.white)
							.lineLimit(1)
						Text(entry.app.currentDescription ?? entry.source.name ?? "")
							.font(.caption)
							.foregroundStyle(.white.opacity(0.85))
							.lineLimit(1)
					}
					.frame(maxWidth: .infinity, alignment: .leading)

					FSGetButton(app: entry.app)
				}
				.padding(14)
				.background(.black.opacity(0.18))
			}
			.frame(width: 290, height: 160)
			.background(
				LinearGradient(
					colors: [_tint, _tint.opacity(0.62)],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
			.overlay(alignment: .topLeading) {
				Text(entry.source.name ?? .localized("Featured"))
					.font(.system(.caption2, design: .rounded).weight(.bold))
					.textCase(.uppercase)
					.foregroundStyle(.white.opacity(0.9))
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(Capsule().fill(.white.opacity(0.2)))
					.padding(12)
			}
			.clipShape(RoundedRectangle(cornerRadius: FSTheme.cardCornerRadius, style: .continuous))
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Remote icon
struct FSRemoteAppIconView: View {
	let url: URL?
	var size: CGFloat = 56

	var body: some View {
		if let url {
			LazyImage(url: url) { state in
				if let image = state.image {
					image.appIconStyle(size: size)
				} else {
					Image("App_Unknown").appIconStyle(size: size)
				}
			}
		} else {
			Image("App_Unknown").appIconStyle(size: size)
		}
	}
}
