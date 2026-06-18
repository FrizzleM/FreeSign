//
//  FSInstallProgressView.swift
//  Feather
//
//  Consumer install sheet. The machinery is identical to the old
//  InstallPreviewView (ArchiveHandler → ServerInstaller / idevice,
//  shortcut completion callback) — only the presentation changed.
//

import SwiftUI
import IDeviceSwift
import NimbleViews
import OSLog

// MARK: - View
struct FSInstallProgressView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 0
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?

	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller

	@State var isSharing: Bool

	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
		let viewModel = InstallerStatusViewModel(isIdevice: UserDefaults.standard.integer(forKey: "Feather.installationMethod") == 1)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: try! ServerInstaller(app: app, viewModel: viewModel))
	}

	// MARK: Body
	var body: some View {
		VStack(spacing: 0) {
			Spacer()

			_progressRing

			VStack(spacing: 4) {
				Text(app.name ?? .localized("Unknown"))
					.font(.system(.headline, design: .rounded).weight(.bold))
					.lineLimit(1)

				Text(_statusText)
					.font(.subheadline)
					.foregroundStyle(_isBroken ? Color.red : Color.secondary)
					.multilineTextAlignment(.center)
					.lineLimit(2)
					.animation(.smooth, value: _statusText)
			}
			.padding(.top, 18)
			.padding(.horizontal, 24)

			Spacer()

			if viewModel.isCompleted {
				Button {
					UIApplication.openApp(with: app.identifier ?? "")
				} label: {
					Label(.localized("Open App"), systemImage: "arrow.up.forward.app.fill")
				}
				.buttonStyle(FSProminentButtonStyle())
				.padding(.horizontal, 24)
				.padding(.bottom, 28)
				.compatTransition()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			if case .completed = newStatus {
				FSTheme.success()
				PostSigningShortcutCoordinator.completePendingInstall(
					for: app.uuid,
					bundleID: app.identifier
				)
			}

			if _installationMethod == 0 {
				if case .ready = newStatus {
					if _serverMethod == 0 {
						UIApplication.shared.open(URL(string: installer.iTunesLink)!)
					} else if _serverMethod == 1 {
						_isWebviewPresenting = true
					}
				}

				if case .sendingPayload = newStatus, _serverMethod == 1 {
					_isWebviewPresenting = false
				}

				if case .installing = newStatus {
					if progressTask == nil {
						progressTask = startInstallProgressPolling(
							bundleID: app.identifier!,
							viewModel: viewModel
						)
					}
				}

				switch newStatus {
				case .completed, .broken(_):
					progressTask?.cancel()
					progressTask = nil
					#if !targetEnvironment(macCatalyst)
					BackgroundAudioManager.shared.stop()
					#endif
				default:
					break
				}
			}
		}
		.onAppear(perform: _install)

		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif

		.onDisappear {
			progressTask?.cancel()
			progressTask = nil

			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}

	// MARK: Presentation
	private var _isBroken: Bool {
		if case .broken = viewModel.status { return true }
		return false
	}

	private var _statusText: String {
		if isSharing {
			return viewModel.isCompleted
				? .localized("Saved!")
				: .localized("Packaging a copy for you…")
		}

		if case .broken(let error) = viewModel.status {
			return error.localizedDescription
		}

		return viewModel.friendlyStatusLabel
	}

	@ViewBuilder
	private var _progressRing: some View {
		ZStack {
			Circle()
				.stroke(Color.accentColor.opacity(0.15), lineWidth: 5)
				.frame(width: 108, height: 108)

			Circle()
				.trim(from: 0, to: viewModel.isCompleted ? 1 : max(0.02, viewModel.overallProgress))
				.stroke(
					_isBroken ? Color.red : Color.accentColor,
					style: StrokeStyle(lineWidth: 5, lineCap: .round)
				)
				.rotationEffect(.degrees(-90))
				.frame(width: 108, height: 108)
				.animation(.smooth, value: viewModel.overallProgress)

			FRAppIconView(app: app, size: 80)

			if viewModel.isCompleted {
				Image(systemName: "checkmark.circle.fill")
					.font(.title2)
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, .green)
					.background(Circle().fill(.white).padding(3))
					.offset(x: 38, y: 38)
					.compatTransition()
			}
		}
	}

	// MARK: Install (unchanged logic)
	private func _install() {
		guard isSharing || app.identifier != Bundle.main.bundleIdentifier! || _installationMethod == 1 else {
			UIAlertController.showAlertWithOk(
				title: .localized("Install"),
				message: .localized("You cannot update ‘%@‘ with itself, please use an alternative tool to update it.", arguments: Bundle.main.name)
			)
			return
		}

		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()

				let packageUrl = try await handler.archive()

				if await !isSharing {
					if await _installationMethod == 0 {
						await MainActor.run {
							installer.packageUrl = packageUrl
							viewModel.status = .ready
						}

						if case .installing = await viewModel.status {
							let task = await startInstallProgressPolling(
								bundleID: app.identifier!,
								viewModel: viewModel
							)

							await MainActor.run {
								progressTask = task
							}
						}
					} else if await _installationMethod == 1 {
						let handler = await InstallationProxy(viewModel: viewModel)
						try await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
					}
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)

					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch {
				await progressTask?.cancel()

				await MainActor.run {
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: String(describing: error),
						action: {
							HeartbeatManager.shared.start(true)
							dismiss()
						}
					)
				}
			}
		}
	}

	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		Task.detached(priority: .background) {
			var hasStarted = false

			while !Task.isCancelled {
				let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

				if rawProgress > 0 {
					hasStarted = true
				}

				let progress = await hasStarted
					? _normalizeInstallProgress(rawProgress)
					: 0.0

				Logger.misc.info("Install progress for \(bundleID): \(progress)")

				await MainActor.run {
					viewModel.installProgress = progress
				}

				if hasStarted && rawProgress == 0 {
					await MainActor.run {
						viewModel.installProgress = 1.0
						viewModel.status = .completed(.success(()))
					}
					break
				}

				try? await Task.sleep(nanoseconds: 1_000_000) // 1 ms
			}
		}
	}

	private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
		min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
	}
}
