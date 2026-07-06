# ShopCapture

SwiftUI + AVFoundation + Vision + CoreLocation + Core Data 的本地实时门头信息采集示例应用。

## 权限配置

`ShopCapture/Info.plist` 已添加以下权限键：

- `NSCameraUsageDescription`
- `NSLocationWhenInUseUsageDescription`

## 功能

- 启动后自动打开后置摄像头，全屏实时预览。
- 每 3 帧分析 1 帧，使用 `VNRecognizeTextRequest` 的 `.fast` 模式识别中央 60% 区域。
- 中国手机号或固定电话连续 5 次稳定出现后自动截取当前帧。
- 抓拍时等待最多 3 秒获取定位；超时则保存 `0.0, 0.0` 并打印 warning。
- JPEG 以 0.8 质量保存到 `Documents/ShopImages/`，Core Data 只保存图片路径和元数据。
- 历史列表展示缩略图、号码、前 20 个字符和经纬度；详情页展示大图、完整文字和 MapKit 标注。

## 运行提醒

真实相机、定位和 Vision 性能需要在实体 iPhone 上验证。当前环境只有 Command Line Tools，缺完整 Xcode，因此无法在这里执行 `xcodebuild` 构建。

## GitHub Actions 打包

仓库已添加 `.github/workflows/ios-build.yml`：

- 推送到 `main`/`master` 或手动运行 workflow 时，会在 macOS runner 上构建未签名的真机 IPA。
- 构建成功后，在 GitHub Actions run 的 Artifacts 中下载 `ShopCapture-unsigned-ipa`。
- 这个 IPA 通常不能直接安装到真机，需要后续重签名。

本项目当前 Bundle Identifier 是 `com.bully1990.shopcapture`。
