import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let deviceOrientation: UIDeviceOrientation
    let guideLayerRect: CGRect
    let onCaptureRegionChange: (CGRect, CGSize) -> Void

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.updateOrientation(deviceOrientation)
        view.updateGuideLayerRect(guideLayerRect, onChange: onCaptureRegionChange)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.updateOrientation(deviceOrientation)
        uiView.updateGuideLayerRect(guideLayerRect, onChange: onCaptureRegionChange)
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private var guideLayerRect = CGRect.zero
    private var onCaptureRegionChange: ((CGRect, CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        publishCaptureRegion()
    }

    func updateOrientation(_ deviceOrientation: UIDeviceOrientation) {
        guard let videoRotationAngle = videoRotationAngle(for: deviceOrientation),
              let connection = videoPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(videoRotationAngle) else {
            return
        }

        connection.videoRotationAngle = videoRotationAngle
        publishCaptureRegion()
    }

    func updateGuideLayerRect(_ rect: CGRect, onChange: @escaping (CGRect, CGSize) -> Void) {
        onCaptureRegionChange = onChange

        guard rect.width > 0, rect.height > 0 else {
            return
        }

        guideLayerRect = rect
        publishCaptureRegion()
    }

    private func publishCaptureRegion() {
        guard guideLayerRect.width > 0, guideLayerRect.height > 0, bounds.width > 0, bounds.height > 0 else {
            return
        }

        onCaptureRegionChange?(guideLayerRect, bounds.size)
    }
}

private func videoRotationAngle(for deviceOrientation: UIDeviceOrientation) -> CGFloat? {
        switch deviceOrientation {
        case .portrait:
            90
        case .portraitUpsideDown:
            270
        case .landscapeLeft:
            0
        case .landscapeRight:
            180
        default:
            nil
        }
}
