//
//  FSQuickInstallSheet.swift
//  Feather
//
//  One-tap install: signs the app with the user's active pass and
//  default options, then hands off to the installation shortcut —
//  the exact same pipeline as SigningView, minus the knobs.
//

import SwiftUI
import CoreData

// MARK: - View
struct FSQuickInstallSheet: View {
	@Environment(\.dismiss) private var dismiss

	@State private var _isWorking = false

	var app: AppInfoPresentable
	var onCustomize: () -> Void

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _selectedCert: CertificatePair? {
		let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		guard _certificates.indices.contains(index) else { return nil }
		return _certificates[index]
	}

	// MARK: Body
	var body: some View {
		VStack(spacing: 0) {
			Spacer(minLength: 24)

			FRAppIconView(app: app, size: 86)
				.shadow(color: .black.opacity(0.12), radius: 14, y: 6)

			VStack(spacing: 4) {
				Text(app.name ?? .localized("Unknown"))
					.font(.system(.title3, design: .rounded).weight(.bold))
					.lineLimit(1)
				if let version = app.version {
					Text(verbatim: .localized("Version %@", arguments: version))
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}
			.padding(.top, 14)

			Spacer(minLength: 18)

			_passStatus
				.padding(.horizontal, 24)

			Spacer(minLength: 18)

			VStack(spacing: 10) {
				Button {
					_startQuickInstall()
				} label: {
					if _isWorking {
						HStack(spacing: 10) {
							ProgressView()
								.tint(.white)
							Text(.localized("Getting it ready…"))
						}
					} else {
						Label(.localized("Install"), systemImage: "arrow.down.circle.fill")
					}
				}
				.buttonStyle(FSProminentButtonStyle())
				.disabled(_isWorking || _selectedCert == nil)
				.opacity(_selectedCert == nil ? 0.5 : 1)

				Button {
					dismiss()
					onCustomize()
				} label: {
					Text(.localized("Customize First…"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
				.disabled(_isWorking)
			}
			.padding(.horizontal, 24)
			.padding(.bottom, 28)
		}
		.interactiveDismissDisabled(_isWorking)
	}

	// MARK: Pass status
	@ViewBuilder
	private var _passStatus: some View {
		HStack(spacing: 12) {
			Image(systemName: _selectedCert == nil ? "exclamationmark.seal.fill" : "checkmark.seal.fill")
				.font(.title2)
				.foregroundStyle(_selectedCert == nil ? Color.orange : Color.green)

			VStack(alignment: .leading, spacing: 2) {
				if let cert = _selectedCert {
					Text(.localized("Signing pass ready"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))

					HStack(spacing: 6) {
						Text(cert.nickname ?? .localized("Pass"))
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
						if let info = cert.expiration?.expirationInfo() {
							Text(verbatim: "•")
								.font(.caption)
								.foregroundStyle(.secondary)
							Text(info.formatted)
								.font(.caption)
								.foregroundStyle(info.color)
						}
					}
				} else {
					Text(.localized("No signing pass"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
					Text(.localized("Get one in Settings → Signing Passes."))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: FSTheme.buttonCornerRadius, style: .continuous)
				.fill(Color(uiColor: .secondarySystemBackground))
		)
	}

	// MARK: Quick install
	private func _startQuickInstall() {
		guard let cert = _selectedCert else { return }

		FSTheme.lightImpact()
		_isWorking = true

		var options = OptionsManager.shared.options

		// same identifier adjustments SigningView applies on appear
		if
			options.ppqProtection,
			cert.ppQCheck,
			let identifier = app.identifier
		{
			options.appIdentifier = "\(identifier).\(options.ppqString)"
		}

		if
			let currentBundleId = app.identifier,
			let newBundleId = options.identifiers[currentBundleId]
		{
			options.appIdentifier = newBundleId
		}

		if
			let currentName = app.name,
			let newName = options.displayNames[currentName]
		{
			options.appName = newName
		}

		options.enforceRequiredPostSigningOptions()

		FR.signPackageFile(
			app,
			using: options,
			icon: nil,
			certificate: cert
		) { error, signedAppUUID in
			_isWorking = false

			if let error {
				FSTheme.failure()
				UIAlertController.showAlertWithOk(
					title: .localized("Couldn't prepare app"),
					message: error.localizedDescription
				)
				return
			}

			if options.post_deleteAppAfterSigned, !app.isSigned {
				Storage.shared.deleteApp(for: app)
			}

			FSTheme.success()
			dismiss()

			if options.post_installAppAfterSigned {
				PostSigningShortcutCoordinator.beginPendingInstall(for: signedAppUUID)
			}
		}
	}
}
