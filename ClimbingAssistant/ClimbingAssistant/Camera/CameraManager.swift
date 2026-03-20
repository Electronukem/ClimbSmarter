import AVFoundation
import Combine

/// Manages the AVCaptureSession, publishes raw CMSampleBuffers from the back camera.
/// All session configuration runs on a dedicated serial queue; permission UI changes
/// are dispatched back to the main thread via @Published.
final class CameraManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var permissionDenied = false

    // MARK: - Public interface

    var captureSession: AVCaptureSession { session }

    /// Downstream subscribers receive every camera frame on whatever thread
    /// AVFoundation delivers it (a capture queue). PoseDetector hops off from there.
    var framePublisher: AnyPublisher<CMSampleBuffer, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    // MARK: - Private

    private let session = AVCaptureSession()
    private let frameSubject = PassthroughSubject<CMSampleBuffer, Never>()
    private let sessionQueue = DispatchQueue(label: "com.climbingassistant.session",
                                             qos: .userInitiated)

    // MARK: - Lifecycle

    func start() {
        checkPermission()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Permission

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async { self.configureSession() }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    // MARK: - Session setup

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        // Back camera input
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        // Video data output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let captureQueue = DispatchQueue(label: "com.climbingassistant.capture",
                                         qos: .userInitiated)
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        // Portrait orientation — tells AVFoundation to deliver rotated pixel data
        // so Vision receives a portrait-oriented buffer and can use .up orientation.
        //
        // Note: On iOS 17+ videoOrientation is deprecated; use videoRotationAngle instead.
        // The #available guard below keeps both old and new devices happy.
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90   // 90° = portrait
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            connection.isVideoMirrored = false
        }

        sessionQueue.async { self.session.startRunning() }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameSubject.send(sampleBuffer)
    }
}
