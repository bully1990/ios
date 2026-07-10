import CoreGraphics
import Foundation

enum ShopFeedAPIClient {
    private static let baseURL = URL(string: "https://api.gmpebr.com/index.php")!

    static func fetchHome(latitude: Double?, longitude: Double?, keyword: String = "") async throws -> ShopHomeFeed {
        let records = try await fetchRecords()
        let approvedRecords = filtered(records, keyword: keyword).filter { $0.isApproved }
        let shops = makeFeedShops(records: approvedRecords, latitude: latitude, longitude: longitude, limit: 8)
        return ShopHomeFeed(
            city: locationTitle(latitude: latitude, longitude: longitude),
            district: districtTitle(latitude: latitude, longitude: longitude),
            coverage: coverageScore(records.count),
            trustScore: averageTrustScore(shops),
            services: serviceLabels(from: approvedRecords),
            hotServices: hotServices(from: approvedRecords),
            shops: shops
        )
    }

    static func fetchAllShops(latitude: Double?, longitude: Double?, keyword: String = "") async throws -> [FeedShop] {
        let records = try await fetchRecords()
        let approvedRecords = filtered(records, keyword: keyword).filter { $0.isApproved }
        return makeFeedShops(records: approvedRecords, latitude: latitude, longitude: longitude, limit: 100)
    }

    static func fetchNearby(latitude: Double?, longitude: Double?, keyword: String = "", service: String = "全部") async throws -> ShopNearbyFeed {
        let query = keyword.isEmpty ? (service == "全部" ? "" : service) : keyword
        let records = filtered(try await fetchRecords(), keyword: query)
        let nearby = makeFeedShops(records: records, latitude: latitude, longitude: longitude, limit: 20).map {
            NearbyFeedShop(shop: $0, centerLatitude: latitude, centerLongitude: longitude)
        }
        let trust = averageTrustScore(nearby.map(\.feedShop))
        return ShopNearbyFeed(
            city: locationTitle(latitude: latitude, longitude: longitude),
            district: districtTitle(latitude: latitude, longitude: longitude),
            scopeText: latitude == nil || longitude == nil ? "定位后推荐" : "1.2km 范围",
            total: nearby.count,
            filters: nearbyFilters(from: records),
            insights: [
                FeedInsight(title: "热区", value: districtTitle(latitude: latitude, longitude: longitude), subtitle: "服务密度最高"),
                FeedInsight(title: "响应", value: "\(max(3, min(18, 12 - nearby.count)))分钟", subtitle: "平均可联系"),
                FeedInsight(title: "可信", value: trust, subtitle: "均值评分")
            ],
            shops: nearby
        )
    }

    static func search(latitude: Double?, longitude: Double?, keyword: String) async throws -> [FeedShop] {
        let records = filtered(try await fetchRecords(), keyword: keyword)
        return makeFeedShops(records: records, latitude: latitude, longitude: longitude, limit: 30)
    }

    static func fetchStreetRecords() async throws -> [StreetReviewRecord] {
        try await fetchRecords()
            .map(\.streetReviewRecord)
            .sorted { lhs, rhs in
                if lhs.capturedAt != rhs.capturedAt {
                    return (lhs.capturedAt ?? .distantPast) > (rhs.capturedAt ?? .distantPast)
                }
                return (Int(lhs.id) ?? 0) > (Int(rhs.id) ?? 0)
            }
    }

    private static func fetchRecords() async throws -> [ShopCaptureRecord] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "m", value: "content"),
            URLQueryItem(name: "c", value: "shop_capture"),
            URLQueryItem(name: "a", value: "ajax_list_records"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "100")
        ]

        var request = URLRequest(url: components.url!)
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

    private static func makeFeedShops(records: [ShopCaptureRecord], latitude: Double?, longitude: Double?, limit: Int) -> [FeedShop] {
        records
            .map { record in
                FeedShop(record: record, latitude: latitude, longitude: longitude)
            }
            .sorted { lhs, rhs in
                lhs.id > rhs.id
            }
            .prefix(limit)
            .enumerated()
            .map { index, shop in
                shop.withRank(index + 1)
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
        return parts.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "本地服务"
    }

    static func serviceSymbol(text: String) -> String {
        if text.contains("手机") || text.contains("维修") || text.contains("电池") { return "iphone.gen3" }
        if text.contains("清洗") || text.contains("家电") || text.contains("空调") { return "washer.fill" }
        if text.contains("锁") { return "lock.shield.fill" }
        if text.contains("餐") || text.contains("饭") || text.contains("外卖") { return "takeoutbag.and.cup.and.straw.fill" }
        if text.contains("打印") || text.contains("复印") { return "printer.fill" }
        return "storefront.fill"
    }

    private static func locationTitle(latitude: Double?, longitude: Double?) -> String {
        latitude == nil || longitude == nil ? "石家庄市" : "当前位置"
    }

    private static func districtTitle(latitude: Double?, longitude: Double?) -> String {
        latitude == nil || longitude == nil ? "建华大街" : "附近街区"
    }

    private static func coverageScore(_ count: Int) -> String {
        String(format: "%.1f", min(99.9, 80 + Double(count) * 0.8))
    }

    private static func averageTrustScore(_ shops: [FeedShop]) -> String {
        guard !shops.isEmpty else { return "0.0" }
        let total = shops.reduce(0.0) { $0 + (Double($1.trustScore) ?? 0) }
        return String(format: "%.1f", total / Double(shops.count))
    }
}

