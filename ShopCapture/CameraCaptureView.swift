import SwiftUI
import UIKit

struct CameraCaptureView: View {
    private enum RecognitionMode: String, CaseIterable, Identifiable {
        case manual = "拍照识别"
        case automatic = "自动识别"

        var id: String { rawValue }

        var startTitle: String {
            switch self {
            case .manual:
                return "拍照"
            case .automatic:
                return "开始自动识别"
            }
        }

        var hint: String {
            switch self {
            case .manual:
                return "默认拍照识别：调整画面后手动拍照保存"
            case .automatic:
                return "自动识别：扫到电话号码后自动保存"
            }
        }
    }

    @StateObject private var processor = CameraFrameProcessor()
    @EnvironmentObject private var locationProvider: LocationProvider
    @State private var isShowingHistory = false
    @State private var isShowingPhotoPicker = false
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    @State private var previewOffset: CGSize = .zero
    @State private var committedPreviewOffset: CGSize = .zero
    @State private var previewSize: CGSize = .zero
    @State private var guideLayerRect: CGRect = .zero
    @State private var gestureStartZoom: CGFloat?
    @State private var recognitionMode: RecognitionMode = .manual

    var body: some View {
        ZStack {
            CameraPreviewView(
                session: processor.session,
                deviceOrientation: deviceOrientation,
                guideLayerRect: guideLayerRect
            ) { guideLayerRect, previewSize in
                processor.setCaptureViewport(guideLayerRect: guideLayerRect, previewSize: previewSize)
            }
                .offset(previewOffset)
                .contentShape(Rectangle())
                .gesture(previewDragGesture)
                .simultaneousGesture(previewZoomGesture)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let guide = CaptureGuide.region
                let width = proxy.size.width * guide.width
                let height = proxy.size.height * guide.height

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(processor.isRecognizing ? .white.opacity(0.82) : .white.opacity(0.35), lineWidth: 2)
                    .frame(width: width, height: height)
                    .position(x: proxy.size.width * guide.midX, y: proxy.size.height * guide.midY)
                    .shadow(color: .black.opacity(0.32), radius: 8)
                    .onAppear {
                        updatePreviewSize(proxy.size)
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        updatePreviewSize(newSize)
                    }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if !processor.isRecognizing {
                VStack(spacing: 12) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("选择模式后开启摄像头")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("也可以从相册选择门头图片识别")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))

                    Text(recognitionMode.hint)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(.black.opacity(0.48))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 26)
            }

            VStack {
                topToolbar
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                Spacer()

                if !isLandscapeLayout {
                    controlPanel
                        .padding(.horizontal, controlHorizontalPadding)
                        .padding(.bottom, controlBottomPadding)
                }
            }

            if isLandscapeLayout {
                GeometryReader { proxy in
                    let guide = CaptureGuide.region
                    let footerWidth = min(proxy.size.width * guide.width, 520)
                    let footerY = min(proxy.size.height - 58, proxy.size.height * guide.maxY + 64)
                    let sideX = min(proxy.size.width - 68, proxy.size.width * guide.maxX + 66)

                    landscapeFooterControls
                        .frame(width: footerWidth)
                        .position(x: proxy.size.width * guide.midX, y: footerY)

                    landscapeSideActionButtons
                        .frame(width: 86)
                        .position(x: sideX, y: proxy.size.height * guide.midY)
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            NavigationStack {
                HistoryView()
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoLibraryPicker { image in
                Task {
                    await importPhoto(image)
                }
            }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateDeviceOrientation(UIDevice.current.orientation)
            processor.delegate = CaptureCoordinator.shared
            CaptureCoordinator.shared.configure(processor: processor, locationProvider: locationProvider)
            locationProvider.requestWhenInUseAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateDeviceOrientation(UIDevice.current.orientation)
        }
        .onDisappear {
            processor.stop()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    private var topToolbar: some View {
        ZStack {
            HStack {
                Button {
                    isShowingPhotoPicker = true
                } label: {
                    toolbarIcon("photo.on.rectangle")
                }
                .accessibilityLabel("从相册选择")

                Spacer()
            }

            Button {
                isShowingHistory = true
            } label: {
                toolbarIcon("clock.arrow.circlepath")
            }
            .accessibilityLabel("历史记录")
        }
    }

    private var controlPanel: some View {
        VStack(spacing: controlSpacing) {
            if let message = processor.message {
                Text(message)
                    .font(messageFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, isLandscapeLayout ? 12 : 14)
                    .padding(.vertical, isLandscapeLayout ? 6 : 9)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
            }

            Picker("识别模式", selection: $recognitionMode) {
                ForEach(RecognitionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(processor.isRecognizing)
            .controlSize(isLandscapeLayout ? .small : .regular)
            .padding(isLandscapeLayout ? 3 : 4)
            .background(.black.opacity(0.36))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if processor.isRecognizing {
                if recognitionMode == .manual {
                    manualActionButtons
                } else {
                    Button {
                        toggleRecognition()
                    } label: {
                        Label("停止自动识别", systemImage: "stop.fill")
                            .font(actionButtonFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, actionButtonVerticalPadding)
                            .background(.red.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous))
                    }
                    .accessibilityLabel("停止自动识别")
                }
            } else {
                Button {
                    toggleRecognition()
                } label: {
                    Label(recognitionMode.startTitle, systemImage: recognitionMode == .manual ? "camera.fill" : "camera.viewfinder")
                        .font(actionButtonFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, actionButtonVerticalPadding)
                        .background(.green.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
                }
                .accessibilityLabel(recognitionMode.startTitle)
            }

            if processor.isRecognizing {
                zoomResetStrip
            }
        }
    }

    private var landscapeFooterControls: some View {
        VStack(spacing: 8) {
            if let message = processor.message {
                Text(message)
                    .font(messageFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
            }

            Picker("识别模式", selection: $recognitionMode) {
                ForEach(RecognitionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(processor.isRecognizing)
            .controlSize(.small)
            .padding(3)
            .background(.black.opacity(0.36))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if processor.isRecognizing {
                zoomResetStrip
            } else {
                Button {
                    toggleRecognition()
                } label: {
                    Label(recognitionMode.startTitle, systemImage: recognitionMode == .manual ? "camera.fill" : "camera.viewfinder")
                        .font(actionButtonFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, actionButtonVerticalPadding)
                        .background(.green.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
                }
                .accessibilityLabel(recognitionMode.startTitle)
            }
        }
    }

    private var landscapeSideActionButtons: some View {
        VStack(spacing: 8) {
            if processor.isRecognizing {
                Button {
                    toggleRecognition()
                } label: {
                    Text("停止")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("停止识别")

                if recognitionMode == .manual {
                    Button {
                        processor.captureCurrentFrame()
                    } label: {
                        Text("拍照")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(.white.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("拍照")
                }
            }
        }
    }

    private var manualActionButtons: some View {
        let stack = isLandscapeLayout ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))

        return stack {
            Button {
                toggleRecognition()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .font(actionButtonFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, actionButtonVerticalPadding)
                    .background(.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous))
            }
            .accessibilityLabel("停止识别")

            Button {
                processor.captureCurrentFrame()
            } label: {
                Label("拍照", systemImage: "camera.fill")
                    .font(actionButtonFont)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, actionButtonVerticalPadding)
                    .background(.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous))
            }
            .accessibilityLabel("拍照")
        }
    }

    private var zoomResetStrip: some View {
        HStack(spacing: 10) {
            Label(String(format: "缩放 %.1fx", processor.zoomFactor), systemImage: "plus.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))

            Spacer()

            Button {
                resetPreviewTransform()
            } label: {
                Label("重置取景", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, isLandscapeLayout ? 10 : 12)
        .padding(.vertical, isLandscapeLayout ? 6 : 9)
        .background(.black.opacity(0.42))
        .clipShape(Capsule())
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.45))
            .clipShape(Circle())
    }

    private func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        guard orientation.isUsableCameraOrientation else {
            return
        }

        deviceOrientation = orientation
        processor.updateOrientation(orientation)
    }

    private func toggleRecognition() {
        if processor.isRecognizing {
            processor.stop()
        } else {
            processor.start(automaticDetection: recognitionMode == .automatic)
        }
    }

    private var isLandscapeLayout: Bool {
        deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight
    }

    private var controlSpacing: CGFloat {
        isLandscapeLayout ? 8 : 12
    }

    private var controlHorizontalPadding: CGFloat {
        isLandscapeLayout ? 78 : 22
    }

    private var controlBottomPadding: CGFloat {
        isLandscapeLayout ? 0 : 28
    }

    private var actionButtonFont: Font {
        isLandscapeLayout ? .subheadline.weight(.semibold) : .headline.weight(.semibold)
    }

    private var messageFont: Font {
        isLandscapeLayout ? .caption.weight(.semibold) : .callout.weight(.semibold)
    }

    private var actionButtonVerticalPadding: CGFloat {
        isLandscapeLayout ? 8 : 15
    }

    private var actionButtonCornerRadius: CGFloat {
        isLandscapeLayout ? 13 : 16
    }

    private var previewDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let nextOffset = clampedOffset(
                    CGSize(
                        width: committedPreviewOffset.width + value.translation.width,
                        height: committedPreviewOffset.height + value.translation.height
                    )
                )
                previewOffset = nextOffset
                updateProcessorGuideLayerRect(for: nextOffset)
            }
            .onEnded { _ in
                committedPreviewOffset = previewOffset
                updateProcessorGuideLayerRect(for: previewOffset)
            }
    }

    private var previewZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureStartZoom == nil {
                    gestureStartZoom = processor.zoomFactor
                }

                processor.setZoomFactor((gestureStartZoom ?? 1) * value)
            }
            .onEnded { _ in
                gestureStartZoom = nil
            }
    }

    private func resetPreviewTransform() {
        previewOffset = .zero
        committedPreviewOffset = .zero
        updateProcessorGuideLayerRect(for: .zero)
        processor.setZoomFactor(1)
    }

    private func clampedOffset(_ offset: CGSize) -> CGSize {
        CGSize(
            width: min(max(offset.width, -140), 140),
            height: min(max(offset.height, -180), 180)
        )
    }

    private func updatePreviewSize(_ size: CGSize) {
        previewSize = size
        updateProcessorGuideLayerRect(for: previewOffset)
    }

    private func updateProcessorGuideLayerRect(for offset: CGSize) {
        guard previewSize.width > 0, previewSize.height > 0 else {
            guideLayerRect = .zero
            return
        }

        let guide = CaptureGuide.region
        guideLayerRect = CGRect(
            x: previewSize.width * guide.minX - offset.width,
            y: previewSize.height * guide.minY - offset.height,
            width: previewSize.width * guide.width,
            height: previewSize.height * guide.height
        )
    }

    private func importPhoto(_ image: UIImage) async {
        do {
            processor.setMessage("正在识别相册图片")

            guard let frame = try await ImageTextRecognizer.detectShopFrame(in: image) else {
                processor.setMessage("未识别到电话号码")
                return
            }

            processor.setMessage("正在保存")
            CaptureCoordinator.shared.save(frame: frame, processor: processor)
        } catch {
            print("Warning: failed to import photo: \(error.localizedDescription)")
            processor.setMessage("相册识别失败")
        }
    }
}

private extension UIDeviceOrientation {
    var isUsableCameraOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class CaptureCoordinator: CameraFrameProcessorDelegate {
    static let shared = CaptureCoordinator()

    private weak var processor: CameraFrameProcessor?
    private weak var locationProvider: LocationProvider?
    private var isSaving = false

    func configure(processor: CameraFrameProcessor, locationProvider: LocationProvider) {
        self.processor = processor
        self.locationProvider = locationProvider
    }

    func cameraFrameProcessor(_ processor: CameraFrameProcessor, didDetect frame: DetectedShopFrame) {
        save(frame: frame, processor: processor)
    }

    func save(frame: DetectedShopFrame, processor: CameraFrameProcessor) {
        guard !isSaving else {
            return
        }

        isSaving = true

        Task {
            let location = await locationProvider?.currentLocation(timeout: 3)
            let summary = await summarize(frame: frame, processor: processor)
            processor.setMessage("正在保存")
            let payload = CapturedShopPayload(
                image: frame.image,
                fullText: frame.fullText,
                phoneNumber: frame.phoneNumber,
                shopName: summary?.shopName,
                serviceContent: summary?.serviceContent,
                latitude: location?.coordinate.latitude ?? 0.0,
                longitude: location?.coordinate.longitude ?? 0.0,
                timestamp: Date()
            )

            do {
                try await ShopRecordStore.save(payload)
                isSaving = false
                processor.markSaveCompleted()
            } catch {
                isSaving = false
                processor.markSaveFailed(error)
            }
        }
    }

    private func summarize(frame: DetectedShopFrame, processor: CameraFrameProcessor) async -> ShopTextSummary? {
        processor.setMessage("正在整理名称和服务")

        do {
            if let summary = try await DeepSeekClient.summarize(fullText: frame.fullText, phoneNumber: frame.phoneNumber) {
                return summary
            }
        } catch {
            print("Warning: DeepSeek summary failed: \(error.localizedDescription)")
        }

        return ShopTextSummarizer.summarizeLocally(fullText: frame.fullText, phoneNumber: frame.phoneNumber)
    }

    func cameraFrameProcessor(_ processor: CameraFrameProcessor, didChangeMessage message: String?) {
    }
}
