//
//  CertificateFileHandler.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation
import OSLog

final class CertificateFileHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _key: URL
	private let _provision: URL
	private let _keyPassword: String?
	private let _certNickname: String?
	private let _isDefault: Bool
	private let _playsFeedback: Bool
	private let _checksRevocation: Bool
	
	private var _certPair: Certificate?
	
	init(
		key: URL,
		provision: URL,
		password: String? = nil,
		nickname: String? = nil,
		isDefault: Bool = false,
		playsFeedback: Bool = true,
		checksRevocation: Bool = true
	) {
		self._key = key
		self._provision = provision
		self._keyPassword = password
		self._certNickname = nickname
		self._isDefault = isDefault
		self._playsFeedback = playsFeedback
		self._checksRevocation = checksRevocation
		
		_certPair = CertificateReader(provision).decoded
		
		super.init()
	}
	
	func copy() async throws {
		guard
			(_certPair != nil)
		else {
			throw CertificateFileHandlerError.certNotValid
		}
		
		let destinationURL = try await _directory()

		try _fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
		try _fileManager.copyItem(at: _key, to: destinationURL.appendingPathComponent(_key.lastPathComponent))
		try _fileManager.copyItem(at: _provision, to: destinationURL.appendingPathComponent(_provision.lastPathComponent))
	}
	
	@MainActor
	func addToDatabase() async throws {
		
		Storage.shared.addCertificate(
			uuid: _uuid,
			password: _keyPassword,
			nickname: _certNickname,
			ppq: _certPair?.PPQCheck ?? false,
			expiration: _certPair?.ExpirationDate ?? Date(),
			isDefault: _isDefault,
			playsFeedback: _playsFeedback,
			checksRevocation: _checksRevocation
		) { _ in
			Logger.misc.info("[\(self._uuid)] Added to database")
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Certificates/\(UUID)
		_fileManager.certificates(_uuid)
	}
}

private enum CertificateFileHandlerError: Error {
	case certNotValid
}
