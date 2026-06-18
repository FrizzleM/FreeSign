//
//  FSRootView.swift
//  Feather
//
//  Root shell of the consumer UI: tab bar, floating download
//  indicator and the install hand-off triggered by the
//  post-signing shortcut callback (freesign://).
//

import SwiftUI
import CoreData

// MARK: - View
struct FSRootView: View {
	enum Tab: Hashable {
		case discover
		case myApps
		case settings
	}

	@State private var _selectedTab: Tab = .discover
	@State private var _installPresenting: AnyApp?

	#if DEBUG
	// lets UI smoke tests jump to a tab: -FSInitialTab myApps|settings
	init() {
		switch UserDefaults.standard.string(forKey: "FSInitialTab") {
		case "myApps": __selectedTab = State(initialValue: .myApps)
		case "settings": __selectedTab = State(initialValue: .settings)
		default: break
		}
	}
	#endif

	@StateObject private var _downloadManager = DownloadManager.shared

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	// MARK: Body
	var body: some View {
		TabView(selection: $_selectedTab) {
			FSDiscoverView()
				.tabItem {
					Label(.localized("Discover"), systemImage: "sparkles")
				}
				.tag(Tab.discover)

			FSMyAppsView(selectedTab: $_selectedTab)
				.tabItem {
					Label(.localized("My Apps"), systemImage: "square.stack.3d.up.fill")
				}
				.tag(Tab.myApps)

			FSSettingsView()
				.tabItem {
					Label(.localized("Settings"), systemImage: "gearshape.fill")
				}
				.tag(Tab.settings)
		}
		.overlay(alignment: .bottom) {
			FSDownloadPulseView(downloadManager: _downloadManager)
				.padding(.bottom, 60)
		}
		.sheet(item: $_installPresenting) { app in
			FSInstallProgressView(app: app.base, isSharing: app.archive)
				.presentationDetents([.height(300)])
				.presentationDragIndicator(.visible)
		}
		.onReceive(NotificationCenter.default.publisher(for: PostSigningShortcutCoordinator.installAppNotification)) { notification in
			if
				let uuid = notification.object as? String,
				let app = _signedApps.first(where: { $0.uuid == uuid })
			{
				_installPresenting = AnyApp(base: app)
			} else if let latest = _signedApps.first {
				_installPresenting = AnyApp(base: latest)
			}
		}
	}
}

// MARK: - Floating download indicator
struct FSDownloadPulseView: View {
	@ObservedObject var downloadManager: DownloadManager

	var body: some View {
		ZStack {
			if let download = downloadManager.downloads.first {
				FSDownloadPulseCard(
					download: download,
					extraCount: downloadManager.downloads.count - 1
				)
				.transition(.move(edge: .bottom).combined(with: .opacity))
			}
		}
		.animation(.spring(response: 0.35, dampingFraction: 0.85), value: downloadManager.downloads.count)
	}
}

private struct FSDownloadPulseCard: View {
	let download: Download
	let extraCount: Int

	@State private var _progress: Double = 0
	@State private var _unpackageProgress: Double = 0

	private var _overallProgress: Double {
		download.onlyArchiving
			? _unpackageProgress
			: (0.3 * _unpackageProgress) + (0.7 * _progress)
	}

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
				Circle()
					.trim(from: 0, to: max(0.03, _overallProgress))
					.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
					.rotationEffect(.degrees(-90))
					.animation(.smooth, value: _overallProgress)
				Image(systemName: "arrow.down")
					.font(.caption2.weight(.bold))
					.foregroundStyle(Color.accentColor)
			}
			.frame(width: 28, height: 28)

			VStack(alignment: .leading, spacing: 1) {
				Text(_title)
					.font(.system(.footnote, design: .rounded).weight(.semibold))
					.lineLimit(1)
				Text(verbatim: "\(Int(_overallProgress * 100))%")
					.font(.caption2)
					.foregroundStyle(.secondary)
					.contentTransition(.numericText())
			}

			if extraCount > 0 {
				Text(verbatim: "+\(extraCount)")
					.font(.caption2.weight(.bold))
					.foregroundStyle(.secondary)
					.padding(6)
					.background(Circle().fill(Color(uiColor: .quaternarySystemFill)))
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(
			Capsule()
				.fill(.regularMaterial)
				.shadow(color: .black.opacity(0.15), radius: 12, y: 4)
		)
		.padding(.horizontal, 24)
		.onReceive(download.$progress) { _progress = $0 }
		.onReceive(download.$unpackageProgress) { _unpackageProgress = $0 }
	}

	private var _title: String {
		download.onlyArchiving
			? .localized("Adding to My Apps…")
			: .localized("Downloading %@", arguments: download.fileName)
	}
}
