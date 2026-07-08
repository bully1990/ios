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
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
              let connection = videoPreviewLayer.connection,
              connection.isVideoOrientationSupported else {
            return
        }

        connection.videoOrientation = videoOrientation
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

private extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        default:
            return nil
        }
    }
}
