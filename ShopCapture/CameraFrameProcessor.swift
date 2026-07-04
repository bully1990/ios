import AVFoundation
import CoreImage
import Foundation
import UIKit
import Vision

struct DetectedShopFrame {
    let image: UIImage
    let fullText: String
    let phoneNumber: String
}

@MainActor
protocol CameraFrameProcessorDelegate: AnyObject {
    func cameraFrameProcessor(_ processor: CameraFrameProcessor, didDetect frame: DetectedShopFrame)
    func cameraFrameProcessor(_ processor: CameraFrameProcessor, didChangeMessage message: String?)
}

final class CameraFrameProcessor: NSObject, ObservableObject {
    enum CaptureState {
        case idle
        case detecting
        case cooldown
    }

    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var message: String? {
        didSet {
            Task { @MainActor in
                delegate?.cameraFrameProcessor(self, didChangeMessage: message)
            }
        }
    }

    weak var delegate: CameraFrameProcessorDelegate?

    private let sessionQueue = DispatchQueue(label: "shopcapture.camera.session")
    private let visionQueue = DispatchQueue(label: "shopcapture.camera.vision", qos: .userInitiated)
    private let ciContext = CIContext()

    private var isConfigured = false
    private var frameIndex = 0
    private var isVisionBusy = false
    private var state: CaptureState = .idle
    private var stablePhoneNumber: String?
    private var stableCount = 0
    private var lastCaptureTime = Date.distantPast

    func start() {
        requestAccessIfNeeded { [weak self] granted in
            guard let self else { return }

            guard granted else {
                Task { @MainActor in
                    self.message = "相机权限未开启"
                }
                return
            }

            self.sessionQueue.async {
                self.configureSessionIfNeeded()

                guard self.isConfigured else {
                    return
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func markSaveCompleted() {
        state = .cooldown
        stablePhoneNumber = nil
        stableCount = 0

        Task { @MainActor in
            message = "已保存"

            try? await Task.sleep(nanoseconds: 1_500_000_000)

            state = .idle
            message = nil
        }
    }

    func markSaveFailed(_ error: Error) {
        print("Warning: failed to save record: \(error.localizedDescription)")
        state = .idle
        stablePhoneNumber = nil
        stableCount = 0
        message = "保存失败"
    }

    func setMessage(_ message: String?) {
        self.message = message
    }

    private func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            Task { @MainActor in
                message = "未找到后置摄像头"
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            Task { @MainActor in
                message = "相机初始化失败"
            }
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }

        isConfigured = true
    }

    private func process(sampleBuffer: CMSampleBuffer) {
        frameIndex += 1

        guard frameIndex % 3 == 0 else {
            return
        }

        guard !isVisionBusy, state == .idle else {
            return
        }

        isVisionBusy = true

        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                isVisionBusy = false
                return
            }

            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self else { return }
                defer { self.isVisionBusy = false }

                if let error {
                    print("Warning: Vision OCR failed: \(error.localizedDescription)")
                    return
                }

                self.handleVisionResults(request.results, pixelBuffer: pixelBuffer)
            }

            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.regionOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

            do {
                try handler.perform([request])
            } catch {
                isVisionBusy = false
                print("Warning: Vision request failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleVisionResults(_ results: [VNObservation]?, pixelBuffer: CVPixelBuffer) {
        guard let observations = results as? [VNRecognizedTextObservation] else {
            resetStability()
            return
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let fullText = lines.joined(separator: "\n")

        guard let phoneNumber = PhoneNumberExtractor.firstPhoneNumber(in: fullText) else {
            resetStability()
            return
        }

        if stablePhoneNumber == phoneNumber {
            stableCount += 1
        } else {
            stablePhoneNumber = phoneNumber
            stableCount = 1
        }

        guard stableCount >= 5 else {
            Task { @MainActor in
                message = "识别中 \(stableCount)/5"
            }
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastCaptureTime) > 2 else {
            resetStability()
            return
        }

        guard let image = makeUIImage(from: pixelBuffer) else {
            resetStability()
            return
        }

        lastCaptureTime = now
        state = .detecting

        let detectedFrame = DetectedShopFrame(image: image, fullText: fullText, phoneNumber: phoneNumber)

        Task { @MainActor in
            message = "正在保存"
            delegate?.cameraFrameProcessor(self, didDetect: detectedFrame)
        }
    }

    private func resetStability() {
        stablePhoneNumber = nil
        stableCount = 0
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }
}

extension CameraFrameProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        process(sampleBuffer: sampleBuffer)
    }
}
