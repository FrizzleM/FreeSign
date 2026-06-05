//
//  DefaultCertificateInstaller.swift
//  Feather
//
//  Created on 05.06.2026.
//

import Foundation
import OSLog
import Zip

actor DefaultCertificateInstaller {
	static let shared = DefaultCertificateInstaller()
	
	private static let _archiveURL = URL(string: "https://github.com/WSF-Team/WSF/raw/refs/heads/main/portal/resources/certificates.zip")!
	private static let _password = "WSF"
	private static let _didInstallKey = "feather.didImportDefaultCertificates"
	
	private var _currentTask: Task<Int, Error>?
	
	nonisolated static var needsInstall: Bool {
		UserDefaults.standard.bool(forKey: _didInstallKey) == false
	}
	
	func installIfNeeded() async throws -> Int? {
		guard Self.needsInstall else {
			return nil
		}
		
		let importedCount = try await install(replacingExistingDefaults: true)
		Logger.misc.info("Installed \(importedCount) default signing certificates")
		return importedCount
	}
	
	func install(replacingExistingDefaults: Bool) async throws -> Int {
		if let currentTask = _currentTask {
			return try await currentTask.value
		}
		
		let task = Task<Int, Error> {
			try await Self._install(replacingExistingDefaults: replacingExistingDefaults)
		}
		
		_currentTask = task
		defer {
			_currentTask = nil
		}
		
		let importedCount = try await task.value
		UserDefaults.standard.set(true, forKey: Self._didInstallKey)
		return importedCount
	}
}

// MARK: - Private implementation
private extension DefaultCertificateInstaller {
	struct CertificatePairURLs {
		let name: String
		let p12URL: URL
		let provisionURL: URL
	}
	
	static func _install(replacingExistingDefaults: Bool) async throws -> Int {
		let fileManager = FileManager.default
		let workDirectory = fileManager.temporaryDirectory
			.appendingPathComponent("FeatherDefaultCertificates_\(UUID().uuidString)", isDirectory: true)
		let archiveURL = workDirectory.appendingPathComponent("certificates.zip")
		let extractionDirectory = workDirectory.appendingPathComponent("Extracted", isDirectory: true)
		
		defer {
			try? fileManager.removeItem(at: workDirectory)
		}
		
		try fileManager.createDirectoryIfNeeded(at: workDirectory)
		try await _downloadArchive(to: archiveURL)
		try fileManager.createDirectoryIfNeeded(at: extractionDirectory)
		try await _unzipArchive(archiveURL, to: extractionDirectory)
		
		let pairs = try _certificatePairs(in: extractionDirectory)
		guard !pairs.isEmpty else {
			throw DefaultCertificateInstallerError.noCertificatesFound
		}
		
		if replacingExistingDefaults {
			await MainActor.run {
				Storage.shared.deleteDefaultCertificates()
			}
		}
		
		var importedCount = 0
		
		for pair in pairs {
			do {
				guard FR.checkPasswordForCertificate(
					for: pair.p12URL,
					with: _password,
					using: pair.provisionURL
				) else {
					Logger.misc.warning("Skipping default certificate \(pair.name): invalid password")
					continue
				}
				
				let handler = CertificateFileHandler(
					key: pair.p12URL,
					provision: pair.provisionURL,
					password: _password,
					nickname: pair.name,
					isDefault: true,
					playsFeedback: false,
					checksRevocation: false
				)
				
				try await handler.copy()
				try await handler.addToDatabase()
				importedCount += 1
			} catch {
				Logger.misc.error("Failed to import default certificate \(pair.name): \(error.localizedDescription)")
			}
		}
		
		guard importedCount > 0 else {
			throw DefaultCertificateInstallerError.noCertificatesImported
		}
		
		return importedCount
	}
	
	static func _downloadArchive(to destinationURL: URL) async throws {
		let (downloadedURL, response) = try await URLSession.shared.download(from: _archiveURL)
		
		if
			let response = response as? HTTPURLResponse,
			!(200...299).contains(response.statusCode)
		{
			throw DefaultCertificateInstallerError.badServerResponse(response.statusCode)
		}
		
		try FileManager.default.removeFileIfNeeded(at: destinationURL)
		try FileManager.default.moveItem(at: downloadedURL, to: destinationURL)
	}
	
	static func _unzipArchive(_ archiveURL: URL, to destinationURL: URL) async throws {
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .utility).async {
				do {
					try Zip.unzipFile(
						archiveURL,
						destination: destinationURL,
						overwrite: true,
						password: nil,
						progress: nil
					)
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	static func _certificatePairs(in directory: URL) throws -> [CertificatePairURLs] {
		let fileManager = FileManager.default
		guard let enumerator = fileManager.enumerator(
			at: directory,
			includingPropertiesForKeys: [.isRegularFileKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}
		
		var pairs: [CertificatePairURLs] = []
		
		for case let p12URL as URL in enumerator where p12URL.pathExtension.lowercased() == "p12" {
			let folderURL = p12URL.deletingLastPathComponent()
			let name = p12URL.deletingPathExtension().lastPathComponent
			let matchingProvisionURL = folderURL.appendingPathComponent("\(name).mobileprovision")
			let provisionURL: URL?
			
			if fileManager.fileExists(atPath: matchingProvisionURL.path) {
				provisionURL = matchingProvisionURL
			} else {
				provisionURL = fileManager.getPath(in: folderURL, for: "mobileprovision")
			}
			
			guard let provisionURL else {
				Logger.misc.warning("Skipping default certificate \(name): missing provisioning file")
				continue
			}
			
			pairs.append(
				CertificatePairURLs(
					name: name,
					p12URL: p12URL,
					provisionURL: provisionURL
				)
			)
		}
		
		return pairs.sorted {
			$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
		}
	}
}

private enum DefaultCertificateInstallerError: LocalizedError {
	case badServerResponse(Int)
	case noCertificatesFound
	case noCertificatesImported
	
	var errorDescription: String? {
		switch self {
		case .badServerResponse(let statusCode):
			return "The certificate server returned HTTP \(statusCode)."
		case .noCertificatesFound:
			return "No certificate pairs were found in the downloaded archive."
		case .noCertificatesImported:
			return "No signing certificates could be imported from the downloaded archive."
		}
	}
}
