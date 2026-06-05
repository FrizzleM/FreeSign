//
//  DefaultCertificateSetupView.swift
//  Feather
//
//  Created on 05.06.2026.
//

import SwiftUI

struct DefaultCertificateSetupView: View {
	enum SetupState: Equatable {
		case loading
		case failed(String)
	}
	
	let state: SetupState
	let retry: () -> Void
	let continueWithoutCertificates: () -> Void
	
	var body: some View {
		VStack(spacing: 28) {
			Spacer()
			
			Image("Glyph")
				.resizable()
				.scaledToFit()
				.frame(width: 80, height: 80)
				.clipShape(RoundedRectangle(cornerRadius: 18))
				.shadow(color: .black.opacity(0.12), radius: 16, y: 8)
			
			_content
				.frame(maxWidth: 360)
			
			Spacer()
		}
		.padding(32)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(uiColor: .systemBackground))
	}
	
	@ViewBuilder
	private var _content: some View {
		switch state {
		case .loading:
			VStack(spacing: 16) {
				ProgressView()
					.controlSize(.large)
				
				VStack(spacing: 8) {
					Text(.localized("Setting Up Certificates"))
						.font(.title3.weight(.semibold))
					Text(.localized("FreeSign is preparing the included signing certificates."))
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				}
			}
		case .failed(let message):
			VStack(spacing: 18) {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.title2)
					.foregroundStyle(.orange)
				
				VStack(spacing: 8) {
					Text(.localized("Certificate Setup Failed"))
						.font(.title3.weight(.semibold))
					Text(message)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				}
				
				VStack(spacing: 10) {
					Button {
						retry()
					} label: {
						Label(.localized("Retry"), systemImage: "arrow.clockwise")
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.borderedProminent)
					
					Button {
						continueWithoutCertificates()
					} label: {
						Text(.localized("Continue"))
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.bordered)
				}
				.controlSize(.large)
			}
		}
	}
}
