import Foundation

enum ShopFeedAPIClient {
    private static let baseURL = URL(string: "https://api.gmpebr.com/index.php")!

    static func fetchHome(latitude: Double?, longitude: Double?, keyword: String = "") async throws -> ShopHomeFeed {
        let records = try await fetchRecords()
        let approvedRecords = filtered(records, keyword: keyword).filter { $0.isApproved }
        let shops = makeFeedShops(records: approvedRecords, latitude: latitude, longitude: longitude, limit: 8)
        return ShopHomeFeed(
            hotServices: hotServices(from: approvedRecords),
            shops: shops
        )
    }

    static func fetchAllShops(
        latitude: Double?,
        longitude: Double?,
        keyword: String = "",
        page: Int,
        pageSize: Int
    ) async throws -> PagedResult<FeedShop> {
        let records = try await fetchRecords(page: page, pageSize: pageSize, auditStatus: "1")
        let approvedRecords = filtered(records, keyword: keyword).filter { $0.isApproved }
        let shops = makeFeedShops(
            records: approvedRecords,
            latitude: latitude,
            longitude: longitude,
            limit: pageSize,
            rankOffset: (page - 1) * pageSize
        )
        return PagedResult(items: shops, page: page, hasMore: records.count == pageSize)
    }

    static func fetchNearby(latitude: Double?, longitude: Double?, keyword: String = "", service: String = "全部") async throws -> ShopNearbyFeed {
        let query = keyword.isEmpty ? (service == "全部" ? "" : service) : keyword
        let records = filtered(try await fetchRecords(), keyword: query).filter { $0.isApproved }
        let nearby = makeFeedShops(records: records, latitude: latitude, longitude: longitude, limit: 20).map {
            NearbyFeedShop(shop: $0)
        }
        return ShopNearbyFeed(
            filters: nearbyFilters(from: records),
            shops: nearby
        )
    }

    static func search(latitude: Double?, longitude: Double?, keyword: String) async throws -> [FeedShop] {
        let records = filtered(try await fetchRecords(), keyword: keyword)
        return makeFeedShops(records: records, latitude: latitude, longitude: longitude, limit: 30)
    }

    static func fetchStreetRecords(
        reviewState: StreetReviewState,
        page: Int,
        pageSize: Int
    ) async throws -> PagedResult<StreetReviewRecord> {
        let records = try await fetchRecords(
            page: page,
            pageSize: pageSize,
            auditStatus: reviewState.apiValue
        )
        let items = records
            .map(\.streetReviewRecord)
            .sorted { lhs, rhs in
                if lhs.capturedAt != rhs.capturedAt {
                    return (lhs.capturedAt ?? .distantPast) > (rhs.capturedAt ?? .distantPast)
                }
                return (Int(lhs.id) ?? 0) > (Int(rhs.id) ?? 0)
            }
        return PagedResult(items: items, page: page, hasMore: records.count == pageSize)
    }

    private static func fetchRecords(
        page: Int = 1,
        pageSize: Int = 100,
        auditStatus: String? = nil
    ) async throws -> [ShopCaptureRecord] {
        var request = URLRequest(url: recordsURL(page: page, pageSize: pageSize, auditStatus: auditStatus))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<[ShopCaptureRecord]>.self, from: data)
        guard envelope.normalizedCode == 200 else {
            throw URLError(.cannotParseResponse)
        }
        return envelope.data
    }

    static func recordsURL(page: Int, pageSize: Int, auditStatus: String? = nil) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "m", value: "content"),
            URLQueryItem(name: "c", value: "shop_capture"),
            URLQueryItem(name: "a", value: "ajax_list_records"),
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "pagesize", value: "\(max(1, pageSize))")
        ]
        if let auditStatus {
            components.queryItems?.append(URLQueryItem(name: "audit_status", value: auditStatus))
        }
        return components.url!
    }

    private static func filtered(_ records: [ShopCaptureRecord], keyword: String) -> [ShopCaptureRecord] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return records
        }
        return records.filter { record in
            [record.shopName.value, record.serviceContent.value, record.fullText.value, record.phoneNumber.value]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(trimmed)
        }
    }

    private static func makeFeedShops(
        records: [ShopCaptureRecord],
        latitude: Double?,
        longitude: Double?,
        limit: Int,
        rankOffset: Int = 0
    ) -> [FeedShop] {
        records
            .map { record in
                FeedShop(record: record, latitude: latitude, longitude: longitude)
            }
            .sorted { lhs, rhs in
                if latitude != nil, longitude != nil, lhs.distanceMeters != rhs.distanceMeters {
                    return lhs.distanceMeters < rhs.distanceMeters
                }
                return lhs.id > rhs.id
            }
            .prefix(limit)
            .enumerated()
            .map { index, shop in
                shop.withRank(rankOffset + index + 1)
            }
    }

    private static func serviceLabels(from records: [ShopCaptureRecord]) -> [String] {
        let detected = records.map { primaryService(text: $0.serviceContent.value.isEmpty ? $0.fullText.value : $0.serviceContent.value) }
        return unique(detected).prefix(5).map { $0 }
    }

    private static func hotServices(from records: [ShopCaptureRecord]) -> [String] {
        Array(serviceLabels(from: records).prefix(8))
    }

    private static func nearbyFilters(from records: [ShopCaptureRecord]) -> [String] {
        Array((["全部"] + serviceLabels(from: records)).prefix(6))
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, !seen.contains(cleaned) else {
                return false
            }
            seen.insert(cleaned)
            return true
        }
    }

    static func primaryService(text: String) -> String {
        let separators = CharacterSet(charactersIn: "，,、;；|/\n\r ")
        let parts = text.components(separatedBy: separators)
        return parts.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    static func serviceSymbol(text: String) -> String {
        if text.contains("手机") || text.contains("维修") || text.contains("电池") { return "iphone.gen3" }
        if text.contains("清洗") || text.contains("家电") || text.contains("空调") { return "washer.fill" }
        if text.contains("锁") { return "lock.shield.fill" }
        if text.contains("餐") || text.contains("饭") || text.contains("外卖") { return "takeoutbag.and.cup.and.straw.fill" }
        if text.contains("打印") || text.contains("复印") { return "printer.fill" }
        return "storefront.fill"
    }

}

