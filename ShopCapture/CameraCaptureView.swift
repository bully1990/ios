import SwiftUI
import UIKit

struct CameraCaptureView: View {
    @StateObject private var processor = CameraFrameProcessor()
    @EnvironmentObject private var locationProvider: LocationProvider
    @State private var isShowingHistory = false
    @State private var isShowingPhotoPicker = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: processor.session)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width * 0.6
                let height = proxy.size.height * 0.6

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.82), lineWidth: 2)
                    .frame(width: width, height: height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .shadow(color: .black.opacity(0.32), radius: 8)
            }
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("从相册选择")

                    Spacer()

                    Button {
                        isShowingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("历史记录")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()

                if let message = processor.message {
                    Text(message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(.bottom, 28)
                }
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
            processor.delegate = CaptureCoordinator.shared
            CaptureCoordinator.shared.configure(processor: processor, locationProvider: locationProvider)
            locationProvider.requestWhenInUseAuthorization()
            processor.start()
        }
        .onDisappear {
            processor.stop()
        }
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
            return try await DeepSeekClient.summarize(fullText: frame.fullText, phoneNumber: frame.phoneNumber)
        } catch {
            print("Warning: DeepSeek summary failed: \(error.localizedDescription)")
            processor.setMessage("整理失败，继续保存")
            return nil
        }
    }

    func cameraFrameProcessor(_ processor: CameraFrameProcessor, didChangeMessage message: String?) {
    }
}
