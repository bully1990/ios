import SwiftUI

struct AppHomeView: View {
    var body: some View {
        TabView {
            ServiceHomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            NearbyDiscoveryView()
                .tabItem {
                    Label("发现/附近", systemImage: "location.fill")
                }

            StreetVerifyTaskView()
                .tabItem {
                    Label("扫街/核实", systemImage: "camera.fill")
                }

            MessageCenterView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }

            ProfileCenterView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .tint(DesignTokens.emerald)
    }
}

private struct ServiceHomeView: View {
    @EnvironmentObject private var locationProvider: LocationProvider
    @State private var services = ServiceHomeView.defaultServices
    @State private var shops = ServiceHomeView.defaultShops
    @State private var hotSearches = ServiceHomeView.defaultHotSearches
    @State private var city = "石家庄市"
    @State private var district = "建华大街"
    @State private var coverage = "98.6"
    @State private var trustScore = "98.6"
    @State private var searchText = ""

    private static let defaultServices = ["手机维修", "打印复印", "家电清洗", "门锁维修", "餐饮外卖"]
    private static let defaultHotSearches = ["手机换电池", "空调清洗", "开锁换锁", "打印复印", "电脑维修", "外卖订餐"]
    private static let defaultShops = [
        RecommendedShop(
            id: "fallback-1",
            rank: 1,
            name: "非凡通讯",
            category: "手机维修中心",
            service: "手机维修",
            details: "换屏 · 电池更换 · 手机配件",
            distance: "120m",
            address: "建华大街万达广场附近",
            rating: "4.8",
            reviews: "128条评价",
            trustScore: "96.3",
            phone: "176 3355 5849",
            symbol: "iphone.gen3"
        ),
        RecommendedShop(
            id: "fallback-2",
            rank: 2,
            name: "新洁家电清洗",
            category: "桥西店",
            service: "家电清洗",
            details: "空调清洗 · 油烟机清洗 · 洗衣机清洗",
            distance: "380m",
            address: "中山西路258号",
            rating: "4.7",
            reviews: "86条评价",
            trustScore: "94.1",
            phone: "153 6912 7788",
            symbol: "washer.fill"
        ),
        RecommendedShop(
            id: "fallback-3",
            rank: 3,
            name: "平安开锁换锁服务部",
            category: "24小时服务",
            service: "门锁维修",
            details: "开锁换锁 · 指纹锁安装 · 锁具维修",
            distance: "560m",
            address: "裕华路与谈固南大街交叉口",
            rating: "4.6",
            reviews: "53条评价",
            trustScore: "93.2",
            phone: "131 8000 6655",
            symbol: "lock.shield.fill"
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        searchHero
                        serviceShortcuts
                        recommendationSection
                        trustStrip
                        nearbyHotSearches
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadHome()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(DesignTokens.ink)
            Text(city)
                .font(.title3.weight(.bold))
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))

