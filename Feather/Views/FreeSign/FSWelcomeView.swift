//
//  FSWelcomeView.swift
//  Feather
//
//  First-launch experience. While the user reads the pitch,
//  FreeSign downloads the bundled enterprise signing passes
//  (DefaultCertificateInstaller) exactly like before.
//

import SwiftUI

struct FSWelcomeView: View {
	enum SetupState: Equatable {
		case loading
		case failed(String)
	}

	let state: SetupState
	let retry: () -> Void
	let continueWithoutCertificates: () -> Void

	@State private var _appeared = false

	var body: some View {
		VStack(spacing: 0) {
			Spacer(minLength: 12)

			_glyph

			VStack(spacing: 10) {
				Text(.localized("Welcome to FreeSign"))
					.font(.system(.largeTitle, design: .rounded).weight(.bold))
					.multilineTextAlignment(.center)
				Text(.localized("Your favorite apps, installed in one tap.\nNo computer needed."))
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.padding(.top, 26)
			.opacity(_appeared ? 1 : 0)
			.offset(y: _appeared ? 0 : 12)

			VStack(alignment: .leading, spacing: 4) {
				_featureRow(
					index: 0,
					icon: "sparkles",
					title: .localized("Discover apps"),
					subtitle: .localized("Browse a catalog of apps you won't find on the App Store.")
				)
				_featureRow(
					index: 1,
					icon: "wand.and.stars",
					title: .localized("One-tap install"),
					subtitle: .localized("FreeSign prepares every app so your iPhone happily accepts it.")
				)
				_featureRow(
					index: 2,
					icon: "checkmark.seal.fill",
					title: .localized("Ready out of the box"),
					subtitle: .localized("Signing passes are fetched automatically — nothing to configure.")
				)
			}
			.padding(.top, 38)
			.padding(.horizontal, 12)
			.frame(maxWidth: 420)

			Spacer(minLength: 12)

			_footer
				.frame(maxWidth: 420)
				.opacity(_appeared ? 1 : 0)
		}
		.padding(28)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(_background)
		.onAppear {
			withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
				_appeared = true
			}
		}
	}

	// MARK: Glyph
	private var _glyph: some View {
		Image("Glyph")
			.resizable()
			.scaledToFit()
			.frame(width: 100, height: 100)
			.clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
			.shadow(color: Color.accentColor.opacity(0.4), radius: 28, y: 12)
			.scaleEffect(_appeared ? 1 : 0.82)
			.opacity(_appeared ? 1 : 0)
	}

	private var _background: some View {
		ZStack {
			Color(uiColor: .systemBackground)
			LinearGradient(
				colors: [
					Color.accentColor.opacity(0.16),
					Color.accentColor.opacity(0.02),
					Color(uiColor: .systemBackground).opacity(0)
				],
				startPoint: .top,
				endPoint: .center
			)
		}
		.ignoresSafeArea()
	}

	// MARK: Footer states
	@ViewBuilder
	private var _footer: some View {
		switch state {
		case .loading:
			VStack(spacing: 12) {
				ProgressView()
				Text(.localized("Setting things up for you…"))
					.font(.system(.subheadline, design: .rounded).weight(.medium))
					.foregroundStyle(.secondary)
			}
			.padding(.bottom, 12)
		case .failed(let message):
			VStack(spacing: 12) {
				VStack(spacing: 4) {
					Text(.localized("We couldn't finish setting up"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
					Text(message)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.lineLimit(3)
				}

				Button {
					retry()
				} label: {
					Label(.localized("Try Again"), systemImage: "arrow.clockwise")
				}
				.buttonStyle(FSProminentButtonStyle())

				Button {
					continueWithoutCertificates()
				} label: {
					Text(.localized("Continue Anyway"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
			}
		}
	}

	@ViewBuilder
	private func _featureRow(index: Int, icon: String, title: String, subtitle: String) -> some View {
		HStack(alignment: .top, spacing: 16) {
			Image(systemName: icon)
				.font(.title2.weight(.semibold))
				.foregroundStyle(Color.accentColor)
				.frame(width: 38, height: 38)
				.background(
					RoundedRectangle(cornerRadius: 11, style: .continuous)
						.fill(Color.accentColor.opacity(0.12))
				)

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.system(.headline, design: .rounded))
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.vertical, 10)
		.opacity(_appeared ? 1 : 0)
		.offset(y: _appeared ? 0 : 18)
		.animation(
			.spring(response: 0.6, dampingFraction: 0.82).delay(0.12 + Double(index) * 0.08),
			value: _appeared
		)
	}
}
