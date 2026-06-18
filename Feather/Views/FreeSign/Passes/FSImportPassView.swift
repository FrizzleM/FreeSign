//
//  FSImportPassView.swift
//  Feather
//
//  Import a personal signing pass (.p12 + .mobileprovision) —
//  same validation and storage pipeline as before.
//

import SwiftUI
import UniformTypeIdentifiers
import NimbleViews

// MARK: - View
struct FSImportPassView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _password = ""
	@State private var _nickname = ""

	@State private var _isImportingP12 = false
	@State private var _isImportingProvision = false

	private var _isSaveDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			Form {
				Section {
					_fileRow(
						title: .localized("Key File"),
						detail: .localized("Ends in .p12"),
						url: _p12URL
					) {
						_isImportingP12 = true
					}
					_fileRow(
						title: .localized("Profile File"),
						detail: .localized("Ends in .mobileprovision"),
						url: _provisionURL
					) {
						_isImportingProvision = true
					}
				} header: {
					Text(.localized("Files"))
				} footer: {
					Text(.localized("These two files together make a signing pass. Whoever gave you the pass will have sent both."))
				}

				Section {
					SecureField(.localized("Password"), text: $_password)
				} footer: {
					Text(.localized("Leave empty if the pass doesn't have one."))
				}

				Section {
					TextField(.localized("Name (optional)"), text: $_nickname)
				} footer: {
					Text(.localized("Give it a name you'll recognize, like “My pass”."))
				}
			}
			.navigationTitle(.localized("Add Your Own Pass"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(.localized("Cancel")) { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(.localized("Add")) {
						_save()
					}
					.fontWeight(.semibold)
					.disabled(_isSaveDisabled)
				}
			}
			.sheet(isPresented: $_isImportingP12) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_p12URL = url
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingProvision) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_provisionURL = url
					}
				)
				.ignoresSafeArea()
			}
		}
	}

	@ViewBuilder
	private func _fileRow(
		title: String,
		detail: String,
		url: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack {
				VStack(alignment: .leading, spacing: 1) {
					Text(title)
						.foregroundStyle(.primary)
					Text(url?.lastPathComponent ?? detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
				Spacer()
				Image(systemName: url == nil ? "plus.circle" : "checkmark.circle.fill")
					.foregroundStyle(url == nil ? Color.accentColor : Color.green)
			}
		}
	}

	// MARK: Save
	private func _save() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _password, using: provisionURL)
		else {
			FSTheme.failure()
			UIAlertController.showAlertWithOk(
				title: .localized("Wrong password"),
				message: .localized("That password doesn't match this pass. Double-check it and try again.")
			)
			return
		}

		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _password,
			certificateName: _nickname
		) { _ in
			dismiss()
		}
	}
}