            Spacer()
        }
    }

    private var searchHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                Text("需要什么")
                    .foregroundStyle(DesignTokens.ink)
                Text("服务？")
                    .foregroundStyle(DesignTokens.emerald)
            }
            .font(.system(size: 36, weight: .black, design: .rounded))

            HStack {
                Text("搜索服务，优选靠谱商家")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.secondaryText)

                Spacer()

                Label(district, systemImage: "location")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)

                TextField("输入服务，如手机维修、开锁、家电清洗", text: $searchText)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await loadHome(keyword: searchText)
                        }
                    }

                Spacer()

                Divider()
                    .frame(height: 26)

                Label("当前位置", systemImage: "location.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .onTapGesture {
                        Task {
                            await loadHome(keyword: searchText)
                        }
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(.white)
            .overlay(
                Capsule()
                    .stroke(DesignTokens.ink, lineWidth: 1.6)
            )
        }
    }

    private var serviceShortcuts: some View {
        HStack(spacing: 12) {
            ForEach(services, id: \.self) { service in
                Button {
                    searchText = service
                    Task {
                        await loadHome(keyword: service)
                    }
                } label: {
                    ServiceShortcut(title: service)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("为你推荐靠谱店铺")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.secondaryText)

                Spacer()

                Text("基于位置和服务需求推荐")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            VStack(spacing: 0) {
                ForEach(shops) { shop in
                    RecommendedShopRow(shop: shop)

                    if shop.id != shops.last?.id {
                        Divider()
                            .padding(.leading, 114)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(DesignTokens.line, lineWidth: 1)
            )

            Button {
            } label: {
                HStack {
                    Spacer()
                    Text("查看全部店铺")
                    Image(systemName: "chevron.right")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)
            }
        }
    }

    private var trustStrip: some View {
        HStack(spacing: 0) {
            TrustItem(symbol: "checkmark.shield.fill", title: "评价可信分", subtitle: "真实评价多维计算")
            Divider().frame(height: 42)
            TrustItem(symbol: "phone.fill", title: "电话已核验", subtitle: "人工核验真实性")
            Divider().frame(height: 42)
            TrustItem(symbol: "clock.fill", title: "近期有更新", subtitle: "确保信息不过期")
        }
        .padding(.vertical, 14)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var nearbyHotSearches: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("附近服务热搜")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                Text("更多服务")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(hotSearches, id: \.self) { item in
                    Button {
                        searchText = item
                        Task {
                            await loadHome(keyword: item)
                        }
                    } label: {
                        Text(item)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DesignTokens.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(DesignTokens.softEmerald)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @MainActor
    private func loadHome(keyword: String = "") async {
        locationProvider.requestWhenInUseAuthorization()
        let location = await locationProvider.currentLocation(timeout: 2)

        do {
            let feed = try await ShopFeedAPIClient.fetchHome(
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                keyword: keyword
            )
            city = feed.city
            district = feed.district
            coverage = feed.coverage
            trustScore = feed.trustScore
            services = feed.services.isEmpty ? Self.defaultServices : feed.services
            hotSearches = feed.hotServices.isEmpty ? Self.defaultHotSearches : feed.hotServices
            let mappedShops = feed.shops.enumerated().map { index, shop in
                shop.recommendedShop(fallbackRank: index + 1)
            }
            shops = mappedShops.isEmpty ? Self.defaultShops : mappedShops
        } catch {
            shops = Self.defaultShops
            services = Self.defaultServices
            hotSearches = Self.defaultHotSearches
        }
    }
}

private struct ServiceShortcut: View {
    let title: String

    private var symbol: String {
        switch title {
        case "手机维修": return "iphone.gen3"
        case "打印复印": return "printer.fill"
        case "家电清洗": return "washer.fill"
        case "门锁维修": return "lock.fill"
        default: return "scooter"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)
                .frame(height: 28)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct RecommendedShopRow: View {
    let shop: RecommendedShop

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.emerald, Color(red: 0.05, green: 0.38, blue: 0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 86)

                Image(systemName: shop.symbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 92, height: 86)

                Text("\(shop.rank)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(DesignTokens.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shop.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)

                        Text(shop.category)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("可信分")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignTokens.emerald)
                        Text(shop.trustScore)
                            .font(.title3.weight(.black))
                            .foregroundStyle(DesignTokens.emerald)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(DesignTokens.softEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: 8) {
                    Text(shop.service)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.emerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignTokens.softEmerald)
                        .clipShape(Capsule())

                    Text(shop.details)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }

                Text("距您 \(shop.distance)  |  \(shop.address)")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(shop.rating, systemImage: "star.fill")
                        .foregroundStyle(DesignTokens.emerald)
                    Text(shop.reviews)
                    Label("电话已核验", systemImage: "phone.circle")
                    Spacer()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignTokens.secondaryText)

                Label(shop.phone, systemImage: "phone.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct TrustItem: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(DesignTokens.emerald)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NearbyDiscoveryView: View {
    @EnvironmentObject private var locationProvider: LocationProvider
    @State private var filters = NearbyDiscoveryView.defaultFilters
    @State private var selectedFilter = "全部"
    @State private var nearbyShops = NearbyDiscoveryView.defaultNearbyShops
    @State private var insights = NearbyDiscoveryView.defaultInsights
    @State private var district = "建华大街"
    @State private var scopeText = "1.2km 范围"
    @State private var total = 268

    private static let defaultFilters = ["全部", "维修", "餐饮", "生活服务", "24小时"]
    private static let defaultInsights = [
        FeedInsight(title: "热区", value: "万达金街", subtitle: "服务密度最高"),
        FeedInsight(title: "响应", value: "8分钟", subtitle: "平均可联系"),
        FeedInsight(title: "可信", value: "96.1", subtitle: "均值评分")
    ]
    private static let defaultNearbyShops = [
        NearbyShop(
            id: "fallback-nearby-1",
            name: "星火手机维修",
            service: "手机维修 · 快修",
            distance: "96m",
            eta: "步行 2 分钟",
            score: "97.8",
            status: "营业中",
            address: "建华大街北国商圈",
            tags: ["电话已核验", "30天内更新"],
            symbol: "iphone.gen3",
            coordinate: CGPoint(x: 0.68, y: 0.34)
        ),
        NearbyShop(
            id: "fallback-nearby-2",
            name: "云记木桶饭",
            service: "快餐简餐 · 外卖",
            distance: "210m",
            eta: "骑行 3 分钟",
            score: "95.2",
            status: "高峰中",
            address: "万达金街东侧",
            tags: ["近期有评价", "服务稳定"],
            symbol: "takeoutbag.and.cup.and.straw.fill",
            coordinate: CGPoint(x: 0.36, y: 0.57)
        ),
        NearbyShop(
            id: "fallback-nearby-3",
            name: "安捷开锁换锁",
            service: "开锁换锁 · 指纹锁",
            distance: "480m",
            eta: "上门约 12 分钟",
            score: "94.6",
            status: "可预约",
            address: "裕华路沿线服务点",
            tags: ["400电话", "夜间服务"],
            symbol: "lock.shield.fill",
            coordinate: CGPoint(x: 0.78, y: 0.72)
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        filterBar
                        insightStrip
                        recommendedNearby
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadNearby()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("发现附近")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.ink)

                Text("按你所在街区，发现可立即联系的真实服务")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "location.north.circle.fill")
                    Text(district)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)

                Text(scopeText)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DesignTokens.line, lineWidth: 1)
            )
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                        Task {
                            await loadNearby(service: filter)
                        }
                    } label: {
                        Text(filter)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(filter == selectedFilter ? .white : DesignTokens.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(filter == selectedFilter ? DesignTokens.ink : .white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(filter == selectedFilter ? .clear : DesignTokens.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 10) {
            ForEach(insights.prefix(3)) { insight in
                DiscoveryInsightCard(title: insight.title, value: insight.value, subtitle: insight.subtitle)
            }
        }
    }

    private var recommendedNearby: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("附近优选")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("按距离和可信分排序")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            VStack(spacing: 12) {
                ForEach(nearbyShops) { shop in
                    NearbyShopCard(shop: shop)
                }
            }
        }
    }

    @MainActor
    private func loadNearby(service: String? = nil) async {
        locationProvider.requestWhenInUseAuthorization()
        let location = await locationProvider.currentLocation(timeout: 2)

        do {
            let feed = try await ShopFeedAPIClient.fetchNearby(
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                service: service ?? selectedFilter
            )
            district = feed.district
            scopeText = feed.scopeText
            total = feed.total
            filters = feed.filters.isEmpty ? Self.defaultFilters : feed.filters
            insights = feed.insights.isEmpty ? Self.defaultInsights : feed.insights
            let mappedShops = feed.shops.map { $0.nearbyShop() }
            nearbyShops = mappedShops.isEmpty ? Self.defaultNearbyShops : mappedShops
        } catch {
            filters = Self.defaultFilters
            insights = Self.defaultInsights
            nearbyShops = Self.defaultNearbyShops
            total = Self.defaultNearbyShops.count
        }
    }
}

private struct StreetVerifyTaskView: View {
    @State private var isShowingCapture = false
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShopRecord.timestamp, ascending: false)],
        animation: .default
    )
    private var records: FetchedResults<ShopRecord>

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("扫街/核实")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(DesignTokens.ink)

                        Text("采集真实门店信息，核实电话、服务内容和位置。通过审核后获得金币奖励。")
                            .font(.body)
                            .foregroundStyle(DesignTokens.secondaryText)

                        HStack(spacing: 12) {
                            TaskMetric(title: "待审核", value: "\(records.count)", color: .orange)
                            TaskMetric(title: "已通过", value: "0", color: DesignTokens.emerald)
                            TaskMetric(title: "未通过", value: "0", color: .red)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("金币余额", systemImage: "bitcoinsign.circle.fill")
                                    .font(.headline.weight(.bold))
                                Spacer()
                                Text("¥ 可提现")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DesignTokens.emerald)
                            }

                            Text("1,286")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(DesignTokens.ink)

                            Text("本地已采集 \(records.count) 条，审核通过后自动入账")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.secondaryText)
                        }
                        .padding(18)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        Button {
                            isShowingCapture = true
                        } label: {
                            Label("开始扫街录入", systemImage: "camera.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(DesignTokens.emerald)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        StreetRecordList(records: Array(records.prefix(8)))
                    }
                    .padding(18)
                }
            }
            .fullScreenCover(isPresented: $isShowingCapture) {
                ZStack(alignment: .topTrailing) {
                    CameraCaptureView()
                    Button {
                        isShowingCapture = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.42))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 18)
                    .padding(.top, 18)
                }
            }
        }
    }
}

