//
//  FSGetButton.swift
//  Feather
//
//  App Store-like "GET" capsule with an inline progress ring
//  while the app downloads. Reuses DownloadManager wholesale.
//

import SwiftUI
import Combine
import AltSourceKit

struct FSGetButton: View {
	let app: ASRepository.App
	var filled: Bool = false

	@ObservedObject private var _downloadManager = DownloadManager.shared
	@State private var _downloadProgress: Double = 0
	@State private var _cancellable: AnyCancellable?

	var body: some View {
		ZStack {
			if let currentDownload = _downloadManager.getDownload(by: app.currentUniqueId) {
				ZStack {
					Circle()
						.stroke(Color.accentColor.opacity(0.2), lineWidth: 2.5)
					Circle()
						.trim(from: 0, to: max(0.02, _downloadProgress))
						.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
						.rotationEffect(.degrees(-90))
						.animation(.smooth, value: _downloadProgress)

					Image(systemName: _downloadProgress >= 0.75 ? "shippingbox.fill" : "stop.fill")
						.foregroundStyle(Color.accentColor)
						.font(.system(size: 10, weight: .bold))
				}
				.frame(width: 30, height: 30)
				.contentShape(Circle())
				.onTapGesture {
					// unpacking has started past this point, let it finish
					if _downloadProgress <= 0.75 {
						_downloadManager.cancelDownload(currentDownload)
					}
				}
				.compatTransition()
			} else {
				Button {
					FSTheme.lightImpact()
					if let url = app.currentDownloadUrl {
						_ = _downloadManager.startDownload(from: url, id: app.currentUniqueId)
					}
				} label: {
					Text(.localized("Get"))
						.textCase(.uppercase)
				}
				.buttonStyle(FSCapsuleButtonStyle(filled: filled))
				.compatTransition()
			}
		}
		.onAppear(perform: _setupObserver)
		.onDisappear { _cancellable?.cancel() }
		.onChange(of: _downloadManager.downloads.description) { _ in
			_setupObserver()
		}
		.animation(.easeInOut(duration: 0.3), value: _downloadManager.getDownload(by: app.currentUniqueId) != nil)
	}

	private func _setupObserver() {
		_cancellable?.cancel()
		guard let download = _downloadManager.getDownload(by: app.currentUniqueId) else {
			_downloadProgress = 0
			return
		}
		_downloadProgress = download.overallProgress

		_cancellable = Publishers.CombineLatest(
			download.$progress,
			download.$unpackageProgress
		)
		.sink { _, _ in
			_downloadProgress = download.overallProgress
		}
	}
}