struct ShopHomeFeed: Sendable {
    let hotServices: [String]
    let shops: [FeedShop]
}

struct PagedResult<Item: Sendable>: Sendable {
    let items: [Item]
    let page: Int
    let hasMore: Bool
}

struct ShopNearbyFeed: Sendable {
    let filters: [String]
    let shops: [NearbyFeedShop]
}

struct ShopSearchFeed: Sendable {
    let keyword: String
    let total: Int
    let shops: [FeedShop]
}

struct FeedShop: Identifiable, Sendable {
    let id: Int
    let rank: Int
    let name: String
    let service: String
    let details: String
    let distance: String
    let phone: String
    let symbol: String
    let latitude: Double
    let longitude: Double
    let imageURL: String
    let distanceMeters: Double

    fileprivate init(record: ShopCaptureRecord, latitude: Double?, longitude: Double?) {
        let serviceText = record.serviceContent.value.isEmpty ? record.fullText.value : record.serviceContent.value
        let service = ShopFeedAPIClient.primaryService(text: serviceText)
        let distance = Self.distanceMeters(
            latitude,
            longitude,
            Double(record.latitude.value),
            Double(record.longitude.value)
        )

        self.id = Int(record.id.value) ?? 0
        self.rank = 0
        self.name = record.shopName.value
        self.service = service
        self.details = serviceText.replacingOccurrences(of: "\n", with: " · ")
        self.distance = Self.distanceText(distance)
        self.phone = record.phoneNumber.value
        self.symbol = ShopFeedAPIClient.serviceSymbol(text: serviceText)
        self.latitude = Double(record.latitude.value) ?? 0
        self.longitude = Double(record.longitude.value) ?? 0
        self.imageURL = record.resolvedImageURL
        self.distanceMeters = distance
    }

    private init(
        id: Int,
        rank: Int,
        name: String,
        service: String,
        details: String,
        distance: String,
        phone: String,
        symbol: String,
        latitude: Double,
        longitude: Double,
        imageURL: String,
        distanceMeters: Double
    ) {
        self.id = id
        self.rank = rank
        self.name = name
        self.service = service
        self.details = details
        self.distance = distance
        self.phone = phone
        self.symbol = symbol
        self.latitude = latitude
        self.longitude = longitude
        self.imageURL = imageURL
        self.distanceMeters = distanceMeters
    }

    func withRank(_ rank: Int) -> FeedShop {
        FeedShop(
            id: id,
            rank: rank,
            name: name,
            service: service,
            details: details,
            distance: distance,
            phone: phone,
            symbol: symbol,
            latitude: latitude,
            longitude: longitude,
            imageURL: imageURL,
            distanceMeters: distanceMeters
        )
    }