private struct MessageCenterView: View {
    var body: some View {
        StaticFeaturePage(
            title: "消息",
            subtitle: "社交与交易沟通",
            symbol: "message.fill",
            accent: Color(red: 0.1, green: 0.32, blue: 0.8),
            rows: ["商家咨询与服务沟通", "评价反馈与核实通知", "系统审核与奖励到账提醒"]
        )
    }
}

private struct ProfileCenterView: View {
    @State private var profile = UserProfileSummary.placeholder

    private let stats = [
        ProfileStat(title: "待审核", value: "12", subtitle: "待处理", color: Color.orange),
        ProfileStat(title: "已通过", value: "86", subtitle: "本月累计", color: Color(red: 0.18, green: 0.82, blue: 0.42)),
        ProfileStat(title: "可信分", value: "98.2", subtitle: "贡献指数", color: Color(red: 0.0, green: 0.72, blue: 0.96))
    ]

    private let quickActions = [
        ProfileAction(title: "采集", subtitle: "扫街记录", symbol: "camera.viewfinder", tint: Color(red: 0.18, green: 0.82, blue: 0.42)),
        ProfileAction(title: "审核", subtitle: "进度", symbol: "checkmark.seal.fill", tint: Color.orange),
        ProfileAction(title: "认证", subtitle: "资料", symbol: "person.text.rectangle.fill", tint: Color(red: 0.0, green: 0.72, blue: 0.96))
    ]

