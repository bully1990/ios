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
    private var lastCaptureTime = Date.distantPast
    private var currentImageOrientation: CGImagePropertyOrientation = .up
    private var currentVideoOrientation: AVCaptureVideoOrientation = .portrait
    private var cameraDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestImageOrientation: CGImagePropertyOrientation = .up
    private var isAutomaticDetectionEnabled = false
    private var captureMetadataRect = CGRect.zero
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

    func setCaptureViewport(metadataRect: CGRect, guideLayerRect: CGRect, previewSize: CGSize) {
        guard metadataRect.width > 0,
              metadataRect.height > 0,
              guideLayerRect.width > 0,
              guideLayerRect.height > 0,
              previewSize.width > 0,
              previewSize.height > 0 else {
            return
        }

        captureMetadataRect = clamped(metadataRect)
        captureGuideLayerRect = guideLayerRect
        capturePreviewSize = previewSize
    }

    func updateOrientation(_ deviceOrientation: UIDeviceOrientation) {
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) else {
            return
        }

        currentImageOrientation = .up
        currentVideoOrientation = videoOrientation

        sessionQueue.async { [weak self] in
            guard let connection = self?.videoOutput?.connection(with: .video),
                  connection.isVideoOrientationSupported else {
                return
            }

            connection.videoOrientation = videoOrientation
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
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation
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
            metadataRect: captureMetadataRect,
            guideLayerRect: captureGuideLayerRect,
            previewSize: capturePreviewSize
        ),
              let cgImage = croppedImage.cgImage else {
            isVisionBusy = false
            if mode == .manual {
                Task { @MainActor in
                    self.state = .idle
                    self.message = "拍照裁剪失败"
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
            }

            guard stableCount >= Constants.requiredStableDetections else {
                Task { @MainActor in
                    message = "识别中 \(stableCount)/\(Constants.requiredStableDetections)"
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
        metadataRect: CGRect,
        guideLayerRect: CGRect,
        previewSize: CGSize
    ) -> UIImage? {
        let rawImage = CIImage(cvPixelBuffer: pixelBuffer)

        if let metadataCropRect = metadataCropRect(imageExtent: rawImage.extent, metadataRect: metadataRect),
           let image = makeUIImage(from: rawImage.cropped(to: metadataCropRect), orientation: orientation) {
            return image
        }

        guard let image = makeUIImage(from: pixelBuffer, orientation: orientation),
              let cgImage = image.cgImage else {
            return nil
        }
        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let cropRect = visibleImageCropRect(
            imageSize: imageSize,
            previewSize: previewSize,
            guideLayerRect: guideLayerRect
        ) ?? fallbackCropRect(imageSize: imageSize)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
    }

    private func makeUIImage(from ciImage: CIImage, orientation: CGImagePropertyOrientation) -> UIImage? {
        let orientedImage = ciImage.oriented(orientation)
        guard let cgImage = ciContext.createCGImage(orientedImage, from: orientedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private func metadataCropRect(imageExtent: CGRect, metadataRect: CGRect) -> CGRect? {
        guard metadataRect.width > 0, metadataRect.height > 0, imageExtent.width > 0, imageExtent.height > 0 else {
            return nil
        }

        let normalizedRect = clamped(metadataRect)
        let cropRect = CGRect(
            x: imageExtent.minX + normalizedRect.minX * imageExtent.width,
            y: imageExtent.minY + (1 - normalizedRect.maxY) * imageExtent.height,
            width: normalizedRect.width * imageExtent.width,
            height: normalizedRect.height * imageExtent.height
        ).integral
        let boundedRect = cropRect.intersection(imageExtent).integral
        guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else {
            return nil
        }

        return boundedRect
    }

    private func visibleImageCropRect(imageSize: CGSize, previewSize: CGSize, guideLayerRect: CGRect) -> CGRect? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              previewSize.width > 0,
              previewSize.height > 0,
              guideLayerRect.width > 0,
              guideLayerRect.height > 0 else {
            return nil
        }

        let scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let displayedOrigin = CGPoint(
            x: (previewSize.width - displayedSize.width) / 2,
            y: (previewSize.height - displayedSize.height) / 2
        )
        let cropRect = CGRect(
            x: (guideLayerRect.minX - displayedOrigin.x) / scale,
            y: (guideLayerRect.minY - displayedOrigin.y) / scale,
            width: guideLayerRect.width / scale,
            height: guideLayerRect.height / scale
        )

        let boundedRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize)).integral
        guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else {
            return nil
        }

        return boundedRect
    }

    private func fallbackCropRect(imageSize: CGSize) -> CGRect {
        CGRect(
            x: CaptureGuide.region.minX * imageSize.width,
            y: CaptureGuide.region.minY * imageSize.height,
            width: CaptureGuide.region.width * imageSize.width,
            height: CaptureGuide.region.height * imageSize.height
        ).integral
    }

    private func clamped(_ region: CGRect) -> CGRect {
        let minX = min(max(region.minX, 0), 1)
        let minY = min(max(region.minY, 0), 1)
        let maxX = min(max(region.maxX, 0), 1)
        let maxY = min(max(region.maxY, 0), 1)
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }
}

extension CameraFrameProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        process(sampleBuffer: sampleBuffer)
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
