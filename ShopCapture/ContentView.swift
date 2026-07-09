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
            Color(red: 0.94, green: 0.96, blue: 0.93)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(Color(red: 0.05, green: 0.42, blue: 0.33))
                Text("正在检查登录状态")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.06, green: 0.12, blue: 0.11))
            }
            .padding(24)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct AppLoginView: View {
    private enum Mode {
        case login
        case register
    }

    @EnvironmentObject private var authSession: AuthSession
    @State private var mode: Mode = .login
    @State private var username = "demo"
    @State private var password = "123456"
    @State private var message: String?
    @State private var isWorking = false
    private let siteID = 999

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 0.91),
                    Color(red: 0.99, green: 0.96, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .login ? "登录" : "注册")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.10))
                }

                VStack(spacing: 14) {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .loginFieldStyle()

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .loginFieldStyle()
                }

                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    Text(isWorking ? "处理中..." : (mode == .login ? "登录进入" : "注册进入"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(red: 0.05, green: 0.42, blue: 0.33))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isWorking || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                Button {
                    switchMode()
                } label: {
                    Text(mode == .login ? "还没有账号？立即注册" : "已有账号？返回登录")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.42, blue: 0.33))
                        .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)

                if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(22)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 28, y: 12)
            .padding(.horizontal, 22)
        }
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
        message = nil
        if mode == .login {
            username = "demo"
            password = "123456"
        } else {
            username = ""
            password = ""
        }
    }
}

private extension View {
    func loginFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(red: 0.96, green: 0.97, blue: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}
