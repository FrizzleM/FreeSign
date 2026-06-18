//
//  FSCatalogManagerView.swift
//  Feather
//
//  Manage app catalogs (sources): add by link, one-tap add of
//  recommended catalogs, and removal of existing ones.
//

import SwiftUI
import AltSourceKit
import NimbleJSON
import NukeUI
import OSLog

// MARK: - View
struct FSCatalogManagerView: View {
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	@Environment(\.dismiss) private var dismiss

	private let _dataService = NBFetchService()

	@State private var _catalogURL = ""
	@State private var _isAdding = false
	@State private var _recommended: [(url: URL, data: ASRepository)] = []

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	let recommendedSources: [URL] = [
		"https://raw.githubusercontent.com/FrizzleM/FreeSign/refs/heads/main/app-repo.json",
		"https://raw.githubusercontent.com/Aidoku/Aidoku/altstore/apps.json",
		"https://github.com/chachillie/Flycast-iOS/raw/main/flycast-ios.json",
		"https://xitrix.github.io/iTorrent/AltStore.json",
		"https://altstore.oatmealdome.me/",
		"https://raw.githubusercontent.com/LiveContainer/LiveContainer/refs/heads/main/apps.json",
		"https://pokemmo.com/altstore",
		"https://provenance-emu.com/apps.json",
		"https://community-apps.sidestore.io/sidecommunity.json",
		"https://alt.getutm.app",
		"https://raw.githubusercontent.com/paigely/Navic/refs/heads/master/app-repo.json",
		"https://stikdebug.xyz/index.json",
		"https://apps.manicemu.site/altstore",
		"https://alt.crystall1ne.dev"
	].map { URL(string: $0)! }

	// MARK: Body
	var body: some View {
		NavigationStack {
			Form {
				Section {
					HStack(spacing: 10) {
						TextField(.localized("Paste a catalog link"), text: $_catalogURL)
							.keyboardType(.URL)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()

						if _isAdding {
							ProgressView()
						} else {
							Button {
								_addCatalog()
							} label: {
								Image(systemName: "plus.circle.fill")
									.font(.title3)
							}
							.disabled(_catalogURL.isEmpty)
						}
					}
				} header: {
					Text(.localized("Add a Catalog"))
				} footer: {
					Text(.localized("Catalogs are public lists of apps (AltStore format). Paste a link and its apps appear in Discover."))
				}

				if !_filteredRecommended.isEmpty {
					Section {
						ForEach(_filteredRecommended, id: \.url) { (url, repo) in
							HStack(spacing: 12) {
								_catalogIcon(repo.currentIconURL)

								VStack(alignment: .leading, spacing: 1) {
									Text(repo.name ?? .localized("Unknown"))
										.font(.system(.subheadline, design: .rounded).weight(.semibold))
										.lineLimit(1)
									Text(verbatim: .localized("%lld apps", arguments: repo.apps.count))
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								.frame(maxWidth: .infinity, alignment: .leading)

								Button {
									FSTheme.lightImpact()
									Storage.shared.addSource(url, repository: repo) { _ in }
								} label: {
									Text(.localized("Add"))
								}
								.buttonStyle(FSCapsuleButtonStyle())
							}
						}
					} header: {
						Text(.localized("Popular Catalogs"))
					}
				}

				if !_sources.isEmpty {
					Section {
						ForEach(_sources, id: \.objectID) { source in
							HStack(spacing: 12) {
								_catalogIcon(source.iconURL)

								VStack(alignment: .leading, spacing: 1) {
									Text(source.name ?? .localized("Catalog"))
										.font(.system(.subheadline, design: .rounded).weight(.semibold))
										.lineLimit(1)
									Text(source.sourceURL?.host ?? "")
										.font(.caption)
										.foregroundStyle(.secondary)
										.lineLimit(1)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
							}
							.swipeActions {
								Button(role: .destructive) {
									Storage.shared.deleteSource(for: source)
								} label: {
									Label(.localized("Remove"), systemImage: "trash")
								}
							}
						}
					} header: {
						Text(.localized("Your Catalogs"))
					} footer: {
						Text(.localized("Swipe left on a catalog to remove it. Your downloaded apps stay in My Apps."))
					}
				}
			}
			.navigationTitle(.localized("Catalogs"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button(.localized("Done")) { dismiss() }
						.fontWeight(.semibold)
				}
			}
			.task {
				await _fetchRecommended()
			}
		}
	}

	private var _filteredRecommended: [(url: URL, data: ASRepository)] {
		_recommended
			.filter { (url, repo) in
				!Storage.shared.sourceExists(repo.id ?? url.absoluteString)
			}
			.sorted {
				($0.data.name ?? "").localizedCaseInsensitiveCompare($1.data.name ?? "") == .orderedAscending
			}
	}

	@ViewBuilder
	private func _catalogIcon(_ url: URL?) -> some View {
		if let url {
			LazyImage(url: url) { state in
				if let image = state.image {
					image.appIconStyle(size: 38)
				} else {
					Image("App_Unknown").appIconStyle(size: 38)
				}
			}
		} else {
			Image("App_Unknown").appIconStyle(size: 38)
		}
	}

	// MARK: Actions
	private func _addCatalog() {
		guard !_catalogURL.isEmpty else { return }
		_isAdding = true

		FR.handleSource(_catalogURL) {
			_isAdding = false
			_catalogURL = ""
		}
	}

	private func _fetchRecommended() async {
		var results: [(url: URL, data: ASRepository)] = []
		let dataService = _dataService

		await withTaskGroup(of: Void.self) { group in
			for url in recommendedSources {
				group.addTask {
					await withCheckedContinuation { continuation in
						dataService.fetch<ASRepository>(from: url) { (result: RepositoryDataHandler) in
							switch result {
							case .success(let repo):
								Task { @MainActor in
									results.append((url: url, data: repo))
								}
							case .failure(let error):
								Logger.misc.error("Failed to fetch \(url): \(error.localizedDescription)")
							}
							continuation.resume()
						}
					}
				}
			}
			await group.waitForAll()
		}

		await MainActor.run {
			_recommended = results
		}
	}
}
