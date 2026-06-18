//
//  FSDesign.swift
//  Feather
//
//  The FreeSign consumer design system: shared colors, cards,
//  buttons and friendly copy used across the new UI.
//

import SwiftUI
import IDeviceSwift

// MARK: - Theme
enum FSTheme {
	static let cardCornerRadius: CGFloat = 22
	static let buttonCornerRadius: CGFloat = 16

	static var accent: Color {
		Color(hex: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#004CFF")
	}

	static var accentGradient: LinearGradient {
		LinearGradient(
			colors: [accent, accent.opacity(0.75)],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	static func lightImpact() {
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	static func success() {
		UINotificationFeedbackGenerator().notificationOccurred(.success)
	}

	static func failure() {
		UINotificationFeedbackGenerator().notificationOccurred(.error)
	}
}

// MARK: - Card background
struct FSCardModifier: ViewModifier {
	var padding: CGFloat = 16

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.background(
				RoundedRectangle(cornerRadius: FSTheme.cardCornerRadius, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground))
			)
	}
}

extension View {
	func fsCard(padding: CGFloat = 16) -> some View {
		modifier(FSCardModifier(padding: padding))
	}
}

// MARK: - Buttons
/// Big rounded call-to-action, used for "Install", "Get Started", etc.
struct FSProminentButtonStyle: ButtonStyle {
	var isDestructive: Bool = false

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.system(.headline, design: .rounded).weight(.bold))
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 15)
			.background(
				RoundedRectangle(cornerRadius: FSTheme.buttonCornerRadius, style: .continuous)
					.fill(isDestructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.accentColor))
			)
			.opacity(configuration.isPressed ? 0.75 : 1)
			.scaleEffect(configuration.isPressed ? 0.985 : 1)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
	}
}

/// Small App Store-like capsule, used for "GET" and per-row actions.
struct FSCapsuleButtonStyle: ButtonStyle {
	var filled: Bool = false

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.system(.subheadline, design: .rounded).weight(.bold))
			.foregroundStyle(filled ? Color.white : Color.accentColor)
			.padding(.horizontal, 20)
			.padding(.vertical, 7)
			.background(
				Capsule().fill(filled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(uiColor: .quaternarySystemFill)))
			)
			.opacity(configuration.isPressed ? 0.7 : 1)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
	}
}

// MARK: - Status pill
struct FSStatusPill: View {
	let text: String
	let color: Color
	var icon: String? = nil

	var body: some View {
		HStack(spacing: 4) {
			if let icon {
				Image(systemName: icon)
					.font(.caption2.weight(.bold))
			}
			Text(text)
				.font(.system(.caption, design: .rounded).weight(.semibold))
		}
		.foregroundStyle(color)
		.padding(.horizontal, 9)
		.padding(.vertical, 4)
		.background(Capsule().fill(color.opacity(0.14)))
	}
}

// MARK: - Empty state (iOS 16 friendly ContentUnavailableView)
struct FSEmptyStateView: View {
	let systemImage: String
	let title: String
	let message: String
	var actionTitle: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		VStack(spacing: 14) {
			Image(systemName: systemImage)
				.font(.system(size: 46, weight: .medium))
				.foregroundStyle(Color.accentColor.opacity(0.8))

			VStack(spacing: 6) {
				Text(title)
					.font(.system(.title3, design: .rounded).weight(.bold))
				Text(message)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}

			if let actionTitle, let action {
				Button(actionTitle, action: action)
					.buttonStyle(FSCapsuleButtonStyle(filled: true))
					.padding(.top, 4)
			}
		}
		.padding(.horizontal, 40)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

// MARK: - Section header
struct FSSectionHeader: View {
	let title: String
	var subtitle: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(title)
				.font(.system(.title3, design: .rounded).weight(.bold))
			if let subtitle {
				Text(subtitle)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: - Friendly install vocabulary
extension InstallerStatusViewModel {
	/// Consumer-facing labels: no signing/server jargon.
	var friendlyStatusLabel: String {
		switch status {
		case .none: .localized("Getting your app ready…")
		case .ready: .localized("Almost there…")
		case .sendingManifest, .sendingPayload: .localized("Handing off to iOS…")
		case .installing: .localized("Installing…")
		case .completed: .localized("Installed!")
		case .broken: .localized("Something went wrong")
		}
	}
}
