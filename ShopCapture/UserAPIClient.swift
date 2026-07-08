import Foundation

struct UserProfileSummary: Sendable {
    let displayName: String
    let accountLine: String
    let roleName: String
    let locationName: String
    let syncStatus: String

    static let placeholder = UserProfileSummary(
        displayName: "扫街合伙人",
        accountLine: "手机号 304****4040",
        roleName: "LV.6 核实官",
        locationName: "石家庄",
        syncStatus: "未登录 · 演示数据"
    )
}

enum UserAPIClient {
    private static let baseURL = URL(string: "https://api.gmpebr.com/index.php")!

    static func login(username: String, password: String, siteID: Int = 1) async throws -> UserProfileSummary {
        var request = URLRequest(url: endpoint(action: "ajax_login"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formBody([
            "username": username,
            "password": password,
            "siteid": "\(siteID)"
        ])

        return try await send(request)
    }

    static func currentUserInfo() async throws -> UserProfileSummary {
        var request = URLRequest(url: endpoint(action: "ajax_user_info"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(request)
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

    private static func send(_ request: URLRequest) async throws -> UserProfileSummary {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let envelope = object as? [String: Any],
              responseCode(from: envelope["code"]) == 200,
              let data = envelope["data"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return UserProfileSummary(data: data)
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
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
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
