//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	let heartbeat = HeartbeatManager.shared
	
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject private var _sourceFetchErrorToast = SourceFetchErrorToastCenter.shared
	@State private var _certificateSetupState: DefaultCertificateSetupView.SetupState? = DefaultCertificateInstaller.needsInstall ? .loading : nil
	let storage = Storage.shared
	
	var body: some Scene {
		WindowGroup {
			Group {
				if let setupState = _certificateSetupState {
					DefaultCertificateSetupView(
						state: setupState,
						retry: {
							_certificateSetupState = .loading
						},
						continueWithoutCertificates: {
							_certificateSetupState = nil
						}
					)
					.task(id: setupState) {
						await _runCertificateSetupIfNeeded()
					}
				} else {
					_mainContent
						.transition(.move(edge: .top).combined(with: .opacity))
				}
			}
			.environment(\.managedObjectContext, storage.context)
			.animation(.smooth, value: downloadManager.manualDownloads.description)
			.overlay(alignment: .bottom) {
				if let message = _sourceFetchErrorToast.message {
					SourceFetchErrorToastView(
						message: message,
						systemImage: _sourceFetchErrorToast.systemImage
					)
						.padding(.bottom, 82)
				}
			}
			.animation(.spring(response: 0.28, dampingFraction: 0.9), value: _sourceFetchErrorToast.message)
			.onOpenURL(perform: _handleURL)
			.onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(
						title: "InvalidHostID",
						message: .localized("Your pairing file is invalid and is incompatible with your device, please import a valid pairing file.")
					)
				}
			}
			// dear god help me
			.onAppear {
				if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "Feather.userInterfaceStyle")) {
					UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
				}
				
				UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#004CFF"))
			}
		}
	}
	
	private func _handleURL(_ url: URL) {
		if url.scheme == "freesign" {
			/// freesign://import-certificate?p12=<base64>&mobileprovision=<base64>&password=<base64>
			if url.host == "import-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
					let queryItems = components.queryItems
				else {
					return
				}
				
				func queryValue(_ name: String) -> String? {
					queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding
				}
				
				guard
					let p12Base64 = queryValue("p12"),
					let provisionBase64 = queryValue("mobileprovision"),
					let passwordBase64 = queryValue("password"),
					let passwordData = Data(base64Encoded: passwordBase64),
					let password = String(data: passwordData, encoding: .utf8)
				else {
					return
				}
				
				let generator = UINotificationFeedbackGenerator()
				generator.prepare()
				
				guard
					let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"),
					let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"),
					FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL)
				else {
					generator.notificationOccurred(.error)
					return
				}
				
				FR.handleCertificateFiles(
					p12URL: p12URL,
					provisionURL: provisionURL,
					p12Password: password
				) { error in
					if let error = error {
						UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
					} else {
						generator.notificationOccurred(.success)
					}
				}
				
				return
			}
			/// freesign://export-certificate?callback_template=<template>
			/// ?callback_template=: This is how we callback to the application requesting the certificate, this will be a url scheme
			/// 	example: livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29
			/// 	decoded: livecontainer://certificate?cert=$(BASE64_CERT)&password=$(PASSWORD)
			/// $(BASE64_CERT) and $(PASSWORD) must be presenting in the callback template so we can replace them with the proper content
			if url.host == "export-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
				else {
					return
				}
				
				let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
				guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
				
				FR.exportCertificateAndOpenUrl(using: callbackTemplate)
			}
			/// freesign://source/<url>
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			/// freesign://install/<url.ipa>
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				_ = DownloadManager.shared.startDownload(from: downloadURL)
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { _ in }
				} else {
					FR.handlePackageFile(url) { _ in }
				}
				
				return
			}
		}
	}
}

// MARK: - View extension
extension FeatherApp {
	@ViewBuilder
	private var _mainContent: some View {
		VStack {
			DownloadHeaderView(downloadManager: downloadManager)
				.transition(.move(edge: .top).combined(with: .opacity))
			VariedTabbarView()
				.transition(.move(edge: .top).combined(with: .opacity))
		}
	}
	
	@MainActor
	private func _runCertificateSetupIfNeeded() async {
		guard _certificateSetupState == .loading else {
			return
		}
		
		do {
			_ = try await DefaultCertificateInstaller.shared.installIfNeeded()
			_certificateSetupState = nil
		} catch {
			_certificateSetupState = .failed(error.localizedDescription)
		}
	}
}

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		_configureFreeSignDefaults()
		_createPipeline()
		_createDocumentsDirectories()
		ResetView.clearWorkCache()
		Task { @MainActor in
			await _installStartupSources()
		}
		return true
	}
	
	@MainActor
	private func _installStartupSources() async {
		var insertedCount = DefaultSourceInstaller.installIfNeeded()
		
		do {
			insertedCount += try await DefaultSourceInstaller.updateFromRemote()
		} catch {
			Logger.misc.error("Failed to update startup sources: \(error.localizedDescription)")
		}
		
		if insertedCount > 0 {
			SourceFetchErrorToastCenter.shared.show(
				.localized("Succesfully added %d sources", arguments: insertedCount),
				systemImage: "checkmark.circle.fill"
			)
		}
	}

	private func _configureFreeSignDefaults() {
		UserDefaults.standard.set(0, forKey: "Feather.installationMethod")
		UserDefaults.standard.set(1, forKey: "Feather.serverMethod")
	}
	
	private func _createPipeline() {
		DataLoader.sharedUrlCache.diskCapacity = 0
		
		let pipeline = ImagePipeline {
			let dataLoader: DataLoader = {
				let config = URLSessionConfiguration.default
				config.urlCache = nil
				return DataLoader(configuration: config)
			}()
			let dataCache = try? DataCache(name: "frizzle.FreeSign.datacache") // disk cache
			let imageCache = Nuke.ImageCache() // memory cache
			dataCache?.sizeLimit = 500 * 1024 * 1024
			imageCache.costLimit = 100 * 1024 * 1024
			$0.dataCache = dataCache
			$0.imageCache = imageCache
			$0.dataLoader = dataLoader
			$0.dataCachePolicy = .automatic
			$0.isStoringPreviewsInMemoryCache = false
		}
		
		ImagePipeline.shared = pipeline
	}
	
	private func _createDocumentsDirectories() {
		let fileManager = FileManager.default

		let directories: [URL] = [
			fileManager.archives,
			fileManager.certificates,
			fileManager.signed,
			fileManager.unsigned
		]
		
		for url in directories {
			try? fileManager.createDirectoryIfNeeded(at: url)
		}
	}
	
}
