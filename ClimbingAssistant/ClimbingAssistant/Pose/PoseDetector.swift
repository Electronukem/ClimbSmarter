import Vision
import AVFoundation
import Combine

/// Consumes camera frames, runs VNDetectHumanBodyPoseRequest on a background queue,
/// and publishes joint positions (normalized, SwiftUI top-left origin) on the main thread.
///
/// Primary joints (labeled in the overlay): leftWrist, rightWrist, leftAnkle, rightAnkle.
/// Skeleton-anchor joints (used for bone lines only): leftShoulder, rightShoulder,
/// leftHip, rightHip. All eight are included in `joints` when confidence ≥ 0.5.
final class PoseDetector: ObservableObject {

    // MARK: - Published state

    /// Normalized screen coordinates: x ∈ [0,1] left→right, y ∈ [0,1] top→bottom.
    /// Only joints whose confidence ≥ 0.5 are present.
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    // MARK: - Joint configuration

    /// The four joints the spec requires to be published and labeled.
    static let primaryJoints: Set<VNHumanBodyPoseObservation.JointName> = [
        .leftWrist, .rightWrist, .leftAnkle, .rightAnkle
    ]

    /// All joints we extract; the extra four act as skeleton anchors.
    private static let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .leftWrist, .rightWrist, .leftAnkle, .rightAnkle,
        .leftShoulder, .rightShoulder, .leftHip, .rightHip
    ]

    // MARK: - Private

    private var cancellable: AnyCancellable?
    private let detectionQueue = DispatchQueue(label: "com.climbingassistant.pose",
                                               qos: .userInitiated)

    // MARK: - Subscription

    func subscribe(to publisher: AnyPublisher<CMSampleBuffer, Never>) {
        cancellable = publisher
            .receive(on: detectionQueue)
            .sink { [weak self] sampleBuffer in
                self?.process(sampleBuffer)
            }
    }

    // MARK: - Detection

    private func process(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Orientation .up is correct when CameraManager sets portrait videoOrientation/
        // videoRotationAngle on the output connection (pixel data is already portrait).
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async { self.joints = [:] }
            return
        }

        guard let observation = request.results?.first else {
            DispatchQueue.main.async { self.joints = [:] }
            return
        }

        var detected: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        detected.reserveCapacity(Self.trackedJoints.count)

        for name in Self.trackedJoints {
            guard
                let point = try? observation.recognizedPoint(name),
                point.confidence >= 0.5
            else { continue }

            // Vision: origin is bottom-left, y increases upward.
            // Flip Y so origin becomes top-left (SwiftUI convention).
            detected[name] = CGPoint(x: point.location.x,
                                     y: 1.0 - point.location.y)
        }

        let result = detected
        DispatchQueue.main.async { self.joints = result }
    }
}
