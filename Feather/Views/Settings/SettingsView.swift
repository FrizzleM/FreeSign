//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@AppStorage("Feather.userTintColor") private var _selectedColorHex: String = "#004CFF"
	@State private var _isFetchingDefaultCertificates = false
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}
	private let _githubUrl = "https://github.com/Frizzle/FreeSign"
    
	// MARK: Body
	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			Form {
				_pageHeader()
				_feedback()
                
				NBSection(.localized("Certificates")) {
                    
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("No Certificate"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificates"), systemImage: "checkmark.seal")
					}
					Button {
						_fetchDefaultCertificates()
					} label: {
						Label(
							.localized(_isFetchingDefaultCertificates ? "Updating certs" : "Update Certs"),
							systemImage: "arrow.clockwise.icloud"
						)
					}
					.disabled(_isFetchingDefaultCertificates)
                 
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}
				
				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
				}
                
				NBSection(.localized("Features")) {
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
				} footer: {
					Text(.localized("Configure zip compression levels and custom modifications to apps."))
				}
                
				_directories()
                
				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
			}
			.toolbar(.hidden, for: .navigationBar)
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _pageHeader() -> some View {
		Section {
			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 4) {
					Text("FastSign")
						.font(.largeTitle.bold())
						.foregroundStyle(Color(hex: _selectedColorHex))
					Text("by Frizzle")
						.font(.subheadline.weight(.medium))
						.foregroundStyle(.secondary)
				}
				
				Text(.localized("Settings"))
					.font(.largeTitle.bold())
					.foregroundStyle(.primary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.fixedSize(horizontal: false, vertical: true)
			.padding(.top, 14)
			.padding(.bottom, 8)
			.listRowBackground(Color.clear)
			.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
			.listRowSeparator(.hidden)
		}
	}
	
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			Button(.localized("Submit Feedback"), systemImage: "safari") {
				let bugAction: UIAlertAction = .init(title: .localized("Bug Report"), style: .default) { _ in
					UIApplication.open(_makeGitHubIssueURL(url: _githubUrl))
				}
				
				let chooseAction: UIAlertAction = .init(title: .localized("Other"), style: .default) { _ in
					UIApplication.open(URL(string: "\(_githubUrl)/issues/new/choose")!)
				}
				
				UIAlertController.showAlertWithCancel(
					title: .localized("Submit Feedback"),
					message: nil,
					actions: [bugAction, chooseAction]
				)
			}
			Button(.localized("GitHub Repository"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			}
		} footer: {
			Text(.localized("If any issues occur within the app please report it via the GitHub repository. When submitting an issue, make sure to submit detailed information."))
		}
	}
    
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
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
	
	private func _fetchDefaultCertificates() {
		guard !_isFetchingDefaultCertificates else {
			return
		}
		
		_isFetchingDefaultCertificates = true
		
		Task { @MainActor in
			do {
				let importedCount = try await DefaultCertificateInstaller.shared.install(replacingExistingDefaults: true)
				_isFetchingDefaultCertificates = false
				
				let generator = UINotificationFeedbackGenerator()
				generator.notificationOccurred(.success)
				
				UIAlertController.showAlertWithOk(
					title: .localized("Certificates Installed"),
					message: .localized("Installed %d signing certificates.", arguments: importedCount)
				)
			} catch {
				_isFetchingDefaultCertificates = false
				
				let generator = UINotificationFeedbackGenerator()
				generator.notificationOccurred(.error)
				
				UIAlertController.showAlertWithOk(
					title: .localized("Error"),
					message: error.localizedDescription
				)
			}
		}
	}
}
