import SwiftUI

struct ContentView: View {
    @StateObject private var authSession = AuthSession()

    var body: some View {
        Group {
            if authSession.isCheckingSession {
                LaunchCheckingView()
            } else if authSession.isAuthenticated {
                AppHomeView()
            } else {
                AppLoginView()
            }
        }
        .environmentObject(authSession)
        .task {
            await authSession.restoreSession()
        }
    }
}

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var account: UserAccountSummary?
    @Published private(set) var isCheckingSession = true

    var isAuthenticated: Bool {
        account != nil
    }

    func restoreSession() async {
        guard isCheckingSession else {
            return
        }

        await refreshAccount()
        isCheckingSession = false
    }

    func refreshAccount() async {
        do {
            account = try await UserAPIClient.accountInfo()
        } catch {
            do {
                let profile = try await UserAPIClient.currentUserInfo()
                account = UserAccountSummary.fallback(profile: profile)
            } catch {
                account = nil
            }
        }
    }

    func login(username: String, password: String, siteID: Int) async throws {
        let profile = try await UserAPIClient.login(username: username, password: password, siteID: siteID)
        account = UserAccountSummary.fallback(profile: profile)
        await refreshAccount()
    }

    func register(username: String, password: String, siteID: Int = 999) async throws {
        let profile = try await UserAPIClient.register(username: username, password: password, siteID: siteID)
        account = UserAccountSummary.fallback(profile: profile)
        await refreshAccount()
    }

    func setAccount(_ account: UserAccountSummary) {
        self.account = account
    }

    func logout() async {
        do {
            try await UserAPIClient.logout()
        } catch {
            // Clear local state even if the remote session has already expired.
        }

        account = nil
        isCheckingSession = false
    }
}

private struct LaunchCheckingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color(uiColor: .systemBlue))
                Text("正在检查登录状态")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
    }
}

private struct AppLoginView: View {
    private enum Mode: Hashable {
        case login
        case register
    }

    private enum LoginField: Hashable {
        case username
        case password
    }

    @EnvironmentObject private var authSession: AuthSession
    @State private var mode: Mode = .login
    @State private var username = "demo"
    @State private var password = "123456"
    @State private var message: String?
    @State private var isWorking = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: LoginField?
    private let siteID = 999

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    brandHeader

                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .login ? "欢迎回来" : "创建账号")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color(uiColor: .label))

                        Text(mode == .login ? "登录后同步采集记录与审核进度" : "注册后开始采集真实店铺信息")
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }

                    Picker("账号操作", selection: $mode) {
                        Text("登录").tag(Mode.login)
                        Text("注册").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        resetFormForModeChange()
                    }

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .loginFieldIconStyle()

                            TextField("请输入账号", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .username)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        .loginFieldRowStyle()

                        Divider()
                            .padding(.leading, 52)

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .loginFieldIconStyle()

                            passwordField

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isPasswordVisible ? "隐藏密码" : "显示密码")
                        }
                        .loginFieldRowStyle()
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.45), lineWidth: 0.5)
                    )

                    if let message {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .systemRed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        focusedField = nil
                        Task {
                            await submit()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isWorking {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isWorking ? "处理中" : (mode == .login ? "登录" : "注册"))
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSubmit ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canSubmit)

                    Button {
                        switchMode()
                    } label: {
                        Text(mode == .login ? "还没有账号？创建账号" : "已有账号？返回登录")
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .systemBlue))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color(uiColor: .systemBlue))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("扫街采集")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))

                Text("专业采集端")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        Group {
            if isPasswordVisible {
                TextField("请输入密码", text: $password)
            } else {
                SecureField("请输入密码", text: $password)
            }
        }
        .textContentType(mode == .login ? .password : .newPassword)
        .submitLabel(.go)
        .focused($focusedField, equals: .password)
        .onSubmit {
            guard canSubmit else { return }
            Task {
                await submit()
            }
        }
    }

    private var canSubmit: Bool {
        !isWorking
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            if mode == .login {
                try await authSession.login(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    siteID: siteID
                )
            } else {
                try await authSession.register(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    siteID: siteID
                )
            }
            password = ""
            message = nil
        } catch {
            message = mode == .login ? "登录失败，请检查账号密码" : "注册失败，请更换账号后重试"
        }
    }

    private func switchMode() {
        mode = mode == .login ? .register : .login
    }

    private func resetFormForModeChange() {
        message = nil
        username = mode == .login ? "demo" : ""
        password = mode == .login ? "123456" : ""
        isPasswordVisible = false
        focusedField = nil
    }
}

private extension View {
    func loginFieldRowStyle() -> some View {
        self
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
    }

    func loginFieldIconStyle() -> some View {
        self
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .frame(width: 24)
    }
}
