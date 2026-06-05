//
//  SourceFetchErrorToastCenter.swift
//  Feather
//
//  Created on 05.06.2026.
//

import SwiftUI

@MainActor
final class SourceFetchErrorToastCenter: ObservableObject {
	static let shared = SourceFetchErrorToastCenter()
	
	@Published private(set) var message: String?
	@Published private(set) var systemImage = "exclamationmark.circle.fill"
	
	private var _dismissTask: Task<Void, Never>?
	
	func show(_ message: String, systemImage: String = "exclamationmark.circle.fill") {
		self.message = message
		self.systemImage = systemImage
		_dismissTask?.cancel()
		_dismissTask = Task {
			try? await Task.sleep(nanoseconds: 3_000_000_000)
			guard !Task.isCancelled else { return }
			self.message = nil
		}
	}
}

struct SourceFetchErrorToastView: View {
	let message: String
	let systemImage: String
	
	var body: some View {
		Label {
			Text(message)
				.font(.footnote.weight(.medium))
				.lineLimit(2)
		} icon: {
			Image(systemName: systemImage)
				.imageScale(.small)
		}
		.foregroundStyle(.primary)
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(.regularMaterial, in: Capsule())
		.shadow(color: .black.opacity(0.14), radius: 16, y: 8)
		.padding(.horizontal, 18)
		.transition(.move(edge: .bottom).combined(with: .opacity))
	}
}
