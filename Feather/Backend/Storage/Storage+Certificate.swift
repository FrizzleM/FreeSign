//
//  Storage+Certificate.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator
import ZsignSwift

// MARK: - Class extension: certificate
extension Storage {
	func addCertificate(
		uuid: String,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		isDefault: Bool = false,
		playsFeedback: Bool = true,
		checksRevocation: Bool = true,
		completion: @escaping (Error?) -> Void
	) {
		let generator = playsFeedback ? UIImpactFeedbackGenerator(style: .light) : nil
		
		let new = CertificatePair(context: context)
		new.uuid = uuid
		new.date = Date()
		new.password = password
		new.ppQCheck = ppq
		new.expiration = expiration
		new.nickname = nickname
		new.isDefault = isDefault
		if checksRevocation {
			Storage.shared.revokagedCertificate(for: new)
		}
		saveContext()
		generator?.impactOccurred()
		completion(nil)
	}
	
	func deleteCertificate(for cert: CertificatePair) {
		if let url = getUuidDirectory(for: cert) {
			try? FileManager.default.removeItem(at: url)
		}
		context.delete(cert)
		saveContext()
	}
	
	func getCertificate(for index: Int) -> CertificatePair? {
		let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]

		guard
			let results = try? context.fetch(fetchRequest),
			index >= 0 && index < results.count
		else {
			return nil
		}
		
		return results[index]
	}
	
	func revokagedCertificate(for cert: CertificatePair) {
		guard !cert.revoked else { return }
		
		Zsign.checkRevokage(
			provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
			p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
			p12Password: cert.password ?? ""
		) { (status, _, _) in
			if status == 1 {
				DispatchQueue.main.async {
					cert.revoked = true
					self.saveContext()
				}
			}
		}
	}
	
	enum FileRequest: String {
		case certificate = "p12"
		case provision = "mobileprovision"
	}
	
	func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
		guard let url = getUuidDirectory(for: cert) else {
			return nil
		}
		
		return FileManager.default.getPath(in: url, for: type.rawValue)
	}
	
	func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
		guard let url = getFile(.provision, from: cert) else {
			return nil
		}
		
		let read = CertificateReader(url)
		return read.decoded
	}
	
	func getUuidDirectory(for cert: CertificatePair) -> URL? {
		guard let uuid = cert.uuid else {
			return nil
		}
		
		return FileManager.default.certificates(uuid)
	}
	
	func getAllCertificates() -> [CertificatePair] {
		let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
		return (try? context.fetch(fetchRequest)) ?? []
	}

	func selectedCertificateIndex(matching selector: String) -> Int? {
		let selector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !selector.isEmpty else {
			return nil
		}

		let certificates = getAllCertificates()
		if let index = Int(selector), certificates.indices.contains(index) {
			return index
		}

		let normalizedSelector = selector.lowercased()
		for (index, certificate) in certificates.enumerated() {
			let decoded = getProvisionFileDecoded(for: certificate)
			let candidates = [
				certificate.uuid,
				certificate.nickname,
				decoded?.UUID,
				decoded?.Name,
				decoded?.AppIDName,
				decoded?.TeamName
			]

			if candidates.contains(where: { $0?.lowercased() == normalizedSelector }) {
				return index
			}

			if decoded?.TeamIdentifier.contains(where: { $0.lowercased() == normalizedSelector }) == true {
				return index
			}
		}

		return nil
	}
	
	func deleteDefaultCertificates() {
		let certificates = getAllCertificates().filter { $0.isDefault }
		
		for certificate in certificates {
			deleteCertificate(for: certificate)
		}
		
		UserDefaults.standard.set(0, forKey: "feather.selectedCert")
	}
}
