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

- 推送到 `main`/`master` 或提交 Pull Request 时，会在 macOS runner 上执行未签名的 iOS Simulator Release 构建，并上传 `ShopCapture-simulator-app.zip` artifact。
- 推送到 `main`/`master` 时，还会构建未签名的真机 IPA，并上传 `ShopCapture-unsigned-ipa` artifact。这个 IPA 通常不能直接安装到真机，需要后续重签名。
- 在 GitHub Actions 页面手动运行 `Build iOS App`，并勾选 `build_signed_ipa` 时，还会尝试执行真机归档并导出 `ShopCapture-ipa` artifact。

导出 IPA 前，需要先在仓库的 `Settings -> Secrets and variables -> Actions` 中配置这些 secrets：

- `BUILD_CERTIFICATE_BASE64`：`.p12` 证书文件的 Base64 内容
- `P12_PASSWORD`：导出 `.p12` 时设置的密码
- `BUILD_PROVISION_PROFILE_BASE64`：`.mobileprovision` 描述文件的 Base64 内容
- `KEYCHAIN_PASSWORD`：CI 临时 keychain 密码
- `DEVELOPMENT_TEAM`：Apple Developer Team ID

本项目当前 Bundle Identifier 是 `com.bully1990.shopcapture`。如果要导出可安装到设备或提交商店的 IPA，需要在 Apple Developer 后台使用同一个 Bundle Identifier 创建 App ID、证书和描述文件。
