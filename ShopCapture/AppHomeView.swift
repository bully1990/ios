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
    var body: some View {
        StaticFeaturePage(
            title: "发现/附近",
            subtitle: "地图探索与智能推荐",
            symbol: "location.fill",
            accent: DesignTokens.emerald,
            rows: ["附近高可信服务热区", "按距离、评分、近期更新排序", "智能推荐当前街区可用商家"]
        )
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
    var body: some View {
        StaticFeaturePage(
            title: "我的",
            subtitle: "个人中心与身份管理",
            symbol: "person.fill",
            accent: DesignTokens.ink,
            rows: ["用户身份与众包身份", "金币钱包与提现记录", "我的评价、收藏和采集记录"]
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

private enum DesignTokens {
    static let background = Color(red: 0.975, green: 0.968, blue: 0.944)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.075)
    static let secondaryText = Color(red: 0.39, green: 0.42, blue: 0.48)
    static let emerald = Color(red: 0.0, green: 0.52, blue: 0.37)
    static let softEmerald = Color(red: 0.9, green: 0.965, blue: 0.94)
    static let line = Color.black.opacity(0.07)
}
