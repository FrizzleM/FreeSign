//
//  FSPassesView.swift
//  Feather
//
//  "Signing Passes" — the consumer face of certificates. Same
//  storage, same selection index, same WSF refresh pipeline.
//

import SwiftUI
import CoreData

// MARK: - View
struct FSPassesView: View {
	@AppStorage("feather.selectedCert") private var _selectedCertIndex: Int = 0

	@State private var _isImportPresenting = false
	@State private var _isRefreshing = false
	@State private var _infoCert: CertificatePair?
	@State private var _certToRename: CertificatePair?
	@State private var _isRenamePresenting = false
	@State private var _newNickname = ""

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	// MARK: Body
	var body: some View {
		Group {
			if _certificates.isEmpty {
				FSEmptyStateView(
					systemImage: "checkmark.seal",
					title: .localized("No passes yet"),
					message: .localized("A signing pass is what lets FreeSign prepare apps for your iPhone. Fetch the free ones to get going."),
					actionTitle: .localized("Fetch Free Passes")
				) {
					_refreshPasses()
				}
			} else {
				ScrollView {
					LazyVStack(spacing: 12) {
						Text(.localized("A pass lets FreeSign prepare apps so your iPhone accepts them. The selected pass is used every time you install."))
							.font(.footnote)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
							.padding(.horizontal, 4)

						ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
							FSPassCardView(
								cert: cert,
								isSelected: index == _selectedCertIndex
							) {
								FSTheme.lightImpact()
								_selectedCertIndex = index
							}
							.contextMenu {
								_passMenu(for: cert)
							}
						}

						Color.clear.frame(height: 20)
					}
					.padding(20)
				}
				.background(Color(uiColor: .systemGroupedBackground))
			}
		}
		.navigationTitle(.localized("Signing Passes"))
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				if _isRefreshing {
					ProgressView()
				} else {
					Menu {
						Button(.localized("Get Fresh Passes"), systemImage: "arrow.clockwise") {
							_refreshPasses()
						}
						Button(.localized("Add Your Own…"), systemImage: "plus") {
							_isImportPresenting = true
						}
					} label: {
						Image(systemName: "ellipsis.circle")
					}
				}
			}
		}
		.sheet(isPresented: $_isImportPresenting) {
			FSImportPassView()
				.presentationDetents([.medium])
		}
		.sheet(item: $_infoCert) { cert in
			CertificatesInfoView(cert: cert)
		}
		.alert(.localized("Rename Pass"), isPresented: $_isRenamePresenting, presenting: _certToRename) { cert in
			TextField(.localized("Name"), text: $_newNickname)
			Button(.localized("Cancel"), role: .cancel) { }
			Button(.localized("Save")) {
				cert.nickname = _newNickname.isEmpty ? nil : _newNickname
				Storage.shared.saveContext()
			}
		}
	}

	// MARK: Menu
	@ViewBuilder
	private func _passMenu(for cert: CertificatePair) -> some View {
		Button(.localized("Details"), systemImage: "info.circle") {
			_infoCert = cert
		}
		Button(.localized("Rename"), systemImage: "pencil") {
			_newNickname = cert.nickname ?? ""
			_certToRename = cert
			_isRenamePresenting = true
		}
		Button(.localized("Check if Still Valid"), systemImage: "checkmark.seal") {
			Storage.shared.revokagedCertificate(for: cert)
		}
		if cert.isDefault != true {
			Divider()
			Button(.localized("Remove"), systemImage: "trash", role: .destructive) {
				Storage.shared.deleteCertificate(for: cert)
			}
		}
	}

	// MARK: Refresh
	private func _refreshPasses() {
		guard !_isRefreshing else { return }
		_isRefreshing = true

		Task { @MainActor in
			do {
				let importedCount = try await DefaultCertificateInstaller.shared.install(replacingExistingDefaults: true)
				_isRefreshing = false
				FSTheme.success()

				UIAlertController.showAlertWithOk(
					title: .localized("You're all set"),
					message: .localized("Fetched %d fresh signing passes.", arguments: importedCount)
				)
			} catch {
				_isRefreshing = false
				FSTheme.failure()

				UIAlertController.showAlertWithOk(
					title: .localized("Couldn't fetch passes"),
					message: error.localizedDescription
				)
			}
		}
	}
}

// MARK: - Pass card
struct FSPassCardView: View {
	@ObservedObject var cert: CertificatePair
	let isSelected: Bool
	let onSelect: () -> Void

	@State private var _decoded: Certificate?

	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 14) {
				ZStack {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(FSTheme.accentGradient)
						.frame(width: 46, height: 46)
					Image(systemName: "checkmark.seal.fill")
						.font(.title3)
						.foregroundStyle(.white)
				}

				VStack(alignment: .leading, spacing: 3) {
					Text(_title)
						.font(.system(.body, design: .rounded).weight(.semibold))
						.foregroundStyle(.primary)
						.lineLimit(1)

					Text(_decoded?.TeamName ?? _decoded?.AppIDName ?? .localized("Signing pass"))
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)

					HStack(spacing: 6) {
						if cert.revoked {
							FSStatusPill(
								text: .localized("No longer valid"),
								color: .red,
								icon: "xmark.octagon.fill"
							)
						} else if let info = cert.expiration?.expirationInfo() {
							FSStatusPill(
								text: info.formatted,
								color: info.color,
								icon: info.icon
							)
						}
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.title3)
					.foregroundStyle(isSelected ? Color.accentColor : Color(uiColor: .tertiaryLabel))
			}
			.fsCard(padding: 14)
			.overlay(
				RoundedRectangle(cornerRadius: FSTheme.cardCornerRadius, style: .continuous)
					.strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
			)
		}
		.buttonStyle(.plain)
		.onAppear {
			_decoded = Storage.shared.getProvisionFileDecoded(for: cert)
		}
	}

	private var _title: String {
		cert.nickname ?? _decoded?.Name ?? .localized("Pass")
	}
}