    private let settings = [
        ProfileSetting(title: "账号与安全", subtitle: "登录密码、绑定手机", symbol: "lock.shield.fill"),
        ProfileSetting(title: "消息通知", subtitle: "审核与奖励提醒", symbol: "bell.badge.fill"),
        ProfileSetting(title: "帮助与反馈", subtitle: "问题反馈、客服支持", symbol: "questionmark.circle.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        activityHero
                        metricStrip
                        actionDock
                        recentAudit
                        settingsList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .task {
                await refreshProfile()
            }
        }
    }

    private func refreshProfile() async {
        do {
            profile = try await UserAPIClient.currentUserInfo()
        } catch {
            profile = .placeholder
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("我的")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.ink)

                Text("保持真实贡献，轻量管理账户。")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer()

            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: 52, height: 52)
                .background(.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignTokens.line, lineWidth: 1))
        }
    }

    private var activityHero: some View {
        HStack(alignment: .center, spacing: 14) {
            ProfileActivityRing()
                .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(profile.displayName)
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)

                        Text(profile.syncStatus.contains("已同步") ? "已登录" : "演示")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.70, green: 1.0, blue: 0.34))
                            .clipShape(Capsule())
                    }

                    Text(profile.accountLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Text("今日贡献")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("12")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("条待审核")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 8) {
                    Label(profile.locationName, systemImage: "location.fill")
                    Label(profile.roleName, systemImage: "shield.lefthalf.filled")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.035, green: 0.04, blue: 0.045))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var metricStrip: some View {
        HStack(spacing: 10) {
            ForEach(stats) { stat in
                ProfileMetricPill(stat: stat)
            }
        }
    }

    private var actionDock: some View {
        HStack(spacing: 10) {
            ForEach(quickActions) { action in
                ProfileActionButton(action: action)
            }
        }
    }

    private var recentAudit: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近审核", action: "全部")

            VStack(spacing: 0) {
                ProfileAuditRow(title: "云记木桶饭", status: "待审核", subtitle: "电话与门头照片已提交", color: Color.orange)
                Divider().padding(.leading, 46)
                ProfileAuditRow(title: "星火手机维修", status: "已通过", subtitle: "奖励 18 金币已入账", color: DesignTokens.emerald)
            }
            .padding(.horizontal, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DesignTokens.line, lineWidth: 1)
            )
        }
    }

    private var settingsList: some View {
        VStack(spacing: 0) {
            ForEach(settings) { setting in
                ProfileSettingRow(setting: setting)

                if setting.id != settings.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct DiscoveryInsightCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct NearbyShopCard: View {
    let shop: NearbyShop

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignTokens.softEmerald)
                    .frame(width: 58, height: 58)

                Image(systemName: shop.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.emerald)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shop.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)

                        Text(shop.service)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(shop.score)
                            .font(.title3.weight(.black))
                            .foregroundStyle(DesignTokens.emerald)
                        Text("可信分")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    Label(shop.distance, systemImage: "location.fill")
                    Label(shop.eta, systemImage: "figure.walk")
                    Text(shop.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.emerald)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignTokens.secondaryText)

                Text(shop.address)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ForEach(shop.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DesignTokens.emerald)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(DesignTokens.softEmerald)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct ProfilePill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let action: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.ink)

            Spacer()

            Text(action)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }
}

