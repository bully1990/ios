import Foundation

struct UserProfileSummary: Sendable {
    let displayName: String
    let accountLine: String
    let roleName: String
    let locationName: String
    let syncStatus: String
}

struct UserAccountSummary: Sendable {
    let profile: UserProfileSummary
    let coins: Int
    let totalIncome: Double
    let currentMonthIncome: Double
    let lastMonthIncome: Double
    let alipayAccount: String
    let alipayName: String

    static func fallback(profile: UserProfileSummary) -> UserAccountSummary {
        UserAccountSummary(
            profile: profile,
            coins: 0,
            totalIncome: 0,
            currentMonthIncome: 0,
            lastMonthIncome: 0,
            alipayAccount: "",
            alipayName: ""
        )
    }
}

enum UserAPIClient {
    private static let baseURL = URL(string: "https://api.gmpebr.com/index.php")!
    private static let authTokenStore = ShopCaptureAuthTokenStore()

    static func login(username: String, password: String, siteID: Int = 1) async throws -> UserProfileSummary {
        var request = URLRequest(url: endpoint(action: "ajax_login"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formBody([
            "username": username,
            "password": password,
            "siteid": "\(siteID)"
        ])

        return try await send(request)
    }

    static func register(username: String, password: String, siteID: Int = 999) async throws -> UserProfileSummary {
        var request = URLRequest(url: endpoint(action: "ajax_register"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formBody([
            "username": username,
            "password": password,
            "siteid": "\(siteID)"
        ])

        return try await send(request)
    }

    static func logout() async throws {
        var request = URLRequest(url: endpoint(action: "ajax_logout"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = true
        applyAuthentication(to: &request)
        defer { authTokenStore.value = "" }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func currentUserInfo() async throws -> UserProfileSummary {
        var request = URLRequest(url: endpoint(action: "ajax_user_info"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request)
        return try await send(request)
    }

    static func accountInfo() async throws -> UserAccountSummary {
        var request = URLRequest(url: endpoint(action: "ajax_account_info"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request)

        let data = try await sendData(request)
        return UserAccountSummary(data: data)
    }

    static func saveAlipay(account: String, name: String) async throws -> UserAccountSummary {
        var request = URLRequest(url: endpoint(action: "ajax_save_alipay"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request)
        request.httpBody = formBody([
            "alipay_account": account,
            "alipay_name": name
        ])

        let data = try await sendData(request)
        return UserAccountSummary(data: data)
    }

    static func submitWithdraw(coins: Int, alipayAccount: String, alipayName: String) async throws {
        var request = URLRequest(url: endpoint(action: "ajax_withdraw_request"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request)
        request.httpBody = formBody([
            "coins": "\(coins)",
            "alipay_account": alipayAccount,
            "alipay_name": alipayName
        ])

        _ = try await sendData(request)
    }

    private static func endpoint(action: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "m", value: "user"),
            URLQueryItem(name: "c", value: "user"),
            URLQueryItem(name: "a", value: action)
        ]
        return components.url!
    }

    static func applyAuthentication(to request: inout URLRequest) {
        let token = authTokenStore.value
        guard !token.isEmpty else { return }
        request.setValue(token, forHTTPHeaderField: "Token")
    }

    private static func send(_ request: URLRequest) async throws -> UserProfileSummary {
        let data = try await sendData(request)
        return UserProfileSummary(data: data)
    }

    private static func sendData(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let envelope = object as? [String: Any],
              responseCode(from: envelope["code"]) == 200 else {
            throw URLError(.cannotParseResponse)
        }

        let payload = envelope["data"] as? [String: Any] ?? [:]
        if let token = payload["token"] as? String, !token.isEmpty {
            authTokenStore.value = token
        } else if let token = payload["token"] as? NSNumber {
            authTokenStore.value = token.stringValue
        }
        return payload
    }

    private static func responseCode(from value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue) ?? 0
        }
        return 0
    }

    private static func formBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private final class ShopCaptureAuthTokenStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = ""

    var value: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

private extension UserProfileSummary {
    init(data: [String: Any]) {
        let username = Self.stringValue(data["username"])
        let realName = Self.firstNonEmpty([
            Self.stringValue(data["realname"]),
            Self.stringValue(data["nickname"]),
            Self.stringValue(data["姓名"]),
            username
        ])
        let mobile = Self.firstNonEmpty([
            Self.stringValue(data["mobile"]),
            Self.stringValue(data["phone"]),
            Self.stringValue(data["手机号"])
        ])
        let role = Self.firstNonEmpty([
            Self.stringValue(data["rolename"]),
            Self.stringValue(data["role_name"]),
            "认证用户"
        ])
        let site = Self.firstNonEmpty([
            Self.stringValue(data["sitename"]),
            Self.stringValue(data["site_name"]),
            Self.stringValue(data["组织名称"]),
            "已登录"
        ])

        self.displayName = realName.isEmpty ? "已登录用户" : realName
        self.accountLine = mobile.isEmpty ? "账号 \(username)" : "手机号 \(Self.maskedMobile(mobile))"
        self.roleName = role
        self.locationName = site
        self.syncStatus = "已同步 · \(Self.nowLabel())"
    }

    static func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return "\(double)"
        default:
            return ""
        }
    }

    static func firstNonEmpty(_ values: [String]) -> String {
        values.first { !$0.isEmpty } ?? ""
    }

    static func maskedMobile(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count >= 7 else {
            return value
        }
        return "\(digits.prefix(3))****\(digits.suffix(4))"
    }

    static func nowLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

private extension UserAccountSummary {
    init(data: [String: Any]) {
        let profileData = data["user"] as? [String: Any] ?? data
        let accountData = data["account"] as? [String: Any] ?? data
        let incomeData = accountData["income"] as? [String: Any]
            ?? data["income"] as? [String: Any]
            ?? accountData

        self.profile = UserProfileSummary(data: profileData)
        self.coins = Self.intValue(Self.firstValue(
            in: accountData,
            keys: ["coins", "coin", "gold", "金币", "balance", "points", "point"]
        ))
        self.totalIncome = Self.doubleValue(Self.firstValue(
            in: incomeData,
            keys: ["total_income", "history_income", "income_total", "total_earnings", "历史总收入"]
        ) ?? Self.firstValue(
            in: data,
            keys: ["total_income", "history_income", "income_total", "total_earnings", "历史总收入"]
        ))
        self.currentMonthIncome = Self.doubleValue(Self.firstValue(
            in: incomeData,
            keys: ["month_income", "current_month_income", "income_month", "本月收入"]
        ) ?? Self.firstValue(
            in: data,
            keys: ["month_income", "current_month_income", "income_month", "本月收入"]
        ))
        self.lastMonthIncome = Self.doubleValue(Self.firstValue(
            in: incomeData,
            keys: ["last_month_income", "previous_month_income", "income_last_month", "上月收入"]
        ) ?? Self.firstValue(
            in: data,
            keys: ["last_month_income", "previous_month_income", "income_last_month", "上月收入"]
        ))
        self.alipayAccount = UserProfileSummary.firstNonEmpty([
            UserProfileSummary.stringValue(Self.firstValue(in: accountData, keys: ["alipay_account", "alipay", "支付宝账号"])),
            UserProfileSummary.stringValue(Self.firstValue(in: accountData, keys: ["payment_account"]))
        ])
        self.alipayName = UserProfileSummary.firstNonEmpty([
            UserProfileSummary.stringValue(Self.firstValue(in: accountData, keys: ["alipay_name", "realname", "收款姓名"])),
            profile.displayName
        ])
    }

    static func firstValue(in data: [String: Any], keys: [String]) -> Any? {
        keys.lazy.compactMap { data[$0] }.first
    }

    static func intValue(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        default:
            return 0
        }
    }

    static func doubleValue(_ value: Any?) -> Double {
        switch value {
        case let int as Int:
            return Double(int)
        case let double as Double:
            return double
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        default:
            return 0
        }
    }
}
