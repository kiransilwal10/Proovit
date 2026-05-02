//
//  CameraService.swift
//  Proovit
//
//  AVCaptureSession wrapper exposing a SwiftUI-friendly @Observable API.
//
//  Threading model:
//   - The class itself runs on @MainActor (project default), so views
//     bind to its observed properties cleanly.
//   - The session itself is configured and run on a private serial
//     dispatch queue. Apple explicitly warns against doing AV setup
//     on the main thread because it can stutter UI.
//   - The photo-capture delegate fires on AVFoundation's own queue;
//     it's `nonisolated` and hops back to MainActor to resume the
//     awaiting continuation safely.
//

// 💡 Learn: @preconcurrency tells Swift 6 to accept AVFoundation types
// across actor boundaries even though Apple hasn't annotated them as
// Sendable yet. AVFoundation predates Swift Concurrency by a decade
// and is safe in practice when used from a single dedicated queue.
@preconcurrency import AVFoundation
import Foundation
import Observation

// 💡 Learn: `@unchecked Sendable` tells the compiler we manually
// guarantee thread safety. Required because we pass `self` into the
// session queue as the AVCapturePhotoCaptureDelegate. Safety here
// rests on three facts: (1) all mutable observed state is touched
// only on @MainActor, (2) the session queue only mutates AVFoundation
// objects (which AVFoundation itself synchronizes), (3) the capture
// continuation is set and resumed on MainActor.
@Observable
final class CameraService: NSObject, @unchecked Sendable {

    enum AuthorizationStatus: Sendable {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    enum CameraError: Error {
        case noCameraAvailable
        case captureFailed
        case sessionConfigurationFailed
        case notAuthorized
    }

    // MARK: - Observed state

    var authorizationStatus: AuthorizationStatus
    var isRunning: Bool = false
    var isCapturing: Bool = false
    var currentPosition: AVCaptureDevice.Position = .back
    var flashMode: AVCaptureDevice.FlashMode = .off

    /// Stable session reference used by the preview layer. Not @Observable
    /// — views grab it once via `makeUIView` and don't re-render on the
    /// session's internal state.
    let session: AVCaptureSession

    // MARK: - Private

    private let sessionQueue: DispatchQueue
    private let photoOutput: AVCapturePhotoOutput
    private var captureContinuation: CheckedContinuation<Data, Error>?

    override init() {
        self.session = AVCaptureSession()
        self.sessionQueue = DispatchQueue(label: "com.proovit.camera-session")
        self.photoOutput = AVCapturePhotoOutput()
        self.authorizationStatus = Self.currentAuthorizationStatus()
        super.init()
    }

    // MARK: - Authorization

    private static func currentAuthorizationStatus() -> AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .denied
        }
    }

    /// Asks the user for camera access. Updates `authorizationStatus`
    /// and returns whether access was granted.
    func requestAuthorization() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
        return granted
    }

    // MARK: - Configuration

    /// Configures inputs and outputs for the current camera position.
    /// Idempotent — safe to call again after a flip.
    func configure() async throws {
        guard authorizationStatus == .authorized else {
            throw CameraError.notAuthorized
        }

        // Capture immutable references so the session-queue closure
        // doesn't have to read MainActor state.
        let position = currentPosition
        let session = self.session
        let photoOutput = self.photoOutput
        let queue = self.sessionQueue

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                session.beginConfiguration()
                session.sessionPreset = .photo

                // Wipe existing inputs so reconfigure (e.g. flip) starts clean.
                for input in session.inputs {
                    session.removeInput(input)
                }

                let discovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: position
                )
                guard let device = discovery.devices.first else {
                    session.commitConfiguration()
                    continuation.resume(throwing: CameraError.noCameraAvailable)
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else {
                        session.commitConfiguration()
                        continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                        return
                    }
                    session.addInput(input)

                    if !session.outputs.contains(photoOutput) {
                        guard session.canAddOutput(photoOutput) else {
                            session.commitConfiguration()
                            continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                            return
                        }
                        session.addOutput(photoOutput)
                    }

                    session.commitConfiguration()
                    continuation.resume()
                } catch {
                    session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Lifecycle

    func start() {
        let session = self.session
        sessionQueue.async {
            guard !session.isRunning else { return }
            session.startRunning()
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    func stop() {
        let session = self.session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    // MARK: - Controls

    /// Switches between front and back cameras. Reconfigures the session.
    func flipCamera() async throws {
        currentPosition = (currentPosition == .back) ? .front : .back
        try await configure()
    }

    /// Cycles flash off → auto → on → off.
    func cycleFlashMode() {
        switch flashMode {
        case .off:       flashMode = .auto
        case .auto:      flashMode = .on
        case .on:        flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - Capture

    /// Takes one photo. Returns the JPEG data. Throws if a capture is
    /// already in flight or the underlying session fails.
    func capturePhoto() async throws -> Data {
        guard captureContinuation == nil else { throw CameraError.captureFailed }

        isCapturing = true
        defer { isCapturing = false }

        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }

        let photoOutput = self.photoOutput
        let queue = self.sessionQueue

        return try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            queue.async {
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {

    // 💡 Learn: This delegate fires on AVFoundation's own queue, NOT
    // ours. The method must be `nonisolated` so the compiler doesn't
    // expect MainActor isolation. We hop back to MainActor via Task to
    // safely touch the continuation, which lives on @MainActor state.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        let nsError = error as NSError?

        Task { @MainActor in
            defer { self.captureContinuation = nil }
            guard let continuation = self.captureContinuation else { return }

            if let nsError {
                continuation.resume(throwing: nsError)
            } else if let data {
                continuation.resume(returning: data)
            } else {
                continuation.resume(throwing: CameraError.captureFailed)
            }
        }
    }
}
