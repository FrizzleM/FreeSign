//
//  FSMyAppsView.swift
//  Feather
//
//  The user's personal shelf: downloaded apps waiting to be
//  installed and apps FreeSign has already prepared.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct FSMyAppsView: View {
	@Binding var selectedTab: FSRootView.Tab

	@StateObject private var _downloadManager = DownloadManager.shared

	@State private var _searchText = ""
	@State private var _quickInstallApp: AnyApp?
	@State private var _customizeApp: AnyApp?
	@State private var _installPresenting: AnyApp?
	@State private var _infoApp: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isImportFromURLPresenting = false
	@State private var _importURLString = ""

	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>

	private var _filteredImported: [Imported] {
		_importedApps.filter {
			_searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	private var _filteredSigned: [Signed] {
		_signedApps.filter {
			_searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			Group {
				if _signedApps.isEmpty && _importedApps.isEmpty {
					FSEmptyStateView(
						systemImage: "square.stack.3d.up.slash",
						title: .localized("No apps yet"),
						message: .localized("Apps you get from Discover or add yourself will live here, ready to install."),
						actionTitle: .localized("Browse Discover")
					) {
						selectedTab = .discover
					}
				} else {
					_shelf
				}
			}
			.navigationTitle(.localized("My Apps"))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Menu {
						Button(.localized("From Files"), systemImage: "folder") {
							_isImportingPresenting = true
						}
						Button(.localized("From a Link"), systemImage: "link") {
							_isImportFromURLPresenting = true
						}
					} label: {
						Image(systemName: "plus")
					}
					.accessibilityLabel(.localized("Add App"))
				}
			}
			.searchable(text: $_searchText, prompt: .localized("Search your apps"))
			.scrollDismissesKeyboard(.interactively)
			.sheet(item: $_quickInstallApp) { app in
				FSQuickInstallSheet(app: app.base) {
					_customizeApp = app
				}
				.presentationDetents([.height(420)])
				.presentationDragIndicator(.visible)
			}
			.sheet(item: $_installPresenting) { app in
				FSInstallProgressView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(300)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_customizeApp) { app in
				SigningView(app: app.base)
			}
			.sheet(item: $_infoApp) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }

						for url in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = _downloadManager.startArchive(from: url, id: id)
							try? _downloadManager.handlePachageFile(url: url, dl: dl)
						}
					}
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Add from a Link"), isPresented: $_isImportFromURLPresenting) {
				TextField(.localized("https://example.com/app.ipa"), text: $_importURLString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) {
					_importURLString = ""
				}
				Button(.localized("Add")) {
					if let url = URL(string: _importURLString) {
						_ = _downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
					_importURLString = ""
				}
			} message: {
				Text(.localized("Paste a direct link to an app file (.ipa) and FreeSign will download it for you."))
			}
		}
	}

	// MARK: Shelf
	@ViewBuilder
	private var _shelf: some View {
		ScrollView {
			LazyVStack(spacing: 24) {
				if !_filteredImported.isEmpty {
					VStack(spacing: 10) {
						FSSectionHeader(
							title: .localized("Ready to Install"),
							subtitle: .localized("One tap and they're on your Home Screen")
						)
						.padding(.horizontal, 20)

						ForEach(_filteredImported, id: \.uuid) { app in
							FSMyAppCardView(
								app: app,
								primaryActionTitle: .localized("Install"),
								primaryAction: { _quickInstallApp = AnyApp(base: app) },
								menu: { _importedMenu(for: app) }
							)
							.padding(.horizontal, 20)
						}
					}
				}

				if !_filteredSigned.isEmpty {
					VStack(spacing: 10) {
						FSSectionHeader(
							title: .localized("Installed"),
							subtitle: .localized("Prepared by FreeSign for this device")
						)
						.padding(.horizontal, 20)

						ForEach(_filteredSigned, id: \.uuid) { app in
							FSMyAppCardView(
								app: app,
								primaryActionTitle: .localized("Open"),
								primaryAction: { UIApplication.openApp(with: app.identifier ?? "") },
								menu: { _signedMenu(for: app) }
							)
							.padding(.horizontal, 20)
						}
					}
				}

				Color.clear.frame(height: 24)
			}
			.padding(.top, 8)
		}
	}

	// MARK: Menus
	@ViewBuilder
	private func _importedMenu(for app: AppInfoPresentable) -> some View {
		Button(.localized("Install"), systemImage: "arrow.down.circle") {
			_quickInstallApp = AnyApp(base: app)
		}
		Button(.localized("Customize & Install"), systemImage: "slider.horizontal.3") {
			_customizeApp = AnyApp(base: app)
		}
		Button(.localized("App Info"), systemImage: "info.circle") {
			_infoApp = AnyApp(base: app)
		}
		Divider()
		Button(.localized("Remove"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}

	@ViewBuilder
	private func _signedMenu(for app: AppInfoPresentable) -> some View {
		if let id = app.identifier {
			Button(.localized("Open"), systemImage: "arrow.up.forward.app") {
				UIApplication.openApp(with: id)
			}
		}
		Button(.localized("Reinstall"), systemImage: "arrow.down.circle") {
			_installPresenting = AnyApp(base: app)
		}
		Button(.localized("Prepare Again"), systemImage: "sparkles") {
			_customizeApp = AnyApp(base: app)
		}
		Button(.localized("Save a Copy"), systemImage: "square.and.arrow.up") {
			_installPresenting = AnyApp(base: app, archive: true)
		}
		Button(.localized("App Info"), systemImage: "info.circle") {
			_infoApp = AnyApp(base: app)
		}
		Divider()
		Button(.localized("Remove"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
}

// MARK: - App card
struct FSMyAppCardView: View {
	var app: AppInfoPresentable
	let primaryActionTitle: String
	let primaryAction: () -> Void
	@ViewBuilder let menu: () -> AnyView

	init(
		app: AppInfoPresentable,
		primaryActionTitle: String,
		primaryAction: @escaping () -> Void,
		@ViewBuilder menu: @escaping () -> some View
	) {
		self.app = app
		self.primaryActionTitle = primaryActionTitle
		self.primaryAction = primaryAction
		self.menu = { AnyView(menu()) }
	}

	private var _certInfo: Date.ExpirationInfo? {
		Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
	}

	private var _certRevoked: Bool {
		Storage.shared.getCertificate(from: app)?.revoked == true
	}

	var body: some View {
		HStack(spacing: 14) {
			FRAppIconView(app: app, size: 58)

			VStack(alignment: .leading, spacing: 3) {
				Text(app.name ?? .localized("Unknown"))
					.font(.system(.body, design: .rounded).weight(.semibold))
					.lineLimit(1)

				if let version = app.version {
					Text(verbatim: .localized("Version %@", arguments: version))
						.font(.footnote)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				if app.isSigned {
					if _certRevoked {
						FSStatusPill(
							text: .localized("Needs a new pass"),
							color: .red,
							icon: "exclamationmark.triangle.fill"
						)
					} else if let info = _certInfo {
						FSStatusPill(
							text: info.formatted,
							color: info.color,
							icon: "checkmark.seal.fill"
						)
					}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			Button {
				FSTheme.lightImpact()
				primaryAction()
			} label: {
				Text(primaryActionTitle)
			}
			.buttonStyle(FSCapsuleButtonStyle(filled: !app.isSigned))
		}
		.fsCard(padding: 14)
		.contextMenu { menu() }
	}
}