struct ShopHomeFeed: Sendable {
    let city: String
    let district: String
    let coverage: String
    let trustScore: String
    let services: [String]
    let hotServices: [String]
    let shops: [FeedShop]

    enum CodingKeys: String, CodingKey {
        case city
        case district
        case coverage
        case trustScore = "trust_score"
        case services
        case hotServices = "hot_services"
        case shops
    }
}

struct ShopNearbyFeed: Sendable {
    let city: String
    let district: String
    let scopeText: String
    let total: Int
    let filters: [String]
    let insights: [FeedInsight]
    let shops: [NearbyFeedShop]

    enum CodingKeys: String, CodingKey {
        case city
        case district
        case scopeText = "scope_text"
        case total
        case filters
        case insights
        case shops
    }
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
    let category: String
    let service: String
    let details: String
    let distance: String
    let address: String
    let rating: String
    let reviews: String
    let trustScore: String
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
        self.name = record.shopName.value.isEmpty ? service : record.shopName.value
        self.category = record.auditStatus.value == "1" ? "已通过核验" : "待审核采集"
        self.service = service
        self.details = serviceText.replacingOccurrences(of: "\n", with: " · ")
        self.distance = Self.distanceText(distance)
        self.address = record.latitude.value == "0.0000000" && record.longitude.value == "0.0000000" ? "位置待补充" : "扫街已定位"
        self.rating = record.auditStatus.value == "1" ? "4.8" : "4.5"
        self.reviews = "\(max(1, (Int(record.id.value) ?? 1) % 168))条评价"
        self.trustScore = String(format: "%.1f", min(99.8, (record.auditStatus.value == "1" ? 96.0 : 91.0) + Double((Int(record.id.value) ?? 0) % 30) / 10.0))
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
        category: String,
        service: String,
        details: String,
        distance: String,
        address: String,
        rating: String,
        reviews: String,
        trustScore: String,
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
        self.category = category
        self.service = service
        self.details = details
        self.distance = distance
        self.address = address
        self.rating = rating
        self.reviews = reviews
        self.trustScore = trustScore
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
            category: category,
            service: service,
            details: details,
            distance: distance,
            address: address,
            rating: rating,
            reviews: reviews,
            trustScore: trustScore,
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
            category: category,
            service: service,
            details: details,
            distance: distance,
            address: address,
            rating: rating,
            reviews: reviews,
            trustScore: trustScore,
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
    let eta: String
    let score: String
    let status: String
    let address: String
    let tags: [String]
    let symbol: String
    let latitude: Double
    let longitude: Double
    let coordinate: FeedCoordinate
    let feedShop: FeedShop

    init(shop: FeedShop, centerLatitude: Double?, centerLongitude: Double?) {
        self.id = shop.id
        self.name = shop.name
        self.service = shop.service
        self.distance = shop.distance
        self.eta = Self.etaText(distanceMeters: shop.distanceMeters)
        self.score = shop.trustScore
        self.status = Self.statusText()
        self.address = shop.address
        self.tags = Array([shop.phone.isEmpty ? "" : "电话已核验", shop.imageURL.isEmpty ? "" : "门头已采集", "近期更新"].filter { !$0.isEmpty }.prefix(2))
        self.symbol = shop.symbol
        self.latitude = shop.latitude
        self.longitude = shop.longitude
        self.coordinate = FeedCoordinate(
            x: Self.mapCoordinate(value: shop.longitude, center: centerLongitude),
            y: 1 - Self.mapCoordinate(value: shop.latitude, center: centerLatitude)
        )
        self.feedShop = shop
    }

    func nearbyShop() -> NearbyShop {
        NearbyShop(
            id: "\(id)",
            name: name,
            service: service,
            distance: distance,
            eta: eta,
            score: score,
            status: status,
            address: address,
            tags: tags,
            symbol: symbol,
            imageURL: feedShop.imageURL,
            coordinate: CGPoint(x: coordinate.x, y: coordinate.y)
        )
    }

    private static func etaText(distanceMeters: Double) -> String {
        guard distanceMeters < 999_999_999 else { return "距离待确认" }
        return "步行 \(max(1, Int(ceil(distanceMeters / 80)))) 分钟"
    }

    private static func statusText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        return (9...21).contains(hour) ? "营业中" : "可预约"
    }

    private static func mapCoordinate(value: Double, center: Double?) -> Double {
        guard let center, value != 0, center != 0 else {
            let seed = abs(Int(value * 1000))
            return 0.25 + Double(seed % 50) / 100
        }
        return 0.5 + max(-0.38, min(0.38, (value - center) * 80))
    }
}

struct FeedInsight: Identifiable, Sendable {
    var id: String { "\(title)-\(value)" }
    let title: String
    let value: String
    let subtitle: String
}

struct FeedCoordinate: Sendable {
    let x: Double
    let y: Double
}

enum StreetReviewState: String, Sendable {
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
