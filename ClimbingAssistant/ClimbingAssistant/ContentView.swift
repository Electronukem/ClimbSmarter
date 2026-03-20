import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var detector = PoseDetector()

    var body: some View {
        ZStack {
            if camera.permissionDenied {
                PermissionDeniedView()
            } else {
                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()
                OverlayView(joints: detector.joints)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            camera.start()
            detector.subscribe(to: camera.framePublisher)
        }
        .onDisappear {
            camera.stop()
        }
    }
}
