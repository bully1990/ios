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
    private let services = ["手机维修", "打印复印", "家电清洗", "门锁维修", "餐饮外卖"]
    private let shops = [
        RecommendedShop(
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
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(DesignTokens.ink)
                    Text("石家庄市")
                        .font(.title3.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }

                Text("数据覆盖 98.6% 的城区")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(DesignTokens.emerald)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("平台可信度 98.6")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.emerald)
                    Text("数据真实 · 用户共建")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
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

                Label("建华大街", systemImage: "location")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)

                Text("输入服务，如手机维修、开锁、家电清洗")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                Divider()
                    .frame(height: 26)

                Label("当前位置", systemImage: "location.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)
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
                ServiceShortcut(title: service)
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
                ForEach(["手机换电池", "空调清洗", "开锁换锁", "打印复印", "电脑维修", "外卖订餐"], id: \.self) { item in
                    Text(item)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(DesignTokens.softEmerald)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    private let filters = ["全部", "维修", "餐饮", "生活服务", "24小时"]
    private let nearbyShops = [
        NearbyShop(
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
                        mapHero
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
                    Text("建华大街")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignTokens.emerald)

                Text("1.2km 范围")
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

    private var mapHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.14, blue: 0.13),
                            Color(red: 0.04, green: 0.32, blue: 0.25),
                            Color(red: 0.81, green: 0.88, blue: 0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MapGridOverlay()
                .opacity(0.48)

            ForEach(nearbyShops) { shop in
                MapPin(shop: shop)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("智能探索", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())

                    Spacer()

                    Label("重新定位", systemImage: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(alignment: .leading, spacing: 5) {
                    Text("附近 268 家可服务商户")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)

                    Text("优先展示电话真实、近期更新、评价稳定的店铺")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(16)
        }
        .frame(height: 312)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Text(filter)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(filter == "全部" ? .white : DesignTokens.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(filter == "全部" ? DesignTokens.ink : .white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(filter == "全部" ? .clear : DesignTokens.line, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 10) {
            DiscoveryInsightCard(title: "热区", value: "万达金街", subtitle: "服务密度最高")
            DiscoveryInsightCard(title: "响应", value: "8分钟", subtitle: "平均可联系")
            DiscoveryInsightCard(title: "可信", value: "96.1", subtitle: "均值评分")
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
}

private struct StreetVerifyTaskView: View {
    @State private var isShowingCapture = false

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
                            TaskMetric(title: "待审核", value: "12", color: .orange)
                            TaskMetric(title: "已通过", value: "86", color: DesignTokens.emerald)
                            TaskMetric(title: "未通过", value: "3", color: .red)
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

                            Text("今日预计收益 36 金币")
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

                        StaticTaskList()
                    }
                    .padding(18)
                }
            }
            .fullScreenCover(isPresented: $isShowingCapture) {
                ZStack(alignment: .topLeading) {
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
                    .padding(.leading, 18)
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
        ProfileStat(title: "待审核", value: "12", subtitle: "采集记录", color: Color.orange),
        ProfileStat(title: "已通过", value: "86", subtitle: "真实入库", color: DesignTokens.emerald),
        ProfileStat(title: "可信贡献", value: "98.2", subtitle: "贡献指数", color: DesignTokens.ink)
    ]

    private let quickActions = [
        ProfileAction(title: "我的采集", subtitle: "查看扫街记录", symbol: "camera.viewfinder", tint: DesignTokens.emerald),
        ProfileAction(title: "审核进度", subtitle: "待审/通过/未通过", symbol: "checkmark.seal.fill", tint: Color.orange),
        ProfileAction(title: "我的评价", subtitle: "评价与收藏", symbol: "star.bubble.fill", tint: Color(red: 0.12, green: 0.34, blue: 0.78)),
        ProfileAction(title: "身份认证", subtitle: "众包人员资料", symbol: "person.text.rectangle.fill", tint: DesignTokens.ink)
    ]

    private let settings = [
        ProfileSetting(title: "账号与安全", subtitle: "登录密码、绑定手机", symbol: "lock.shield.fill"),
        ProfileSetting(title: "消息通知", subtitle: "审核、奖励、咨询提醒", symbol: "bell.badge.fill"),
        ProfileSetting(title: "数据与隐私", subtitle: "定位权限、图片上传说明", symbol: "hand.raised.fill"),
        ProfileSetting(title: "帮助与反馈", subtitle: "问题反馈、客服支持", symbol: "questionmark.circle.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        profileHero
                        walletCard
                        contributionStats
                        quickActionGrid
                        auditTimeline
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

    private var profileHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.06, blue: 0.07),
                            Color(red: 0.04, green: 0.27, blue: 0.22),
                            DesignTokens.emerald
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 160, height: 160)
                .offset(x: 52, y: -58)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.16))
                            .frame(width: 70, height: 70)

                        Image(systemName: "person.crop.circle.fill.badge.checkmark")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(profile.displayName)
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)

                            Text(profile.syncStatus.contains("已同步") ? "已登录" : "演示")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DesignTokens.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white)
                                .clipShape(Capsule())
                        }

                        Text(profile.accountLine)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))

                        HStack(spacing: 8) {
                            Label(profile.locationName, systemImage: "location.fill")
                            Label(profile.roleName, systemImage: "shield.lefthalf.filled")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    ProfilePill(title: "今日可提现", value: "¥12.86")
                    ProfilePill(title: "账号状态", value: profile.syncStatus)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 196)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("金币钱包", systemImage: "bitcoinsign.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("提现")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(DesignTokens.emerald)
                    .clipShape(Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("1,286")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.ink)

                Text("金币")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            HStack {
                Label("已通过记录自动入账", systemImage: "checkmark.circle.fill")
                Spacer()
                Text("预计到账 36 金币")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DesignTokens.line, lineWidth: 1)
        )
    }

    private func refreshProfile() async {
        do {
            profile = try await UserAPIClient.currentUserInfo()
        } catch {
            profile = .placeholder
        }
    }

    private var contributionStats: some View {
        HStack(spacing: 10) {
            ForEach(stats) { stat in
                ProfileStatCard(stat: stat)
            }
        }
    }

    private var quickActionGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("常用功能")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(quickActions) { action in
                    ProfileActionCard(action: action)
                }
            }
        }
    }

    private var auditTimeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近审核")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)

                Spacer()

                Text("全部记录")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            VStack(spacing: 0) {
                ProfileAuditRow(title: "云记木桶饭", status: "待审核", subtitle: "电话与门头照片已提交", color: Color.orange)
                Divider().padding(.leading, 46)
                ProfileAuditRow(title: "星火手机维修", status: "已通过", subtitle: "奖励 18 金币已入账", color: DesignTokens.emerald)
                Divider().padding(.leading, 46)
                ProfileAuditRow(title: "安捷开锁换锁", status: "需补充", subtitle: "服务内容描述不完整", color: Color.red)
            }
            .padding(.horizontal, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
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

private struct MapGridOverlay: View {
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1.2)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? 58 : -42))
                    .offset(x: CGFloat(index - 3) * 42)
            }

            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1.2)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -9 : 13))
                    .offset(y: CGFloat(index - 2) * 48)
            }

            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
                .frame(width: 178, height: 178)
                .offset(x: 38, y: -16)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .frame(width: 246, height: 246)
                .offset(x: -72, y: 68)
        }
    }
}

private struct MapPin: View {
    let shop: NearbyShop

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 5) {
                Image(systemName: shop.symbol)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(DesignTokens.emerald)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 5)

                Text(shop.distance)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .position(
                x: proxy.size.width * shop.coordinate.x,
                y: proxy.size.height * shop.coordinate.y
            )
        }
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

private struct StaticTaskList: View {
    private let rows = [
        "核实建华大街手机维修门店电话",
        "补充中山路家电清洗服务内容",
        "拍摄裕华区新开门店门头"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐任务")
                .font(.headline.weight(.bold))
                .foregroundStyle(DesignTokens.ink)

            ForEach(rows, id: \.self) { row in
                HStack {
                    Image(systemName: "scope")
                        .foregroundStyle(DesignTokens.emerald)
                    Text(row)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct RecommendedShop: Identifiable {
    let id = UUID()
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

private struct NearbyShop: Identifiable {
    let id = UUID()
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
