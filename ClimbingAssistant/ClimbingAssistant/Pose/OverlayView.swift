import SwiftUI
import Vision

/// Transparent SwiftUI view drawn on top of the camera preview.
///
/// Coordinate mapping: `joints` values are already in SwiftUI's top-left coordinate
/// system (PoseDetector flips Vision's bottom-left Y). Multiplying by the view's
/// geometry size converts normalized [0,1] coords to pixel positions.
struct OverlayView: View {

    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    // MARK: - Configuration

    private let dotRadius: CGFloat = 8
    private let dotColor = Color.yellow
    private let dotStrokeColor = Color.white
    private let lineColor = Color.cyan.opacity(0.85)
    private let lineWidth: CGFloat = 2.5
    private let labelOffset: CGFloat = 13
    private let labelFont = Font.system(size: 13, weight: .bold, design: .rounded)

    /// Human-readable short labels for the four primary joints.
    private let labels: [VNHumanBodyPoseObservation.JointName: String] = [
        .leftWrist:  "LW",
        .rightWrist: "RW",
        .leftAnkle:  "LA",
        .rightAnkle: "RA"
    ]

    /// Skeleton bone definitions: draw a line from the first joint to the second
    /// only if both are present in `joints` with sufficient confidence.
    private let skeleton: [(VNHumanBodyPoseObservation.JointName,
                            VNHumanBodyPoseObservation.JointName)] = [
        (.leftWrist,   .leftShoulder),
        (.rightWrist,  .rightShoulder),
        (.leftAnkle,   .leftHip),
        (.rightAnkle,  .rightHip)
    ]

    // MARK: - View

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                drawSkeleton(context: &context, size: size)
                drawJoints(context: &context, size: size)
            }
        }
    }

    // MARK: - Drawing helpers

    /// Converts a normalized joint position to pixel coordinates in `size`.
    private func pixel(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width,
                y: normalized.y * size.height)
    }

    private func drawSkeleton(context: inout GraphicsContext, size: CGSize) {
        for (fromName, toName) in skeleton {
            guard
                let fromNorm = joints[fromName],
                let toNorm   = joints[toName]
            else { continue }

            let from = pixel(fromNorm, in: size)
            let to   = pixel(toNorm,   in: size)

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
    }

    private func drawJoints(context: inout GraphicsContext, size: CGSize) {
        for (name, normalized) in joints {
            let center = pixel(normalized, in: size)

            // Filled circle
            let rect = CGRect(x: center.x - dotRadius,
                              y: center.y - dotRadius,
                              width:  dotRadius * 2,
                              height: dotRadius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
            context.stroke(Path(ellipseIn: rect),
                           with: .color(dotStrokeColor),
                           lineWidth: 1.5)

            // Label — only for the four primary joints
            if let label = labels[name] {
                let text = Text(label)
                    .font(labelFont)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
                context.draw(text,
                             at: CGPoint(x: center.x + dotRadius + labelOffset,
                                         y: center.y))
            }
        }
    }
}
