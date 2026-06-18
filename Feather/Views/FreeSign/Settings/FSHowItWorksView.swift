//
//  FSHowItWorksView.swift
//  Feather
//
//  Plain-language explanation of what happens when the user
//  taps Install.
//

import SwiftUI

struct FSHowItWorksView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				Text(.localized("Installing an app outside the App Store is normally a chore. FreeSign turns it into one tap. Here's what happens behind the scenes:"))
					.font(.subheadline)
					.foregroundStyle(.secondary)

				_step(
					number: 1,
					icon: "sparkles",
					title: .localized("You pick an app"),
					text: .localized("Browse the catalogs in Discover, or add your own app file (.ipa) to My Apps.")
				)

				_step(
					number: 2,
					icon: "checkmark.seal.fill",
					title: .localized("FreeSign personalizes it"),
					text: .localized("Every iPhone only accepts apps that carry a valid signature. FreeSign re-signs the app with your signing pass — that's the \"preparing\" step you see.")
				)

				_step(
					number: 3,
					icon: "arrow.down.circle.fill",
					title: .localized("iOS installs it"),
					text: .localized("FreeSign hands the prepared app to iOS, which installs it on your Home Screen like any other app.")
				)

				VStack(alignment: .leading, spacing: 8) {
					Label {
						Text(.localized("About passes"))
							.font(.system(.headline, design: .rounded))
					} icon: {
						Image(systemName: "info.circle.fill")
							.foregroundStyle(Color.accentColor)
					}

					Text(.localized("Signing passes expire or occasionally stop working — that's normal. When it happens, apps may refuse to open. Just fetch fresh passes in Settings and reinstall the app; your data stays put."))
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.fsCard()
				.padding(.top, 6)
			}
			.padding(20)
		}
		.background(Color(uiColor: .systemGroupedBackground))
		.navigationTitle(.localized("How It Works"))
		.navigationBarTitleDisplayMode(.inline)
	}

	@ViewBuilder
	private func _step(number: Int, icon: String, title: String, text: String) -> some View {
		HStack(alignment: .top, spacing: 14) {
			ZStack {
				Circle()
					.fill(FSTheme.accentGradient)
					.frame(width: 38, height: 38)
				Image(systemName: icon)
					.font(.subheadline.weight(.bold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(verbatim: .localized("Step %lld", arguments: number))
					.font(.system(.caption, design: .rounded).weight(.bold))
					.foregroundStyle(Color.accentColor)
					.textCase(.uppercase)
				Text(title)
					.font(.system(.headline, design: .rounded))
				Text(text)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.fsCard()
	}
}
