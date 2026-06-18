//
//  FSAppDetailView.swift
//  Feather
//
//  Consumer product page for an app from a catalog: hero, Get
//  button, screenshots, what's new and details.
//

import SwiftUI
import AltSourceKit
import NukeUI

// MARK: - View
struct FSAppDetailView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var _isDescriptionExpanded = false

	var source: ASRepository
	var app: ASRepository.App

	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 26) {
					_hero
					if let screenshotURLs = app.screenshotURLs, !screenshotURLs.isEmpty {
						_screenshots(screenshotURLs)
					}
					if
						let version = app.currentVersion,
						let whatsNew = app.currentAppVersion?.localizedDescription
					{
						_whatsNew(version: version, text: whatsNew)
					}
					if let description = app.localizedDescription {
						_description(description)
					}
					_details
				}
				.padding(20)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark.circle.fill")
							.symbolRenderingMode(.hierarchical)
							.font(.title2)
							.foregroundStyle(.secondary)
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						let sharedString = """
						\(app.currentName) - \(app.currentVersion ?? "0")
						\(app.currentDescription ?? "")
						\(source.website?.absoluteString ?? source.name ?? "")
						"""
						UIActivityViewController.show(activityItems: [sharedString])
					} label: {
						Image(systemName: "square.and.arrow.up")
					}
				}
			}
			.navigationBarTitleDisplayMode(.inline)
		}
	}

	// MARK: Hero
	@ViewBuilder
	private var _hero: some View {
		HStack(spacing: 16) {
			FSRemoteAppIconView(url: app.iconURL, size: 100)

			VStack(alignment: .leading, spacing: 5) {
				Text(app.currentName)
					.font(.system(.title2, design: .rounded).weight(.bold))
					.lineLimit(2)

				Text(app.developer ?? source.name ?? .localized("Unknown"))
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(1)

				Spacer(minLength: 6)

				HStack(spacing: 10) {
					FSGetButton(app: app, filled: true)

					if let size = app.size {
						Text(size.formattedByteCount)
							.font(.system(.caption, design: .rounded).weight(.semibold))
							.foregroundStyle(.secondary)
					}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	// MARK: Screenshots
	@ViewBuilder
	private func _screenshots(_ urls: [URL]) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			FSSectionHeader(title: .localized("Preview"))

			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 12) {
					ForEach(urls.indices, id: \.self) { index in
						LazyImage(url: urls[index]) { state in
							if let image = state.image {
								image
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(maxHeight: 380)
									.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
									.overlay {
										RoundedRectangle(cornerRadius: 18, style: .continuous)
											.strokeBorder(.gray.opacity(0.25), lineWidth: 1)
									}
							}
						}
					}
				}
				.padding(.horizontal, 20)
			}
			.padding(.horizontal, -20)
		}
	}

	// MARK: What's new
	@ViewBuilder
	private func _whatsNew(version: String, text: String) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			FSSectionHeader(title: .localized("What's New"))

			VStack(alignment: .leading, spacing: 6) {
				HStack {
					Text(verbatim: .localized("Version %@", arguments: version))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
						.foregroundStyle(.secondary)
					Spacer()
					if let date = app.currentDate?.date {
						Text(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				Text(text)
					.font(.subheadline)
			}
			.fsCard()
		}
	}

	// MARK: Description
	@ViewBuilder
	private func _description(_ text: String) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			FSSectionHeader(title: .localized("About this app"))

			VStack(alignment: .leading, spacing: 8) {
				Text(text)
					.font(.subheadline)
					.lineLimit(_isDescriptionExpanded ? nil : 4)

				Button {
					withAnimation(.snappy) {
						_isDescriptionExpanded.toggle()
					}
				} label: {
					Text(_isDescriptionExpanded ? .localized("Less") : .localized("More"))
						.font(.system(.subheadline, design: .rounded).weight(.semibold))
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.fsCard()
		}
	}

	// MARK: Details
	@ViewBuilder
	private var _details: some View {
		VStack(alignment: .leading, spacing: 8) {
			FSSectionHeader(title: .localized("Information"))

			VStack(spacing: 0) {
				if let name = source.name {
					_detailRow(.localized("Catalog"), value: name)
				}
				if let developer = app.developer {
					_detailRow(.localized("Developer"), value: developer)
				}
				if let version = app.currentVersion {
					_detailRow(.localized("Version"), value: version)
				}
				if let size = app.size {
					_detailRow(.localized("Size"), value: size.formattedByteCount)
				}
				if let category = app.category {
					_detailRow(.localized("Category"), value: category.capitalized)
				}
				if let date = app.currentDate?.date {
					_detailRow(
						.localized("Updated"),
						value: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
					)
				}
			}
			.fsCard(padding: 4)
		}
	}

	@ViewBuilder
	private func _detailRow(_ title: String, value: String) -> some View {
		HStack {
			Text(title)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Spacer()
			Text(value)
				.font(.subheadline.weight(.medium))
				.multilineTextAlignment(.trailing)
				.lineLimit(2)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 11)
	}
}
