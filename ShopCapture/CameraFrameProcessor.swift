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
    private enum Constants {
        static let frameProcessingInterval = 2
        static let requiredStableDetections = 1
        static let automaticCaptureDelay: TimeInterval = 3
        static let maximumZoomFactor: CGFloat = 6
    }

    private enum RecognitionMode {
        case automatic
        case manual
    }

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
    @Published private(set) var isRecognizing = false
    @Published private(set) var zoomFactor: CGFloat = 1

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
    private var pendingAutomaticPhoneNumberKey: String?
    private var pendingAutomaticCaptureDeadline: Date?
    private var lastCaptureTime = Date.distantPast
    private var currentImageOrientation: CGImagePropertyOrientation = .up
    private var currentVideoRotationAngle: CGFloat = 90
    private var cameraDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestImageOrientation: CGImagePropertyOrientation = .up
    private var isAutomaticDetectionEnabled = false
    private var captureGuideLayerRect = CGRect.zero
    private var capturePreviewSize = CGSize.zero
    private var automaticallySavedPhoneNumberKeys = Set<String>()

    func start(automaticDetection: Bool) {
        latestPixelBuffer = nil
        resetStability()
        isAutomaticDetectionEnabled = automaticDetection
        if automaticDetection {
            automaticallySavedPhoneNumberKeys.removeAll()
        }

        Task { @MainActor in
            self.isRecognizing = true
            self.message = "正在开启摄像头"
        }

        requestAccessIfNeeded { [weak self] granted in
            guard let self else { return }

            guard granted else {
                Task { @MainActor in
                    self.isRecognizing = false
                    self.message = "相机权限未开启"
                }
                return
            }

            self.sessionQueue.async {
                self.configureSessionIfNeeded()

                guard self.isConfigured else {
                    Task { @MainActor in
                        self.isRecognizing = false
                    }
                    return
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                Task { @MainActor in
                    self.isRecognizing = true
                    self.message = automaticDetection ? "正在自动识别门头" : "请调整画面后拍照识别"
                }
            }
        }
    }

    func stop() {
        resetStability()
        state = .idle
        latestPixelBuffer = nil
        isAutomaticDetectionEnabled = false
        automaticallySavedPhoneNumberKeys.removeAll()

        Task { @MainActor in
            self.isRecognizing = false
            self.message = nil
        }

        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureCurrentFrame() {
        guard isRecognizing else {
            message = "请先开始摄像头"
            return
        }

        guard state == .idle else {
            message = "正在处理上一张"
            return
        }

        state = .detecting
        message = "正在拍照识别"

        visionQueue.async { [weak self] in
            guard let self else { return }

            guard !self.isVisionBusy else {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "正在识别中，请稍后再拍"
                }
                return
            }

            guard let pixelBuffer = self.latestPixelBuffer else {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "请稍等相机画面稳定"
                }
                return
            }

            self.isVisionBusy = true
            self.performTextRecognition(
                pixelBuffer: pixelBuffer,
                orientation: self.latestImageOrientation,
                recognitionLevel: .accurate,
                mode: .manual
            )
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.cameraDevice else {
                return
            }

            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, Constants.maximumZoomFactor)
            let clampedFactor = min(max(factor, 1), maxZoom)

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()

                Task { @MainActor in
                    self.zoomFactor = clampedFactor
                }
            } catch {
                print("Warning: failed to update zoom: \(error.localizedDescription)")
            }
        }
    }

    func setCaptureViewport(guideLayerRect: CGRect, previewSize: CGSize) {
        guard guideLayerRect.width > 0,
              guideLayerRect.height > 0,
              previewSize.width > 0,
              previewSize.height > 0 else {
            return
        }

        captureGuideLayerRect = guideLayerRect
        capturePreviewSize = previewSize
    }

    func updateOrientation(_ deviceOrientation: UIDeviceOrientation) {
        guard let videoRotationAngle = videoRotationAngle(for: deviceOrientation) else {
            return
        }

        currentImageOrientation = .up
        currentVideoRotationAngle = videoRotationAngle

        sessionQueue.async { [weak self] in
            guard let connection = self?.videoOutput?.connection(with: .video),
                  connection.isVideoRotationAngleSupported(videoRotationAngle) else {
                return
            }

            connection.videoRotationAngle = videoRotationAngle
        }
    }

    func markSaveCompleted() {
        state = .cooldown
        resetStability()

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
        resetStability()
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

        cameraDevice = device

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
        videoOutput = output

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(currentVideoRotationAngle) {
                connection.videoRotationAngle = currentVideoRotationAngle
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }

        isConfigured = true
    }

    private func process(sampleBuffer: CMSampleBuffer) {
        frameIndex += 1

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        latestPixelBuffer = pixelBuffer
        latestImageOrientation = currentImageOrientation

        guard isAutomaticDetectionEnabled else {
            return
        }

        guard frameIndex % Constants.frameProcessingInterval == 0 else {
            return
        }

        guard !isVisionBusy, state == .idle else {
            return
        }

        isVisionBusy = true

        autoreleasepool {
            performTextRecognition(
                pixelBuffer: pixelBuffer,
                orientation: .up,
                recognitionLevel: .accurate,
                mode: .automatic
            )
        }
    }

    private func performTextRecognition(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        recognitionLevel: VNRequestTextRecognitionLevel,
        mode: RecognitionMode
    ) {
        guard let croppedImage = makeCroppedUIImage(
            from: pixelBuffer,
            orientation: orientation,
            guideLayerRect: captureGuideLayerRect,
            previewSize: capturePreviewSize
        ),
              let cgImage = croppedImage.cgImage else {
            isVisionBusy = false
            if mode == .manual {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "取景裁剪失败"
                }
            }
            return
        }

        guard cgImage.width >= 80, cgImage.height >= 80 else {
            isVisionBusy = false
            if mode == .manual {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "取景区域太小"
                }
            }
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }
            defer { self.isVisionBusy = false }

            if let error {
                print("Warning: Vision OCR failed: \(error.localizedDescription)")
                if mode == .manual {
                    Task { @MainActor in
                        self.state = .idle
                        self.message = "拍照识别失败"
                    }
                }
                return
            }

            self.handleVisionResults(request.results, image: croppedImage, mode: mode)
        }

        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            isVisionBusy = false
            if mode == .manual {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "拍照识别失败"
                }
            }
            print("Warning: Vision request failed: \(error.localizedDescription)")
        }
    }

    private func handleVisionResults(_ results: [VNObservation]?, image: UIImage, mode: RecognitionMode) {
        guard let observations = results as? [VNRecognizedTextObservation] else {
            resetStability()
            if mode == .manual {
                Task { @MainActor in
                    state = .idle
                    message = "未识别到文字"
                }
            }
            return
        }

        let textLines = OCRTextContextBuilder.lines(from: observations, image: image)
        let fullText = textLines.map(\.text).joined(separator: "\n")

        let phoneNumbers = PhoneNumberExtractor.allPhoneNumbers(in: fullText)
        guard !phoneNumbers.isEmpty else {
            resetStability()
            if mode == .manual {
                Task { @MainActor in
                    state = .idle
                    message = "未识别到电话号码"
                }
            }
            return
        }
        let phoneNumber = phoneNumbers.joined(separator: "、")
        let phoneNumberKey = canonicalPhoneNumberKey(from: phoneNumbers)

        if mode == .automatic {
            guard !automaticallySavedPhoneNumberKeys.contains(phoneNumberKey) else {
                resetStability()
                Task { @MainActor in
                    state = .idle
                    message = "已识别过，继续扫描新店铺"
                }
                return
            }

            if stablePhoneNumber == phoneNumber {
                stableCount += 1
            } else {
                stablePhoneNumber = phoneNumber
                stableCount = 1
                pendingAutomaticPhoneNumberKey = nil
                pendingAutomaticCaptureDeadline = nil
            }

            guard stableCount >= Constants.requiredStableDetections else {
                Task { @MainActor in
                    message = "识别中 \(stableCount)/\(Constants.requiredStableDetections)"
                }
                return
            }

            let now = Date()
            if pendingAutomaticPhoneNumberKey != phoneNumberKey {
                pendingAutomaticPhoneNumberKey = phoneNumberKey
                pendingAutomaticCaptureDeadline = now.addingTimeInterval(Constants.automaticCaptureDelay)
                Task { @MainActor in
                    message = "已识别到电话，请保持画面 3 秒"
                }
                return
            }

            if let deadline = pendingAutomaticCaptureDeadline, now < deadline {
                let remaining = max(1, Int(ceil(deadline.timeIntervalSince(now))))
                Task { @MainActor in
                    message = "请保持画面 \(remaining) 秒"
                }
                return
            }
        }

        let now = Date()
        guard mode == .manual || now.timeIntervalSince(lastCaptureTime) > 2 else {
            resetStability()
            return
        }

        lastCaptureTime = now
        state = .detecting
        if mode == .automatic {
            automaticallySavedPhoneNumberKeys.insert(phoneNumberKey)
        }

        let prioritizedText = OCRTextContextBuilder.prioritizedText(from: textLines, phoneNumber: phoneNumber)
        let detectedFrame = DetectedShopFrame(image: image, fullText: prioritizedText, phoneNumber: phoneNumber)

        Task { @MainActor in
            message = mode == .manual ? "拍照识别成功，正在保存" : "正在保存"
            delegate?.cameraFrameProcessor(self, didDetect: detectedFrame)
        }
    }

    private func resetStability() {
        stablePhoneNumber = nil
        stableCount = 0
        pendingAutomaticPhoneNumberKey = nil
        pendingAutomaticCaptureDeadline = nil
    }

    private func canonicalPhoneNumberKey(from phoneNumbers: [String]) -> String {
        phoneNumbers
            .map { $0.filter(\.isNumber) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "|")
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private func makeCroppedUIImage(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        guideLayerRect: CGRect,
        previewSize: CGSize
    ) -> UIImage? {
        guard let image = makeUIImage(from: pixelBuffer, orientation: orientation) else {
            return nil
        }

        return cropRenderedPreviewImage(sourceImage: image, previewSize: previewSize, guideLayerRect: guideLayerRect)
    }

    private func cropRenderedPreviewImage(sourceImage: UIImage, previewSize: CGSize, guideLayerRect: CGRect) -> UIImage? {
        guard sourceImage.size.width > 0,
              sourceImage.size.height > 0,
              previewSize.width > 0,
              previewSize.height > 0,
              guideLayerRect.width > 0,
              guideLayerRect.height > 0 else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let previewImage = UIGraphicsImageRenderer(size: previewSize, format: format).image { _ in
            sourceImage.draw(in: aspectFillRect(imageSize: sourceImage.size, previewSize: previewSize))
        }

        guard let previewCGImage = previewImage.cgImage else {
            return nil
        }

        let cropScale = previewImage.scale
        let cropRect = CGRect(
            x: guideLayerRect.minX * cropScale,
            y: guideLayerRect.minY * cropScale,
            width: guideLayerRect.width * cropScale,
            height: guideLayerRect.height * cropScale
        ).integral
        let boundedRect = cropRect.intersection(
            CGRect(x: 0, y: 0, width: CGFloat(previewCGImage.width), height: CGFloat(previewCGImage.height))
        ).integral

        guard !boundedRect.isNull,
              boundedRect.width > 0,
              boundedRect.height > 0,
              let croppedCGImage = previewCGImage.cropping(to: boundedRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: cropScale, orientation: .up)
    }

    private func aspectFillRect(imageSize: CGSize, previewSize: CGSize) -> CGRect {
        let scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let displayedOrigin = CGPoint(
            x: (previewSize.width - displayedSize.width) / 2,
            y: (previewSize.height - displayedSize.height) / 2
        )
        return CGRect(origin: displayedOrigin, size: displayedSize)
    }
}

extension CameraFrameProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        process(sampleBuffer: sampleBuffer)
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
