//
//  PostSigningShortcutCoordinator.swift
//  Feather
//
//  Bridges the signing pipeline to the consumer install sheet.
//
//  After an app is signed, FreeSign hands the install off to the
//  "BreakFree" helper shortcut so the device is prepared (DNS) before
//  the .ipa actually lands. The full handshake is:
//
//    1. App signs the .ipa.
//    2. App runs the shortcut with input "Installation".          ← beginPendingInstall
//    3. Shortcut reopens us via freesign://shortcut?input=InstallDNS.
//    4. App installs the .ipa.                                     ← resumePendingInstall
//    5. Install succeeds.
//    6. App runs the shortcut with input "Installed".             ← completePendingInstall
//
//  Both entry points — the one-tap "Install" sheet (FSQuickInstallSheet)
//  and the full "Customize & Install" flow (SigningView) — funnel
//  through here so there is a single, predictable hand-off. The actual
//  install machinery (ArchiveHandler → ServerInstaller / idevice) is
//  untouched; this type only sequences the shortcut handshake and
//  decides *which* freshly-signed app to present.
//

import Foundation
import UIKit

enum PostSigningShortcutCoordinator {
	/// Posted when a freshly-signed app is ready to install.
	///
	/// We deliberately reuse the legacy `Feather.installApp` name so
	/// the existing signing flow keeps working unchanged: the object,
	/// when present, is the signed app's UUID (`String`); a `nil`
	/// object means "install the most recently signed app".
	static let installAppNotification = Notification.Name("Feather.installApp")

	/// UserDefaults key for the helper shortcut name, configurable in
	/// Settings → Power Tools → Helper Shortcut.
	private static let shortcutNameKey = "Feather.installShortcutName"

	/// The helper shortcut name used when the user hasn't set one.
	static let defaultShortcutName = "BreakFree"

	/// Text inputs handed to the helper shortcut at each phase.
	private enum ShortcutInput {
		/// Sent before installing so the shortcut can prepare the device.
		static let preInstall = "Installation"
		/// Sent after a successful install.
		static let postInstall = "Installed"
	}

	/// The app the user last asked to install, used to disambiguate
	/// when several apps were signed in quick succession.
	private(set) static var pendingInstallUUID: String?

	/// Call after a successful sign when the app should be installed.
	///
	/// Kicks off the helper shortcut with input "Installation". The
	/// shortcut prepares the device and reopens us via
	/// `freesign://shortcut?input=InstallDNS`, which routes back into
	/// `resumePendingInstall()` to actually present the install sheet.
	static func beginPendingInstall(for uuid: String?) {
		pendingInstallUUID = uuid

		// A small delay lets any presenting signing sheet finish
		// dismissing before we background the app into Shortcuts.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
			runHelperShortcut(input: ShortcutInput.preInstall)
		}
	}

	/// Call when the helper shortcut reopens us via the InstallDNS
	/// callback. Presents the install sheet for the pending app (or the
	/// latest signed app if we lost track of the UUID).
	static func resumePendingInstall() {
		let uuid = pendingInstallUUID

		// A small delay lets the @FetchRequest backing the UI observe
		// the new Signed record before we ask it to present, and lets
		// the app settle back into the foreground from Shortcuts.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
			NotificationCenter.default.post(name: installAppNotification, object: uuid)
		}
	}

	/// Call when the install sheet finishes (success or failure) so we
	/// stop tracking it. On success of the pending install, runs the
	/// helper shortcut a final time with input "Installed".
	static func completePendingInstall(for uuid: String?, bundleID: String?) {
		if pendingInstallUUID == uuid || uuid == nil {
			pendingInstallUUID = nil
			runHelperShortcut(input: ShortcutInput.postInstall)
		}
	}

	// MARK: - Helper shortcut

	/// The configured helper shortcut name, falling back to the default
	/// when the user hasn't customized it.
	private static var shortcutName: String {
		let stored = UserDefaults.standard.string(forKey: shortcutNameKey)?
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return (stored?.isEmpty == false) ? stored! : defaultShortcutName
	}

	/// Runs the helper shortcut with `input` as its text input, via the
	/// Shortcuts URL scheme (`shortcuts://run-shortcut`).
	private static func runHelperShortcut(input: String) {
		var components = URLComponents()
		components.scheme = "shortcuts"
		components.host = "run-shortcut"
		components.queryItems = [
			URLQueryItem(name: "name", value: shortcutName),
			URLQueryItem(name: "input", value: "text"),
			URLQueryItem(name: "text", value: input),
		]

		guard let url = components.url else { return }

		DispatchQueue.main.async {
			UIApplication.shared.open(url, options: [:])
		}
	}
}

// MARK: - Options
extension Options {
	/// The consumer "Install" button always means *install*, regardless
	/// of the user's saved signing defaults. This nudges the options so
	/// the quick-install path reliably hands off afterwards.
	mutating func enforceRequiredPostSigningOptions() {
		post_installAppAfterSigned = true
	}
}