    private static func distanceMeters(_ lat1: Double?, _ lng1: Double?, _ lat2: Double?, _ lng2: Double?) -> Double {
        guard let lat1, let lng1, let lat2, let lng2, lat1 != 0, lng1 != 0, lat2 != 0, lng2 != 0 else {
            return 999_999_999
        }
        let earth = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return earth * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private static func distanceText(_ meters: Double) -> String {
        guard meters < 999_999_999 else { return "未知" }
        if meters < 1000 { return "\(Int(meters.rounded()))m" }
        return String(format: "%.1fkm", meters / 1000)
    }

    func recommendedShop(fallbackRank: Int) -> RecommendedShop {
        RecommendedShop(
            id: "\(id)",
            rank: rank > 0 ? rank : fallbackRank,
            name: name,
            service: service,
            details: details,
            distance: distance,
            phone: phone,
            symbol: symbol,
            imageURL: imageURL
        )
    }
}

struct NearbyFeedShop: Identifiable, Sendable {
    let id: Int
    let name: String
    let service: String
    let distance: String
    let symbol: String
    let latitude: Double
    let longitude: Double
    let feedShop: FeedShop

    init(shop: FeedShop) {
        self.id = shop.id
        self.name = shop.name
        self.service = shop.service
        self.distance = shop.distance
        self.symbol = shop.symbol
        self.latitude = shop.latitude
        self.longitude = shop.longitude
        self.feedShop = shop
    }

    func nearbyShop() -> NearbyShop {
        NearbyShop(
            id: "\(id)",
            name: name,
            service: service,
            distance: distance,
            symbol: symbol,
            imageURL: feedShop.imageURL
        )
    }
}

enum StreetReviewState: String, CaseIterable, Sendable {
    case pending
    case approved
    case rejected

    var title: String {
        switch self {
        case .pending:
            return "待审核"
        case .approved:
            return "已通过"
        case .rejected:
            return "未通过"
        }
    }

    var apiValue: String {
        switch self {
        case .pending:
            return "0"
        case .approved:
            return "1"
        case .rejected:
            return "2"
        }
    }
}

struct StreetReviewRecord: Identifiable, Sendable {
    let id: String
    let clientUUID: String
    let shopName: String
    let serviceContent: String
    let phoneNumber: String
    let fullText: String
    let imageURL: String
    let latitude: Double
    let longitude: Double
    let capturedAt: Date?
    let reviewState: StreetReviewState
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let code: FlexibleInt
    let data: T

    var normalizedCode: Int {
        code.value
    }
}

private struct ShopCaptureRecord: Decodable, Sendable {
    let id: FlexibleString
    let clientUUID: FlexibleString
    let shopName: FlexibleString
    let serviceContent: FlexibleString
    let phoneNumber: FlexibleString
    let fullText: FlexibleString
    let imageURL: FlexibleString
    let latitude: FlexibleString
    let longitude: FlexibleString
    let captureTime: FlexibleString
    let createdAt: FlexibleString
    let auditStatus: FlexibleString

    enum CodingKeys: String, CodingKey {
        case id
        case clientUUID = "client_uuid"
        case shopName = "shop_name"
        case serviceContent = "service_content"
        case phoneNumber = "phone_number"
        case fullText = "full_text"
        case imageURL = "image_url"
        case latitude
        case longitude
        case captureTime = "capture_time"
        case createdAt = "created_at"
        case auditStatus = "audit_status"
    }

    var isApproved: Bool {
        reviewState == .approved
    }

    var reviewState: StreetReviewState {
        let status = auditStatus.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if status == "1" || status == "approved" || status == "pass" || status == "passed" || status == "已通过" {
            return .approved
        }
        if status == "2" || status == "rejected" || status == "fail" || status == "failed" || status == "未通过" {
            return .rejected
        }
        return .pending
    }

    var streetReviewRecord: StreetReviewRecord {
        let timestamp = TimeInterval(captureTime.value) ?? TimeInterval(createdAt.value)
        return StreetReviewRecord(
            id: id.value,
            clientUUID: clientUUID.value,
            shopName: shopName.value,
            serviceContent: serviceContent.value,
            phoneNumber: phoneNumber.value,
            fullText: fullText.value,
            imageURL: resolvedImageURL,
            latitude: Double(latitude.value) ?? 0,
            longitude: Double(longitude.value) ?? 0,
            capturedAt: timestamp.map(Date.init(timeIntervalSince1970:)),
            reviewState: reviewState
        )
    }

    var resolvedImageURL: String {
        guard !imageURL.value.isEmpty else { return "" }
        if let url = URL(string: imageURL.value), url.scheme != nil {
            return url.absoluteString
        }
        return URL(string: imageURL.value, relativeTo: URL(string: "https://api.gmpebr.com")!)?
            .absoluteURL.absoluteString ?? imageURL.value
    }
}

private struct FlexibleInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self), let intValue = Int(stringValue) {
            value = intValue
        } else {
            value = 0
        }
    }
}

private struct FlexibleString: Decodable, Sendable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = "\(intValue)"
        } else if let doubleValue = try? container.decode(Double.self) {
            value = "\(doubleValue)"
        } else {
            value = ""
        }
    }
}
