//
//  SourcesViewModel.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import Foundation
import AltSourceKit
import SwiftUI
import NimbleJSON

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	
	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else { return }
		
		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) { return }
		
		// isfinished is used to prevent multiple fetches at the same time
		isFinished = false
		defer { isFinished = true }
		
		await MainActor.run {
			self.sources = [:]
		}
		
		let sourcesArray = Array(sources)
		
		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let endIndex = min(startIndex + batchSize, sourcesArray.count)
			let batch = sourcesArray[startIndex..<endIndex]
			
			let batchResults = await withTaskGroup(
				of: (source: AltSource, repo: ASRepository?, didFail: Bool).self,
				returning: (repos: [AltSource: ASRepository], failures: [AltSource]).self
			) { group in
				for source in batch {
					group.addTask {
						guard let url = source.sourceURL else {
							return (source, nil, true)
						}
						
						return await withCheckedContinuation { continuation in
							self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								switch result {
								case .success(let repo):
									continuation.resume(returning: (source, repo, false))
								case .failure(_):
									continuation.resume(returning: (source, nil, true))
								}
							}
						}
					}
				}
				
				var results = [AltSource: ASRepository]()
				var failures: [AltSource] = []
				for await (source, repo, didFail) in group {
					if let repo {
						results[source] = repo
					} else if didFail {
						failures.append(source)
					}
				}
				return (results, failures)
			}
			
			await MainActor.run {
				for (source, repo) in batchResults.repos {
					self.sources[source] = repo
					source.name = repo.name ?? source.name
					source.iconURL = repo.currentIconURL ?? source.iconURL
				}
				Storage.shared.saveContext()
				self._showFetchFailureToast(for: batchResults.failures)
			}
		}
	}
	
	@MainActor
	private func _showFetchFailureToast(for failures: [AltSource]) {
		guard !failures.isEmpty else {
			return
		}
		
		if failures.count == 1 {
			let source = failures[0]
			let name = source.name ?? source.sourceURL?.host ?? .localized("source")
			SourceFetchErrorToastCenter.shared.show(.localized("Couldn't refresh %@", arguments: name))
		} else {
			SourceFetchErrorToastCenter.shared.show(.localized("%d sources couldn't refresh", arguments: failures.count))
		}
	}
}