private struct ProfileActivityRing: View {
    var body: some View {
        ZStack {
            ring(color: Color(red: 0.18, green: 0.82, blue: 0.42), lineWidth: 13, progress: 0.82)
                .padding(2)
            ring(color: Color(red: 1.0, green: 0.24, blue: 0.52), lineWidth: 13, progress: 0.66)
                .padding(18)
            ring(color: Color(red: 0.0, green: 0.72, blue: 0.96), lineWidth: 13, progress: 0.48)
                .padding(34)

            VStack(spacing: 0) {
                Text("86")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("通过")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }

    private func ring(color: Color, lineWidth: CGFloat, progress: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct ProfileMetricPill: View {
    let stat: ProfileStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(stat.color)
                    .frame(width: 8, height: 8)

                Text(stat.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            }

            Text(stat.value)
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)

            Text(stat.subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct ProfileActionButton: View {
    let action: ProfileAction

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(action.tint)
                    .clipShape(Circle())

                VStack(spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)

                    Text(action.subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DesignTokens.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileStatCard: View {
    let stat: ProfileStat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stat.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)

            Text(stat.value)
                .font(.title.weight(.black))
                .foregroundStyle(stat.color)

            Text(stat.subtitle)
                .font(.caption2)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct ProfileActionCard: View {
    let action: ProfileAction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: action.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(action.tint)
                .frame(width: 44, height: 44)
                .background(action.tint.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct ProfileAuditRow: View {
    let title: String
    let status: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer()

            Text(status)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 13)
    }
}

private struct ProfileSettingRow: View {
    let setting: ProfileSetting

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: setting.symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)
                .frame(width: 38, height: 38)
                .background(DesignTokens.softEmerald)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(setting.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Text(setting.subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(.vertical, 12)
    }
}

private struct StaticFeaturePage: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    let rows: [String]

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 74, height: 74)
                    .background(accent.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text(title)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(DesignTokens.ink)

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.secondaryText)

                VStack(spacing: 0) {
                    ForEach(rows, id: \.self) { row in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                            Text(row)
                                .font(.body.weight(.medium))
                                .foregroundStyle(DesignTokens.ink)
                            Spacer()
                        }
                        .padding(.vertical, 16)

                        if row != rows.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TaskMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)
            Text(value)
                .font(.title.weight(.black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StreetRecordList: View {
    let records: [ShopRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("扫街记录")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("\(records.count) 条")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            if records.isEmpty {
                ContentUnavailableView(
                    "暂无扫街记录",
                    systemImage: "text.viewfinder",
                    description: Text("点击开始扫街录入，识别后的店铺会显示在这里。")
                )
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(records) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            StreetRecordCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct StreetRecordCard: View {
    @ObservedObject var record: ShopRecord

    var body: some View {
        HStack(spacing: 12) {
            RecordThumbnail(path: record.imagePath)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)

                    Spacer()

                    Text("待审核")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(phoneText, systemImage: "phone.fill")
                    Label(locationText, systemImage: "location.fill")
                    Spacer()
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignTokens.secondaryText)

                if let timestamp = record.timestamp {
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }

    private var title: String {
        if let shopName = record.shopName, !shopName.isEmpty {
            return shopName
        }
        return record.phoneNumber?.isEmpty == false ? record.phoneNumber ?? "未命名店铺" : "未命名店铺"
    }

    private var subtitle: String {
        if let serviceContent = record.serviceContent, !serviceContent.isEmpty {
            return serviceContent
        }

        let text = record.fullText?.replacingOccurrences(of: "\n", with: " ") ?? ""
        if text.isEmpty {
            return "服务内容待完善"
        }
        return String(text.prefix(36))
    }

    private var phoneText: String {
        record.phoneNumber?.isEmpty == false ? record.phoneNumber ?? "无号码" : "无号码"
    }

    private var locationText: String {
        if record.latitude == 0 && record.longitude == 0 {
            return "未定位"
        }
        return String(format: "%.4f, %.4f", record.latitude, record.longitude)
    }
}

struct RecommendedShop: Identifiable {
    let id: String
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
}

struct NearbyShop: Identifiable {
    let id: String
    let name: String
    let service: String
    let distance: String
    let eta: String
    let score: String
    let status: String
    let address: String
    let tags: [String]
    let symbol: String
    let coordinate: CGPoint
}

private struct ProfileStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let color: Color
}

private struct ProfileAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

private struct ProfileSetting: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

private enum DesignTokens {
    static let background = Color(red: 0.975, green: 0.968, blue: 0.944)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.075)
    static let secondaryText = Color(red: 0.39, green: 0.42, blue: 0.48)
    static let emerald = Color(red: 0.0, green: 0.52, blue: 0.37)
    static let softEmerald = Color(red: 0.9, green: 0.965, blue: 0.94)
    static let line = Color.black.opacity(0.07)
}
