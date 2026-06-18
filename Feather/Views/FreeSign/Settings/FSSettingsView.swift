//
//  FSSettingsView.swift
//  Feather
//
//  Consumer settings: passes front and center, the developer
//  knobs tucked away under "Power Tools".
//

import SwiftUI
import UIKit
import IDeviceSwift

// MARK: - View
struct FSSettingsView: View {
	@AppStorage("feather.selectedCert") private var _selectedCertIndex: Int = 0
	@AppStorage("Feather.installShortcutName") private var _installShortcutName: String = ""

	@State private var _isRefreshingPasses = false
	@State private var _currentAppIcon: String? = UIApplication.shared.alternateIconName

	private let _githubUrl = "https://github.com/FrizzleM/FreeSign"

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _selectedCertificate: CertificatePair? {
		guard
			_selectedCertIndex >= 0,
			_selectedCertIndex < _certificates.count
		else {
			return nil
		}
		return _certificates[_selectedCertIndex]
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			Form {
				_header

				Section {
					NavigationLink {
						FSPassesView()
					} label: {
						_passStatusRow
					}

					Button {
						_refreshPasses()
					} label: {
						HStack {
							Label(.localized("Get Fresh Passes"), systemImage: "arrow.clockwise")
							Spacer()
							if _isRefreshingPasses {
								ProgressView()
							}
						}
					}
					.disabled(_isRefreshingPasses)
				} header: {
					Text(.localized("Installing"))
				} footer: {
					Text(.localized("Passes let FreeSign prepare apps for your iPhone. If installs stop working, fetching fresh passes usually fixes it."))
				}

				Section {
					NavigationLink {
						AppearanceView()
					} label: {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
					NavigationLink {
						AppIconView(currentIcon: $_currentAppIcon)
					} label: {
						Label(.localized("App Icon"), systemImage: "app.badge")
					}
				} header: {
					Text(.localized("Look & Feel"))
				}

				Section {
					NavigationLink {
						FSHowItWorksView()
					} label: {
						Label(.localized("How Installing Works"), systemImage: "questionmark.circle")
					}
					Button {
						_submitFeedback()
					} label: {
						Label(.localized("Something's Not Working"), systemImage: "lifepreserver")
					}
					Button {
						UIApplication.open(_githubUrl)
					} label: {
						Label(.localized("FreeSign on GitHub"), systemImage: "star")
					}
				} header: {
					Text(.localized("Help"))
				}

				Section {
					NavigationLink {
						ConfigurationView()
					} label: {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink {
						ArchiveView()
					} label: {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					HStack {
						Label(.localized("Helper Shortcut"), systemImage: "link")
						Spacer()
						TextField("BreakFree", text: $_installShortcutName)
							.multilineTextAlignment(.trailing)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
							.frame(maxWidth: 140)
					}
					Button {
						UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
					} label: {
						Label(.localized("Browse App Files"), systemImage: "folder")
					}
					NavigationLink {
						ResetView()
					} label: {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} header: {
					Text(.localized("Power Tools"))
				} footer: {
					Text(.localized("You shouldn't ever need these — but they're here if someone asks you to use them."))
				}
			}
			.navigationTitle(.localized("Settings"))
		}
	}

	// MARK: Header
	@ViewBuilder
	private var _header: some View {
		Section {
			VStack(spacing: 10) {
				Image("Glyph")
					.resizable()
					.scaledToFit()
					.frame(width: 64, height: 64)
					.clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

				VStack(spacing: 2) {
					Text(verbatim: "FreeSign")
						.font(.system(.title2, design: .rounded).weight(.bold))
					Text(verbatim: .localized("Sideloading made simple • %@", arguments: Bundle.main.version))
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 10)
			.listRowBackground(Color.clear)
		}
	}

	@ViewBuilder
	private var _passStatusRow: some View {
		HStack(spacing: 12) {
			Image(systemName: _selectedCertificate == nil ? "exclamationmark.seal.fill" : "checkmark.seal.fill")
				.font(.title3)
				.foregroundStyle(_selectedCertificate == nil ? Color.orange : Color.green)

			VStack(alignment: .leading, spacing: 1) {
				Text(.localized("Signing Passes"))

				if let cert = _selectedCertificate {
					HStack(spacing: 5) {
						Text(cert.nickname ?? .localized("Pass"))
							.lineLimit(1)
						if let info = cert.expiration?.expirationInfo() {
							Text(verbatim: "•")
							Text(info.formatted)
								.foregroundStyle(info.color)
						}
					}
					.font(.caption)
					.foregroundStyle(.secondary)
				} else {
					Text(.localized("None active — installs won't work yet"))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	// MARK: Actions
	private func _refreshPasses() {
		guard !_isRefreshingPasses else { return }
		_isRefreshingPasses = true

		Task { @MainActor in
			do {
				let importedCount = try await DefaultCertificateInstaller.shared.install(replacingExistingDefaults: true)
				_isRefreshingPasses = false
				FSTheme.success()

				UIAlertController.showAlertWithOk(
					title: .localized("You're all set"),
					message: .localized("Fetched %d fresh signing passes.", arguments: importedCount)
				)
			} catch {
				_isRefreshingPasses = false
				FSTheme.failure()

				UIAlertController.showAlertWithOk(
					title: .localized("Couldn't fetch passes"),
					message: error.localizedDescription
				)
			}
		}
	}

	private func _submitFeedback() {
		let bugAction: UIAlertAction = .init(title: .localized("Report a Problem"), style: .default) { _ in
			UIApplication.open(_makeGitHubIssueURL(url: _githubUrl))
		}

		let chooseAction: UIAlertAction = .init(title: .localized("Other"), style: .default) { _ in
			UIApplication.open(URL(string: "\(_githubUrl)/issues/new/choose")!)
		}

		UIAlertController.showAlertWithCancel(
			title: .localized("Something's Not Working"),
			message: .localized("Tell us what happened and we'll look into it."),
			actions: [bugAction, chooseAction]
		)
	}

	private func _makeGitHubIssueURL(url: String) -> String {
		var configurationSection = "### App Configuration:\n"

		switch UserDefaults.standard.integer(forKey: "Feather.installationMethod") {
		case 0: // Server
			let serverMethod = UserDefaults.standard.integer(forKey: "Feather.serverMethod")
			let ipFix = UserDefaults.standard.bool(forKey: "Feather.ipFix")
			let serverType = (serverMethod == 0) ? "Fully Local" : "Semi Local"
			configurationSection += "- Install method: `Server`\n"
			configurationSection += "  - Server type: `\(serverType)`\n"
			configurationSection += "  - IP Fix: `\(ipFix)`\n"
		case 1: // idevice
			let pairingPath = HeartbeatManager.pairingFile()
			let pairingExists = FileManager.default.fileExists(atPath: pairingPath)
			let pairingStatus = pairingExists ? "`Present`" : "`Not Present`"
			configurationSection += "- Install method: `idevice`\n"
			configurationSection += "  - Pairing file: \(pairingStatus)\n"
		default:
			configurationSection += "- Install method: `Unknown`\n"
		}

		let body = """
		### Device Information
		- Device: `\(MobileGestalt().getStringForName("PhysicalHardwareNameString") ?? "Unknown")`
		- iOS Version: `\(UIDevice.current.systemVersion)`
		- App Version: `\(Bundle.main.version)`

		\(configurationSection)

		### Issue Description
		<!-- Describe your issue here -->

		### Steps to Reproduce
		1.
		2.
		3.

		### Expected Behavior

		### Actual Behavior
		"""
		let encodedTitle = "[Bug] replace this with a descriptive title "
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		let encodedBody = body
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		return "\(url)/issues/new?template=bug.yml&title=\(encodedTitle)&text=\(encodedBody)"
	}
}
