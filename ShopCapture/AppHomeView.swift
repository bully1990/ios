import SwiftUI

struct AppHomeView: View {
    var body: some View {
        TabView {
            ServiceHomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            StreetVerifyTaskView()
                .tabItem {
                    Label("扫街", systemImage: "camera.fill")
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
    @State private var services: [String] = []
    @State private var shops: [RecommendedShop] = []
    @State private var hotSearches: [String] = []
    @State private var city = "石家庄市"
    @State private var district = "建华大街"
    @State private var coverage = "98.6"
    @State private var trustScore = "98.6"
    @State private var searchText = ""
    @State private var hasLoadedHome = false

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
                .refreshable {
                    await loadHome(keyword: searchText)
                }
            }
            .navigationBarHidden(true)
            .task {
                guard !hasLoadedHome else { return }
                hasLoadedHome = true
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

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)

                TextField("输入你需要的服务", text: $searchText)
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
        Group {
            if !services.isEmpty {
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
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("推荐店铺")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()
            }

            if shops.isEmpty {
                ContentUnavailableView(
                    "暂无店铺",
                    systemImage: "storefront",
                    description: Text("暂未获取到真实店铺数据")
                )
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
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
            }

            if !shops.isEmpty {
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
        Group {
            if !hotSearches.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("附近服务热搜")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DesignTokens.ink)
                        Spacer()
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
        }
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
            services = feed.services
            hotSearches = feed.hotServices
            let mappedShops = feed.shops.enumerated().map { index, shop in
                shop.recommendedShop(fallbackRank: index + 1)
            }
            shops = mappedShops
        } catch {
            shops = []
            services = []
            hotSearches = []
        }
    }
}

private struct ServiceShortcut: View {
    let title: String

    private var symbol: String {
        if title.contains("手机") || title.contains("维修") { return "iphone.gen3" }
        if title.contains("打印") || title.contains("复印") { return "printer.fill" }
        if title.contains("清洗") || title.contains("家电") { return "washer.fill" }
        if title.contains("锁") { return "lock.fill" }
        return "storefront.fill"
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
                ShopPhoto(path: shop.imageURL, symbol: shop.symbol)
                    .frame(width: 92, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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

private struct ShopPhoto: View {
    let path: String
    let symbol: String

    private var hasImagePath: Bool {
        ImageLoader.image(at: path) != nil || ImageLoader.remoteURL(for: path) != nil
    }

    var body: some View {
        Group {
            if hasImagePath {
                RecordImage(path: path, contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [DesignTokens.emerald, Color(red: 0.05, green: 0.38, blue: 0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .clipped()
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
    @State private var nearbyShops: [NearbyShop] = []
    @State private var insights: [FeedInsight] = []
    @State private var district = "建华大街"
    @State private var scopeText = "1.2km 范围"
    @State private var total = 268

    private static let defaultFilters = ["全部", "维修", "餐饮", "生活服务", "24小时"]
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
        Group {
            if !insights.isEmpty {
                HStack(spacing: 10) {
                    ForEach(insights.prefix(3)) { insight in
                        DiscoveryInsightCard(title: insight.title, value: insight.value, subtitle: insight.subtitle)
                    }
                }
            }
        }
    }

    private var recommendedNearby: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("附近店铺")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("按距离和可信分排序")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            if nearbyShops.isEmpty {
                ContentUnavailableView(
                    "暂无附近店铺",
                    systemImage: "map",
                    description: Text("暂未获取到真实店铺数据")
                )
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(nearbyShops) { shop in
                        NearbyShopCard(shop: shop)
                    }
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
            insights = feed.insights
            let mappedShops = feed.shops.map { $0.nearbyShop() }
            nearbyShops = mappedShops
        } catch {
            filters = Self.defaultFilters
            insights = []
            nearbyShops = []
            total = 0
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
                        Text("扫街")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(DesignTokens.ink)

                        StreetRecordList(pendingRecords: Array(records), approvedRecords: [], rejectedRecords: [])
                    }
                    .padding(18)
                    .padding(.bottom, 78)
                }
            }
            .safeAreaInset(edge: .bottom) {
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
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.regularMaterial)
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
    @State private var profile: UserProfileSummary?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        profileCard
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
            profile = nil
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("我的")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.ink)
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

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let profile {
                ProfileInfoRow(title: "名称", value: profile.displayName, symbol: "person.fill")
                Divider()
                ProfileInfoRow(title: "账号", value: profile.accountLine, symbol: "number")
                Divider()
                ProfileInfoRow(title: "身份", value: profile.roleName, symbol: "shield.lefthalf.filled")
                Divider()
                ProfileInfoRow(title: "位置", value: profile.locationName, symbol: "location.fill")
                Divider()
                ProfileInfoRow(title: "状态", value: profile.syncStatus, symbol: "checkmark.circle.fill")
            } else {
                ContentUnavailableView(
                    "未获取到账户信息",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("请稍后重新进入或检查登录状态")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }
}

private struct ProfileInfoRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)
                .frame(width: 34, height: 34)
                .background(DesignTokens.softEmerald)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
            ShopPhoto(path: shop.imageURL, symbol: shop.symbol)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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

private struct StreetRecordList: View {
    let pendingRecords: [ShopRecord]
    let approvedRecords: [ShopRecord]
    let rejectedRecords: [ShopRecord]
    @State private var selectedStatus: StreetRecordStatus = .pending

    private var totalCount: Int {
        pendingRecords.count + approvedRecords.count + rejectedRecords.count
    }

    private var selectedRecords: [ShopRecord] {
        switch selectedStatus {
        case .pending:
            return pendingRecords
        case .approved:
            return approvedRecords
        case .rejected:
            return rejectedRecords
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("扫街记录")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("\(totalCount) 条")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            if totalCount == 0 {
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
                Picker("记录状态", selection: $selectedStatus) {
                    ForEach(StreetRecordStatus.allCases) { status in
                        Text("\(status.title) \(count(for: status))").tag(status)
                    }
                }
                .pickerStyle(.segmented)

                StreetRecordStatusList(status: selectedStatus, records: selectedRecords)
            }
        }
    }

    private func count(for status: StreetRecordStatus) -> Int {
        switch status {
        case .pending:
            return pendingRecords.count
        case .approved:
            return approvedRecords.count
        case .rejected:
            return rejectedRecords.count
        }
    }
}

private enum StreetRecordStatus: String, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }

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

    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .approved:
            return DesignTokens.emerald
        case .rejected:
            return .red
        }
    }
}

private struct StreetRecordStatusList: View {
    let status: StreetRecordStatus
    let records: [ShopRecord]

    var body: some View {
        VStack(spacing: 12) {
            if records.isEmpty {
                Text("暂无\(status.title)记录")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(records) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            StreetRecordCard(record: record, statusTitle: status.title, statusColor: status.color)
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
    let statusTitle: String
    let statusColor: Color

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

                    Text(statusTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
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
        return "已记录位置"
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
    let imageURL: String
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
    let imageURL: String
    let coordinate: CGPoint
}

private enum DesignTokens {
    static let background = Color(red: 0.975, green: 0.968, blue: 0.944)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.075)
    static let secondaryText = Color(red: 0.39, green: 0.42, blue: 0.48)
    static let emerald = Color(red: 0.0, green: 0.52, blue: 0.37)
    static let softEmerald = Color(red: 0.9, green: 0.965, blue: 0.94)
    static let line = Color.black.opacity(0.07)
}
