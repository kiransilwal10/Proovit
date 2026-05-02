//
//  CameraView.swift
//  Proovit
//
//  Full-screen camera modal. Configures the session on appear, runs
//  while visible, stops on dismiss. After capture, swaps to
//  CapturePreviewView for the confirm/save step.
//
//  Camera-only product principle: there is NO gallery affordance here,
//  ever. Adding `PHPicker`, `UIImagePickerController(.photoLibrary)`,
//  or any "import" path would violate the brand contract.
//
//  ⚠️ REQUIRES NSCameraUsageDescription in Info.plist. The project uses
//  GENERATE_INFOPLIST_FILE = YES — add the key in Xcode's target Info
//  tab. Without it, requestAccess() crashes the app.
//

import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct CameraView: View {
    /// If supplied (e.g. from the "Capture <Name>" CTA on Tracker
    /// Detail), the camera opens with that tracker preselected. From
    /// the bottom-bar FAB we pass nil and default to the first tracker.
    let preselectedTrackerID: UUID?

    init(preselectedTrackerID: UUID? = nil) {
        self.preselectedTrackerID = preselectedTrackerID
    }

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    // 💡 Learn: @State on a non-trivial @Observable class is the iOS-17+
    // pattern. SwiftUI tracks the reference; the @Observable macro
    // tracks property reads inside the body for surgical re-renders.
    @State private var camera = CameraService()
    @State private var capturedData: Data?
    @State private var selectedTrackerID: UUID?

    var body: some View {
        Group {
            if let capturedData, let tracker = currentTracker {
                CapturePreviewView(
                    imageData: capturedData,
                    tracker: tracker,
                    onRetake: { self.capturedData = nil },
                    onSaved: { dismiss() }
                )
            } else {
                liveCameraContent
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await ensureAuthorizedAndConfigured()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var currentTracker: Tracker? {
        if let id = selectedTrackerID, let tracker = trackers.first(where: { $0.id == id }) {
            return tracker
        }
        return trackers.first
    }

    // MARK: - Auth-state branching

    @ViewBuilder
    private var liveCameraContent: some View {
        switch camera.authorizationStatus {
        case .authorized:
            authorizedContent
        case .notDetermined:
            requestingContent
        case .denied, .restricted:
            deniedContent
        }
    }

    // MARK: - Live camera

    private var authorizedContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var topControls: some View {
        HStack(alignment: .center) {
            closeButton
            Spacer()
            trackerPicker
            Spacer()
            // Symmetric placeholder so the picker stays visually centered.
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black.opacity(0.4)))
        }
    }

    private var trackerPicker: some View {
        Menu {
            ForEach(trackers) { tracker in
                Button {
                    selectedTrackerID = tracker.id
                } label: {
                    Label(tracker.name, systemImage: tracker.iconSymbolName)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let tracker = currentTracker {
                    Circle()
                        .fill(Theme.trackerColor(named: tracker.colorAssetName))
                        .frame(width: 8, height: 8)
                }
                Text(currentTracker?.name ?? "Pick tracker")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Capsule().fill(.black.opacity(0.4)))
        }
        .disabled(trackers.isEmpty)
    }

    private var bottomControls: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                flashButton
                Spacer()
                shutterButton
                Spacer()
                flipButton
            }

            Text("Camera only — no gallery uploads")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
            }
        }
        .disabled(camera.isCapturing || currentTracker == nil)
        .opacity(camera.isCapturing ? 0.5 : 1.0)
    }

    private var flashButton: some View {
        Button {
            camera.cycleFlashMode()
        } label: {
            Image(systemName: flashIconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
    }

    private var flashIconName: String {
        switch camera.flashMode {
        case .off:       return "bolt.slash"
        case .auto:      return "bolt.badge.a"
        case .on:        return "bolt.fill"
        @unknown default: return "bolt.slash"
        }
    }

    private var flipButton: some View {
        Button {
            Task { try? await camera.flipCamera() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Auth-blocked states

    private var requestingContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView().tint(.white)
        }
    }

    private var deniedContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Camera access required")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Proovit captures progress photos directly from the camera. Enable camera access in Settings to continue.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Lifecycle helpers

    private func ensureAuthorizedAndConfigured() async {
        switch camera.authorizationStatus {
        case .notDetermined:
            let granted = await camera.requestAuthorization()
            if granted { await startCamera() }
        case .authorized:
            await startCamera()
        case .denied, .restricted:
            break
        }

        if selectedTrackerID == nil {
            selectedTrackerID = preselectedTrackerID ?? trackers.first?.id
        }
    }

    private func startCamera() async {
        do {
            try await camera.configure()
            camera.start()
        } catch {
            // Configuration failures (e.g. running on simulator) just leave
            // the preview blank. We don't surface a message because the
            // primary failure mode — denied auth — has its own dedicated
            // screen above.
        }
    }

    private func capture() async {
        do {
            let data = try await camera.capturePhoto()
            capturedData = data
        } catch {
            // For Step 6 we silently no-op; v1.0 polish adds a toast.
        }
    }
}
