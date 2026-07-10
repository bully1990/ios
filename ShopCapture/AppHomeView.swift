import SwiftUI
import UIKit
import CoreLocation

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
        .tint(ProfilePalette.systemBlue)
        .background(TabBarDoubleTapObserver())
    }
}

private extension Notification.Name {
    static let homeTabDoubleTapped = Notification.Name("shopcapture.homeTabDoubleTapped")
    static let streetTabDoubleTapped = Notification.Name("shopcapture.streetTabDoubleTapped")
}

private struct TabBarDoubleTapObserver: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> TabBarObserverViewController {
        let controller = TabBarObserverViewController()
        controller.onTabBarAvailable = { [weak coordinator = context.coordinator] tabBarController in
            coordinator?.install(on: tabBarController)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: TabBarObserverViewController, context: Context) {
        uiViewController.attachIfPossible()
    }

    static func dismantleUIViewController(_ uiViewController: TabBarObserverViewController, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject {
        private weak var tabBarController: UITabBarController?
        private weak var tabBar: UITabBar?
        private var recognizer: UITapGestureRecognizer?

        func install(on tabBarController: UITabBarController) {
            let tabBar = tabBarController.tabBar
            guard self.tabBar !== tabBar else { return }

            uninstall()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            recognizer.numberOfTapsRequired = 2
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            tabBar.addGestureRecognizer(recognizer)

            self.tabBarController = tabBarController
            self.tabBar = tabBar
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer, let tabBar {
                tabBar.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            tabBar = nil
            tabBarController = nil
        }

        @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let tabBar,
                  let tabBarController,
                  let items = tabBar.items,
                  !items.isEmpty else {
                return
            }

            let location = recognizer.location(in: tabBar)
            let itemWidth = tabBar.bounds.width / CGFloat(items.count)
            let index = min(max(Int(location.x / itemWidth), 0), items.count - 1)
            guard index == tabBarController.selectedIndex else { return }

            switch index {
            case 0:
                NotificationCenter.default.post(name: .homeTabDoubleTapped, object: nil)
            case 1:
                NotificationCenter.default.post(name: .streetTabDoubleTapped, object: nil)
            default:
                break
            }
        }
    }
}

private final class TabBarObserverViewController: UIViewController {
    var onTabBarAvailable: ((UITabBarController) -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachIfPossible()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        attachIfPossible()
    }

    func attachIfPossible() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let tabBarController = self.tabBarController else { return }
            self.onTabBarAvailable?(tabBarController)
        }
    }
}

private struct TopReloadIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("正在刷新")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(DesignTokens.ink)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在刷新数据")
    }
}

private struct ServiceHomeView: View {
    @EnvironmentObject private var locationProvider: LocationProvider
    @AppStorage("shopcapture.usesManualCity") private var usesManualCity = false
    @AppStorage("shopcapture.manualCityName") private var manualCityName = ""
    @AppStorage("shopcapture.manualCityLatitude") private var manualCityLatitude = 0.0
    @AppStorage("shopcapture.manualCityLongitude") private var manualCityLongitude = 0.0
    @State private var shops: [RecommendedShop] = []
    @State private var hotSearches: [String] = []
    @State private var city = "石家庄市"
    @State private var district = "建华大街"
    @State private var coverage = "98.6"
    @State private var trustScore = "98.6"
    @State private var searchText = ""
    @State private var hasLoadedHome = false
    @State private var isReloading = false
    @State private var hasPendingReload = false
    @State private var activeLatitude: Double?
    @State private var activeLongitude: Double?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        searchHero
                        recommendationSection
                        trustStrip
                        nearbyHotSearches
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await reloadHome()
                }

                if isReloading {
                    TopReloadIndicator()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isReloading)
            .navigationBarHidden(true)
            .task {
                guard !hasLoadedHome else { return }
                hasLoadedHome = true
                await reloadHome()
            }
            .onReceive(NotificationCenter.default.publisher(for: .homeTabDoubleTapped)) { _ in
                Task {
                    await reloadHome()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            NavigationLink {
                CitySelectionView(selectedCityName: city) { selection in
                    applyCitySelection(selection)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "mappin.circle.fill")
                    Text(city)
                        .font(.title3.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(DesignTokens.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择城市，当前\(city)")

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
                            await reloadHome()
                        }
                    }

                Spacer()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task {
                            await reloadHome()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }

                Divider()
                    .frame(height: 26)

                Button {
                    applyCitySelection(nil)
                } label: {
                    Label(usesManualCity ? "当前位置" : district, systemImage: "location.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: 108)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("使用当前位置")
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
                        NavigationLink {
                            RecommendedShopDetailView(shop: shop)
                        } label: {
                            RecommendedShopRow(shop: shop)
                        }
                        .buttonStyle(.plain)

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
                NavigationLink {
                    AllRecommendedShopsView(
                        keyword: searchText,
                        latitude: activeLatitude,
                        longitude: activeLongitude
                    )
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
                                    await reloadHome()
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
    private func reloadHome() async {
        guard !isReloading else {
            hasPendingReload = true
            return
        }

        repeat {
            hasPendingReload = false
            isReloading = true
            let keyword = searchText
            await loadHome(keyword: keyword)
            isReloading = false

            if searchText != keyword {
                hasPendingReload = true
            }
        } while hasPendingReload
    }

    @MainActor
    private func loadHome(keyword: String = "") async {
        let location: CLLocation?
        let locationName: (city: String, district: String)?

        if usesManualCity, !manualCityName.isEmpty, manualCityLatitude != 0, manualCityLongitude != 0 {
            location = CLLocation(latitude: manualCityLatitude, longitude: manualCityLongitude)
            locationName = (manualCityName, "手动选择")
        } else {
            locationProvider.requestWhenInUseAuthorization()
            await waitForLocationAuthorizationIfNeeded()
            location = await locationProvider.currentLocation(timeout: 2)
            locationName = await resolveLocationName(location)
        }

        activeLatitude = location?.coordinate.latitude
        activeLongitude = location?.coordinate.longitude

        do {
            let feed = try await ShopFeedAPIClient.fetchHome(
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                keyword: keyword
            )
            city = locationName?.city ?? (location == nil ? "未定位" : feed.city)
            district = locationName?.district ?? (location == nil ? "请开启定位" : feed.district)
            coverage = feed.coverage
            trustScore = feed.trustScore
            hotSearches = feed.hotServices
            let mappedShops = feed.shops.enumerated().map { index, shop in
                shop.recommendedShop(fallbackRank: index + 1)
            }
            shops = mappedShops
        } catch {
            shops = []
            hotSearches = []
        }
    }

    @MainActor
    private func waitForLocationAuthorizationIfNeeded() async {
        guard locationProvider.authorizationStatus == .notDetermined else { return }

        for _ in 0..<30 {
            try? await Task.sleep(for: .milliseconds(100))
            if locationProvider.authorizationStatus != .notDetermined {
                return
            }
        }
    }

    private func resolveLocationName(_ location: CLLocation?) async -> (city: String, district: String)? {
        guard let location else { return nil }

        do {
            guard let placemark = try await CLGeocoder()
                .reverseGeocodeLocation(location)
                .first else {
                return nil
            }

            let resolvedCity = placemark.locality
                ?? placemark.administrativeArea
                ?? "当前位置"
            let resolvedDistrict = placemark.subLocality
                ?? placemark.thoroughfare
                ?? placemark.name
                ?? "附近街区"
            return (resolvedCity, resolvedDistrict)
        } catch {
            return nil
        }
    }

    private func applyCitySelection(_ selection: CityOption?) {
        if let selection {
            usesManualCity = true
            manualCityName = selection.name
            manualCityLatitude = selection.latitude
            manualCityLongitude = selection.longitude
            city = selection.name
            district = "手动选择"
        } else {
            usesManualCity = false
            manualCityName = ""
            manualCityLatitude = 0
            manualCityLongitude = 0
            city = "正在定位"
            district = "当前位置"
        }

        Task {
            await reloadHome()
        }
    }
}

struct CityOption: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { name }

    var pinyin: String {
        name
            .applyingTransform(.toLatin, reverse: false)?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased() ?? name
    }

    var initial: String {
        String(pinyin.prefix(1))
    }
}

private struct CitySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCityName: String
    let onSelect: (CityOption?) -> Void

    @State private var searchText = ""
    @State private var isGeocoding = false
    @State private var geocodingMessage: String?

    private let popularCityNames = ["北京", "上海", "广州", "深圳", "成都", "杭州", "重庆", "石家庄"]

    private var filteredCities: [CityOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.cities }
        let normalized = query.uppercased()
        return Self.cities.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.pinyin.contains(normalized)
        }
    }

    private var sections: [(initial: String, cities: [CityOption])] {
        Dictionary(grouping: Self.cities, by: \.initial)
            .map { (initial: $0.key, cities: $0.value.sorted { $0.pinyin < $1.pinyin }) }
            .sorted { $0.initial < $1.initial }
    }

    private var popularCities: [CityOption] {
        popularCityNames.compactMap { name in
            Self.cities.first { $0.name == name }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section("当前城市") {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(ProfilePalette.systemBlue)
                            Text(selectedCityName)
                                .foregroundStyle(ProfilePalette.label)
                            Spacer()
                            Text("重新定位")
                                .foregroundStyle(ProfilePalette.systemBlue)
                        }
                    }
                }

                if searchText.isEmpty {
                    Section("热门城市") {
                        cityGrid(popularCities)
                    }

                    Section("字母索引") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 10)], spacing: 10) {
                            ForEach(sections.map(\.initial), id: \.self) { initial in
                                Button(initial) {
                                    withAnimation {
                                        proxy.scrollTo(initial, anchor: .top)
                                    }
                                }
                                .font(.body.weight(.medium))
                                .foregroundStyle(ProfilePalette.label)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    ForEach(sections, id: \.initial) { section in
                        Section {
                            ForEach(section.cities) { city in
                                cityRow(city)
                            }
                        } header: {
                            Text(section.initial)
                                .id(section.initial)
                        }
                    }
                } else {
                    Section("搜索结果") {
                        ForEach(filteredCities) { city in
                            cityRow(city)
                        }

                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           !filteredCities.contains(where: { $0.name == searchText }) {
                            Button {
                                Task {
                                    await geocodeSearchText()
                                }
                            } label: {
                                Label("使用“\(searchText)”", systemImage: "magnifyingglass.circle.fill")
                                    .lineLimit(1)
                            }
                            .disabled(isGeocoding)
                        }

                        if let geocodingMessage {
                            Text(geocodingMessage)
                                .font(.footnote)
                                .foregroundStyle(ProfilePalette.secondaryLabel)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaPadding(.trailing, searchText.isEmpty ? 22 : 0)
            .searchable(text: $searchText, prompt: "搜索城市或拼音")
            .overlay(alignment: .trailing) {
                if searchText.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(sections.map(\.initial), id: \.self) { initial in
                            Button(initial) {
                                proxy.scrollTo(initial, anchor: .top)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ProfilePalette.systemBlue)
                            .frame(width: 24, height: 15)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
        .navigationTitle("选择城市")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cityGrid(_ cities: [CityOption]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
            ForEach(cities) { city in
                Button(city.name) {
                    select(city)
                }
                .font(.subheadline)
                .foregroundStyle(ProfilePalette.label)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 4)
    }

    private func cityRow(_ city: CityOption) -> some View {
        Button {
            select(city)
        } label: {
            HStack {
                Text(city.name)
                    .foregroundStyle(ProfilePalette.label)
                Spacer()
                if city.name == selectedCityName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ProfilePalette.systemBlue)
                }
            }
        }
    }

    private func select(_ city: CityOption) {
        onSelect(city)
        dismiss()
    }

    @MainActor
    private func geocodeSearchText() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isGeocoding else { return }

        isGeocoding = true
        defer { isGeocoding = false }
        geocodingMessage = nil

        do {
            guard let placemark = try await CLGeocoder()
                .geocodeAddressString("\(query), 中国")
                .first,
                  let location = placemark.location else {
                geocodingMessage = "未找到该城市"
                return
            }
            let name = placemark.locality ?? placemark.administrativeArea ?? query
            select(CityOption(
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ))
        } catch {
            geocodingMessage = "城市搜索失败，请稍后重试"
        }
    }

    private static let cities: [CityOption] = [
        CityOption(name: "安庆", latitude: 30.54, longitude: 117.06),
        CityOption(name: "鞍山", latitude: 41.11, longitude: 122.99),
        CityOption(name: "北京", latitude: 39.90, longitude: 116.41),
        CityOption(name: "保定", latitude: 38.87, longitude: 115.46),
        CityOption(name: "包头", latitude: 40.66, longitude: 109.84),
        CityOption(name: "北海", latitude: 21.48, longitude: 109.12),
        CityOption(name: "蚌埠", latitude: 32.92, longitude: 117.39),
        CityOption(name: "成都", latitude: 30.57, longitude: 104.07),
        CityOption(name: "重庆", latitude: 29.56, longitude: 106.55),
        CityOption(name: "长沙", latitude: 28.23, longitude: 112.94),
        CityOption(name: "长春", latitude: 43.82, longitude: 125.32),
        CityOption(name: "常州", latitude: 31.81, longitude: 119.97),
        CityOption(name: "沧州", latitude: 38.30, longitude: 116.84),
        CityOption(name: "大连", latitude: 38.91, longitude: 121.61),
        CityOption(name: "东莞", latitude: 23.02, longitude: 113.75),
        CityOption(name: "大庆", latitude: 46.59, longitude: 125.10),
        CityOption(name: "德州", latitude: 37.44, longitude: 116.36),
        CityOption(name: "鄂尔多斯", latitude: 39.61, longitude: 109.78),
        CityOption(name: "福州", latitude: 26.07, longitude: 119.30),
        CityOption(name: "佛山", latitude: 23.02, longitude: 113.12),
        CityOption(name: "抚顺", latitude: 41.88, longitude: 123.96),
        CityOption(name: "广州", latitude: 23.13, longitude: 113.26),
        CityOption(name: "贵阳", latitude: 26.65, longitude: 106.63),
        CityOption(name: "桂林", latitude: 25.27, longitude: 110.29),
        CityOption(name: "赣州", latitude: 25.83, longitude: 114.93),
        CityOption(name: "杭州", latitude: 30.27, longitude: 120.15),
        CityOption(name: "哈尔滨", latitude: 45.80, longitude: 126.53),
        CityOption(name: "合肥", latitude: 31.82, longitude: 117.23),
        CityOption(name: "海口", latitude: 20.04, longitude: 110.20),
        CityOption(name: "呼和浩特", latitude: 40.84, longitude: 111.75),
        CityOption(name: "邯郸", latitude: 36.63, longitude: 114.54),
        CityOption(name: "惠州", latitude: 23.11, longitude: 114.42),
        CityOption(name: "济南", latitude: 36.65, longitude: 117.12),
        CityOption(name: "嘉兴", latitude: 30.75, longitude: 120.76),
        CityOption(name: "金华", latitude: 29.08, longitude: 119.65),
        CityOption(name: "吉林", latitude: 43.84, longitude: 126.55),
        CityOption(name: "江门", latitude: 22.58, longitude: 113.08),
        CityOption(name: "九江", latitude: 29.71, longitude: 116.00),
        CityOption(name: "昆明", latitude: 25.04, longitude: 102.71),
        CityOption(name: "开封", latitude: 34.80, longitude: 114.31),
        CityOption(name: "兰州", latitude: 36.06, longitude: 103.83),
        CityOption(name: "洛阳", latitude: 34.62, longitude: 112.45),
        CityOption(name: "临沂", latitude: 35.10, longitude: 118.36),
        CityOption(name: "柳州", latitude: 24.33, longitude: 109.42),
        CityOption(name: "拉萨", latitude: 29.65, longitude: 91.17),
        CityOption(name: "连云港", latitude: 34.60, longitude: 119.22),
        CityOption(name: "绵阳", latitude: 31.47, longitude: 104.68),
        CityOption(name: "南京", latitude: 32.06, longitude: 118.80),
        CityOption(name: "宁波", latitude: 29.87, longitude: 121.55),
        CityOption(name: "南昌", latitude: 28.68, longitude: 115.86),
        CityOption(name: "南宁", latitude: 22.82, longitude: 108.37),
        CityOption(name: "南通", latitude: 31.98, longitude: 120.89),
        CityOption(name: "莆田", latitude: 25.45, longitude: 119.01),
        CityOption(name: "平顶山", latitude: 33.74, longitude: 113.19),
        CityOption(name: "青岛", latitude: 36.07, longitude: 120.38),
        CityOption(name: "泉州", latitude: 24.87, longitude: 118.68),
        CityOption(name: "秦皇岛", latitude: 39.94, longitude: 119.60),
        CityOption(name: "曲靖", latitude: 25.49, longitude: 103.80),
        CityOption(name: "日照", latitude: 35.42, longitude: 119.53),
        CityOption(name: "上海", latitude: 31.23, longitude: 121.47),
        CityOption(name: "深圳", latitude: 22.54, longitude: 114.06),
        CityOption(name: "石家庄", latitude: 38.04, longitude: 114.51),
        CityOption(name: "苏州", latitude: 31.30, longitude: 120.58),
        CityOption(name: "沈阳", latitude: 41.80, longitude: 123.43),
        CityOption(name: "汕头", latitude: 23.35, longitude: 116.68),
        CityOption(name: "绍兴", latitude: 30.00, longitude: 120.58),
        CityOption(name: "三亚", latitude: 18.25, longitude: 109.51),
        CityOption(name: "天津", latitude: 39.09, longitude: 117.20),
        CityOption(name: "太原", latitude: 37.87, longitude: 112.55),
        CityOption(name: "唐山", latitude: 39.63, longitude: 118.18),
        CityOption(name: "台州", latitude: 28.66, longitude: 121.42),
        CityOption(name: "武汉", latitude: 30.59, longitude: 114.30),
        CityOption(name: "无锡", latitude: 31.49, longitude: 120.31),
        CityOption(name: "温州", latitude: 28.00, longitude: 120.70),
        CityOption(name: "乌鲁木齐", latitude: 43.83, longitude: 87.62),
        CityOption(name: "威海", latitude: 37.51, longitude: 122.12),
        CityOption(name: "潍坊", latitude: 36.71, longitude: 119.16),
        CityOption(name: "西安", latitude: 34.34, longitude: 108.94),
        CityOption(name: "厦门", latitude: 24.48, longitude: 118.09),
        CityOption(name: "徐州", latitude: 34.20, longitude: 117.28),
        CityOption(name: "西宁", latitude: 36.62, longitude: 101.78),
        CityOption(name: "湘潭", latitude: 27.83, longitude: 112.94),
        CityOption(name: "襄阳", latitude: 32.01, longitude: 112.12),
        CityOption(name: "银川", latitude: 38.49, longitude: 106.23),
        CityOption(name: "烟台", latitude: 37.46, longitude: 121.45),
        CityOption(name: "扬州", latitude: 32.39, longitude: 119.41),
        CityOption(name: "宜昌", latitude: 30.69, longitude: 111.29),
        CityOption(name: "义乌", latitude: 29.31, longitude: 120.08),
        CityOption(name: "郑州", latitude: 34.75, longitude: 113.62),
        CityOption(name: "珠海", latitude: 22.27, longitude: 113.58),
        CityOption(name: "中山", latitude: 22.52, longitude: 113.39),
        CityOption(name: "镇江", latitude: 32.19, longitude: 119.42),
        CityOption(name: "淄博", latitude: 36.81, longitude: 118.05),
        CityOption(name: "株洲", latitude: 27.83, longitude: 113.13)
    ]
}

private struct RecommendedShopRow: View {
    let shop: RecommendedShop
    var showsDisclosureIndicator = true

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

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ProfilePalette.tertiaryLabel)
                    .padding(.top, 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct AllRecommendedShopsView: View {
    let keyword: String
    let latitude: Double?
    let longitude: Double?

    @State private var shops: [RecommendedShop] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var nextPage = 1
    @State private var hasMoreServerPages = true
    @State private var bufferedFeedShops: [FeedShop] = []

    private let pageSize = 10

    private var hasMorePages: Bool {
        hasMoreServerPages || !bufferedFeedShops.isEmpty
    }

    var body: some View {
        Group {
            if shops.isEmpty && !isLoading {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        loadFailed ? "店铺加载失败" : "暂无店铺",
                        systemImage: loadFailed ? "wifi.exclamationmark" : "storefront",
                        description: Text(loadFailed ? "请重新加载" : "暂未找到符合条件的已审核店铺")
                    )

                    if loadFailed {
                        Button("重新加载") {
                            Task {
                                await loadShops(reset: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List(shops) { shop in
                    NavigationLink {
                        RecommendedShopDetailView(shop: shop)
                    } label: {
                        RecommendedShopRow(shop: shop, showsDisclosureIndicator: false)
                    }
                    .listRowInsets(EdgeInsets())
                    .onAppear {
                        guard shop.id == shops.last?.id else { return }
                        Task {
                            await loadShops(reset: false)
                        }
                    }

                    if shop.id == shops.last?.id, isLoading, !shops.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadShops(reset: true)
                }
            }
        }
        .overlay {
            if isLoading && shops.isEmpty {
                ProgressView("正在加载店铺")
            }
        }
        .navigationTitle(keyword.isEmpty ? "全部店铺" : "搜索结果")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard shops.isEmpty else { return }
            await loadShops(reset: true)
        }
    }

    @MainActor
    private func loadShops(reset: Bool) async {
        guard !isLoading, reset || hasMorePages else { return }

        isLoading = true
        defer { isLoading = false }

        if reset {
            nextPage = 1
            hasMoreServerPages = true
            bufferedFeedShops = []
            loadFailed = false
        }

        do {
            var page = nextPage
            var accumulated = bufferedFeedShops
            var pageHasMore = hasMoreServerPages
            var seenIDs = Set(accumulated.map(\.id))
            if !reset {
                seenIDs.formUnion(shops.compactMap { Int($0.id) })
            }
            var scannedPages = 0

            while accumulated.count < pageSize, pageHasMore, scannedPages < 20 {
                let result = try await ShopFeedAPIClient.fetchAllShops(
                    latitude: latitude,
                    longitude: longitude,
                    keyword: keyword,
                    page: page,
                    pageSize: pageSize
                )
                let uniqueItems = result.items.filter { seenIDs.insert($0.id).inserted }
                accumulated.append(contentsOf: uniqueItems)
                pageHasMore = result.hasMore
                if !result.items.isEmpty && uniqueItems.isEmpty {
                    pageHasMore = false
                }
                page += 1
                scannedPages += 1
            }

            let batch = Array(accumulated.prefix(pageSize))
            bufferedFeedShops = Array(accumulated.dropFirst(batch.count))

            let mapped = batch.enumerated().map { index, shop in
                let rank = (reset ? 0 : shops.count) + index + 1
                return shop.withRank(rank).recommendedShop(fallbackRank: rank)
            }
            let existingIDs = reset ? Set<String>() : Set(shops.map(\.id))
            let newShops = mapped.filter { !existingIDs.contains($0.id) }
            shops = reset ? newShops : shops + newShops
            nextPage = page
            hasMoreServerPages = pageHasMore
            if newShops.isEmpty && bufferedFeedShops.isEmpty {
                hasMoreServerPages = false
            }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct RecommendedShopDetailView: View {
    let shop: RecommendedShop

    var body: some View {
        List {
            Section {
                ShopPhoto(path: shop.imageURL, symbol: shop.symbol)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("店铺信息") {
                detailRow("名称", shop.name)
                detailRow("分类", shop.category)
                detailRow("可信分", shop.trustScore)
                detailRow("评分", shop.rating)
                detailRow("评价", shop.reviews)
            }

            Section("服务与位置") {
                detailRow("服务", shop.service)
                detailRow("详情", shop.details)
                detailRow("地址", shop.address)
                detailRow("距离", shop.distance)
                detailRow("电话", shop.phone)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value.isEmpty ? "暂无" : value)
                .foregroundStyle(ProfilePalette.secondaryLabel)
                .multilineTextAlignment(.trailing)
        }
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

private struct StreetPageState {
    var records: [StreetReviewRecord] = []
    var nextPage = 1
    var hasMoreServerRecords = true
    var hasMoreLocalRecords = false
    var loadedServerKeys: Set<String> = []

    var hasMore: Bool {
        hasMoreServerRecords || hasMoreLocalRecords
    }
}

private struct StreetVerifyTaskView: View {
    @State private var isShowingCapture = false
    @State private var selectedStatus: StreetRecordStatus = .pending
    @State private var isReloading = false
    @State private var hasLoadedRecords = false
    @State private var pageStates: [StreetRecordStatus: StreetPageState] = [:]
    @State private var localPendingRecords: [StreetReviewRecord] = []
    @State private var loadErrorMessage: String?
    @State private var loadingStatus: StreetRecordStatus?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShopRecord.timestamp, ascending: false)],
        animation: .default
    )
    private var records: FetchedResults<ShopRecord>

    private var selectedRecords: [StreetReviewRecord] {
        pageStates[selectedStatus]?.records ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ProfilePalette.groupedBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("扫街")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(ProfilePalette.label)

                        Picker("记录状态", selection: $selectedStatus) {
                            ForEach(StreetRecordStatus.allCases) { status in
                                Text("\(status.title) \(count(for: status))").tag(status)
                            }
                        }
                        .pickerStyle(.segmented)

                        if let loadErrorMessage {
                            Text(loadErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(ProfilePalette.secondaryLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(ProfilePalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            StreetRecordList(status: selectedStatus, records: selectedRecords)

                            if !isReloading, pageStates[selectedStatus]?.hasMore == true {
                                ZStack {
                                    Color.clear
                                        .frame(height: 1)

                                    if loadingStatus == selectedStatus {
                                        ProgressView("正在加载更多")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: loadingStatus == selectedStatus ? 44 : 1)
                                .id("\(selectedStatus.rawValue)-\(pageStates[selectedStatus]?.nextPage ?? 1)")
                                .onAppear {
                                    Task {
                                        await loadMoreRecords(for: selectedStatus)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 96)
                    }
                    .refreshable {
                        await reloadStreetRecords()
                    }
                }

                if isReloading {
                    TopReloadIndicator()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isReloading)
            .safeAreaInset(edge: .bottom) {
                Button {
                    isShowingCapture = true
                } label: {
                    Label("开始扫街录入", systemImage: "camera.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ProfilePalette.systemBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 16)
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
            .onReceive(NotificationCenter.default.publisher(for: .streetTabDoubleTapped)) { _ in
                Task {
                    await reloadStreetRecords()
                }
            }
            .task {
                guard !hasLoadedRecords else { return }
                hasLoadedRecords = true
                await reloadStreetRecords()
            }
        }
    }

    @MainActor
    private func reloadStreetRecords() async {
        guard !isReloading, loadingStatus == nil else { return }

        isReloading = true
        defer { isReloading = false }

        pageStates = [:]
        localPendingRecords = Array(records).map(localReviewRecord)
        loadErrorMessage = nil

        for status in [StreetRecordStatus.approved, .rejected, .pending] {
            await loadMoreRecords(for: status, minimumCount: 10)
        }
    }

    @MainActor
    private func loadMoreRecords(for status: StreetRecordStatus, minimumCount: Int? = nil) async {
        var state = pageStates[status] ?? StreetPageState()
        guard loadingStatus == nil, state.hasMore else { return }

        let targetCount = minimumCount ?? (state.records.count + 10)
        loadingStatus = status
        defer { loadingStatus = nil }

        do {
            var scannedPages = 0

            while state.records.count < targetCount,
                  state.hasMoreServerRecords,
                  scannedPages < 20 {
                let result = try await ShopFeedAPIClient.fetchStreetRecords(
                    reviewState: status.reviewState,
                    page: state.nextPage,
                    pageSize: 10
                )
                var loadedKeys = state.loadedServerKeys
                let newSourceRecords = result.items.filter { record in
                    loadedKeys.insert(streetRecordKey(record)).inserted
                }
                state.loadedServerKeys = loadedKeys
                let newRecords = newSourceRecords.filter { $0.reviewState == status.reviewState }
                state.records = mergeStreetRecords(state.records, with: newRecords)
                state.nextPage = result.page + 1
                state.hasMoreServerRecords = result.hasMore
                if !result.items.isEmpty && newSourceRecords.isEmpty {
                    state.hasMoreServerRecords = false
                }
                scannedPages += 1
            }

            if status == .pending, state.records.count < targetCount {
                appendLocalPendingRecords(to: &state, targetCount: targetCount)
            } else if status == .pending {
                updateLocalPendingAvailability(in: &state)
            }

            pageStates[status] = state
            loadErrorMessage = nil
        } catch {
            if status == .pending {
                appendLocalPendingRecords(to: &state, targetCount: targetCount)
            }
            pageStates[status] = state
            loadErrorMessage = state.nextPage == 1
                ? "接口加载失败，当前显示本机待审核记录"
                : "更多记录加载失败，请稍后重试"
        }
    }

    private func mergeStreetRecords(
        _ existingRecords: [StreetReviewRecord],
        with newRecords: [StreetReviewRecord]
    ) -> [StreetReviewRecord] {
        var recordsByKey: [String: StreetReviewRecord] = [:]
        for record in existingRecords {
            recordsByKey[streetRecordKey(record)] = record
        }
        for record in newRecords {
            recordsByKey[streetRecordKey(record)] = record
        }
        return recordsByKey.values.sorted {
            ($0.capturedAt ?? .distantPast) > ($1.capturedAt ?? .distantPast)
        }
    }

    private func appendLocalPendingRecords(to state: inout StreetPageState, targetCount: Int) {
        let serverKeys = Set(pageStates.values.flatMap { $0.loadedServerKeys }).union(state.loadedServerKeys)
        let existingKeys = Set(state.records.map(streetRecordKey))
        let availableRecords = localPendingRecords.filter { record in
            let key = streetRecordKey(record)
            return !serverKeys.contains(key) && !existingKeys.contains(key)
        }
        let neededCount = max(0, targetCount - state.records.count)
        state.records = mergeStreetRecords(state.records, with: Array(availableRecords.prefix(neededCount)))
        state.hasMoreLocalRecords = availableRecords.count > neededCount
    }

    private func updateLocalPendingAvailability(in state: inout StreetPageState) {
        let serverKeys = Set(pageStates.values.flatMap { $0.loadedServerKeys }).union(state.loadedServerKeys)
        let existingKeys = Set(state.records.map(streetRecordKey))
        state.hasMoreLocalRecords = localPendingRecords.contains { record in
            let key = streetRecordKey(record)
            return !serverKeys.contains(key) && !existingKeys.contains(key)
        }
    }

    private func streetRecordKey(_ record: StreetReviewRecord) -> String {
        if !record.clientUUID.isEmpty {
            return "uuid:\(record.clientUUID.lowercased())"
        }
        return "id:\(record.id)"
    }

    private func localReviewRecord(_ record: ShopRecord) -> StreetReviewRecord {
        let clientUUID = record.id?.uuidString ?? ""
        return StreetReviewRecord(
            id: clientUUID.isEmpty ? record.objectID.uriRepresentation().absoluteString : clientUUID,
            clientUUID: clientUUID,
            shopName: record.shopName ?? "",
            serviceContent: record.serviceContent ?? "",
            phoneNumber: record.phoneNumber ?? "",
            fullText: record.fullText ?? "",
            imageURL: record.imagePath ?? "",
            latitude: record.latitude,
            longitude: record.longitude,
            capturedAt: record.timestamp,
            reviewState: .pending
        )
    }

    private func count(for status: StreetRecordStatus) -> Int {
        pageStates[status]?.records.count ?? 0
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
    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        NavigationStack {
            ZStack {
                ProfilePalette.groupedBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if let account = authSession.account {
                            balanceOverview(account)
                            withdrawalHistoryLink
                        } else {
                            ProgressView("正在加载账户")
                                .font(.subheadline)
                                .foregroundStyle(ProfilePalette.secondaryLabel)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await refreshAccount()
                }
            }
            .navigationBarHidden(true)
            .task {
                await refreshAccount()
            }
        }
    }

    private func refreshAccount() async {
        await authSession.refreshAccount()
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("我的")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ProfilePalette.label)

            Spacer()

            NavigationLink {
                ProfileSettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(ProfilePalette.systemBlue)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("设置")
        }
    }

    private func balanceOverview(_ account: UserAccountSummary) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("可提现金币")
                        .font(.footnote)
                        .foregroundStyle(ProfilePalette.secondaryLabel)

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(account.coins)")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(ProfilePalette.label)

                        Text("金币")
                            .font(.subheadline)
                            .foregroundStyle(ProfilePalette.secondaryLabel)
                    }
                }

                Spacer()

                NavigationLink {
                    WithdrawView()
                } label: {
                    Text("提现")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(ProfilePalette.systemBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(16)

            Rectangle()
                .fill(ProfilePalette.separator)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ProfileMetric(title: "历史总收入", value: incomeText(account.totalIncome))

                ProfileMetricDivider()

                ProfileMetric(title: "本月收入", value: incomeText(account.currentMonthIncome))

                ProfileMetricDivider()

                ProfileMetric(title: "上月收入", value: incomeText(account.lastMonthIncome))
            }
            .padding(.vertical, 14)
        }
        .background(ProfilePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func incomeText(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }

    private var withdrawalHistoryLink: some View {
        NavigationLink {
            WithdrawalHistoryView()
        } label: {
            ProfileActionRow(
                title: "提现明细",
                value: nil,
                symbol: "list.bullet.rectangle.fill",
                tint: ProfilePalette.systemGreen
            )
        }
        .buttonStyle(.plain)
        .background(ProfilePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProfileMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ProfilePalette.secondaryLabel)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ProfilePalette.label)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct ProfileMetricDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProfilePalette.separator)
            .frame(width: 0.5, height: 34)
    }
}

private struct ProfileActionRow: View {
    let title: String
    let value: String?
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(.body)
                .foregroundStyle(ProfilePalette.label)

            Spacer(minLength: 10)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(ProfilePalette.secondaryLabel)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ProfilePalette.tertiaryLabel)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct ProfileRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProfilePalette.separator)
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var isWorking = false

    var body: some View {
        ZStack {
            ProfilePalette.groupedBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("设置")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(ProfilePalette.label)

                    if let account = authSession.account {
                        settingsMenu(account)
                    }

                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsMenu(_ account: UserAccountSummary) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                ProfileInformationView(
                    title: "个人信息",
                    items: [
                        ProfileInformationItem(title: "名称", value: account.profile.displayName),
                        ProfileInformationItem(title: "身份", value: account.profile.roleName),
                        ProfileInformationItem(title: "所属站点", value: account.profile.locationName)
                    ]
                )
            } label: {
                ProfileActionRow(
                    title: "个人信息",
                    value: nil,
                    symbol: "person.fill",
                    tint: ProfilePalette.systemBlue
                )
            }
            .buttonStyle(.plain)

            ProfileRowDivider()

            NavigationLink {
                PaymentInformationView()
            } label: {
                ProfileActionRow(
                    title: "收款信息",
                    value: paymentStatus(account),
                    symbol: "creditcard.fill",
                    tint: ProfilePalette.systemGreen
                )
            }
            .buttonStyle(.plain)

            ProfileRowDivider()

            NavigationLink {
                ProfileInformationView(
                    title: "账号信息",
                    items: [
                        ProfileInformationItem(title: "账号", value: account.profile.accountLine),
                        ProfileInformationItem(title: "同步状态", value: account.profile.syncStatus)
                    ]
                )
            } label: {
                ProfileActionRow(
                    title: "账号信息",
                    value: nil,
                    symbol: "person.text.rectangle.fill",
                    tint: ProfilePalette.systemOrange
                )
            }
            .buttonStyle(.plain)
        }
        .background(ProfilePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func paymentStatus(_ account: UserAccountSummary) -> String {
        let value = account.alipayAccount
        guard !value.isEmpty else { return "未设置" }
        guard value.count > 7 else { return "已设置" }
        return "\(value.prefix(3))****\(value.suffix(3))"
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            Task {
                await logout()
            }
        } label: {
            Text("退出登录")
                .font(.body)
                .foregroundStyle(ProfilePalette.systemRed)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(ProfilePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.55 : 1)
    }

    private func logout() async {
        isWorking = true
        defer { isWorking = false }

        await authSession.logout()
    }
}

private struct PaymentInformationView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var alipayAccount = ""
    @State private var alipayName = ""
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("支付宝账号", text: $alipayAccount)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            TextField("收款姓名", text: $alipayName)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await saveAlipay()
                }
            } label: {
                Text(isWorking ? "保存中..." : "保存支付宝")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ProfilePalette.systemBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .disabled(isWorking || alipayAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || alipayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(ProfilePalette.secondaryLabel)
            }
        }
        .padding(16)
        .background(ProfilePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
        .background(ProfilePalette.groupedBackground)
        .navigationTitle("收款信息")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            alipayAccount = authSession.account?.alipayAccount ?? ""
            alipayName = authSession.account?.alipayName ?? ""
        }
    }

    private func saveAlipay() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let summary = try await UserAPIClient.saveAlipay(
                account: alipayAccount.trimmingCharacters(in: .whitespacesAndNewlines),
                name: alipayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            authSession.setAccount(summary)
            alipayAccount = summary.alipayAccount
            alipayName = summary.alipayName
            statusMessage = "支付宝已保存"
        } catch {
            statusMessage = "支付宝保存失败"
        }
    }

}

private struct ProfileInformationItem: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct ProfileInformationView: View {
    let title: String
    let items: [ProfileInformationItem]

    var body: some View {
        List(items) { item in
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(item.title)
                    .foregroundStyle(ProfilePalette.label)

                Spacer(minLength: 16)

                Text(item.value)
                    .foregroundStyle(ProfilePalette.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
            .font(.body)
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WithdrawalHistoryView: View {
    var body: some View {
        ContentUnavailableView(
            "暂无提现明细",
            systemImage: "list.bullet.rectangle",
            description: Text("提交提现申请后，可在这里查看处理记录")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ProfilePalette.groupedBackground)
        .navigationTitle("提现明细")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WithdrawView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var withdrawCoins = ""
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("金币提现")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(DesignTokens.ink)

                    if let account = authSession.account {
                        withdrawCard(account)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.white.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func withdrawCard(_ account: UserAccountSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("\(account.coins)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.ink)
                Text("可提现金币")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            ProfileInfoRow(
                title: "收款支付宝",
                value: account.alipayAccount.isEmpty ? "请先到设置中配置" : account.alipayAccount,
                symbol: "creditcard.fill"
            )

            if account.alipayAccount.isEmpty || account.alipayName.isEmpty {
                NavigationLink {
                    PaymentInformationView()
                } label: {
                    Text("去配置收款支付宝")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DesignTokens.emerald)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(DesignTokens.softEmerald)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            TextField("提现金币数量", text: $withdrawCoins)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await submitWithdraw(account: account)
                }
            } label: {
                Text(isWorking ? "提交中..." : "提交提现申请")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canSubmitWithdraw(account: account) ? DesignTokens.emerald : Color.gray.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isWorking || !canSubmitWithdraw(account: account))
        }
        .profilePanelStyle()
    }

    private func submitWithdraw(account: UserAccountSummary) async {
        guard let coins = Int(withdrawCoins) else {
            statusMessage = "请输入正确的金币数量"
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await UserAPIClient.submitWithdraw(
                coins: coins,
                alipayAccount: account.alipayAccount,
                alipayName: account.alipayName
            )
            withdrawCoins = ""
            statusMessage = "提现申请已提交"
            await authSession.refreshAccount()
        } catch {
            statusMessage = "提现申请提交失败"
        }
    }

    private func canSubmitWithdraw(account: UserAccountSummary) -> Bool {
        guard let coins = Int(withdrawCoins), coins > 0, coins <= account.coins else {
            return false
        }

        return !account.alipayAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !account.alipayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension View {
    func profilePanelStyle() -> some View {
        self
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
    let status: StreetRecordStatus
    let records: [StreetReviewRecord]

    var body: some View {
        StreetRecordStatusList(status: status, records: records)
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

    var reviewState: StreetReviewState {
        switch self {
        case .pending:
            return .pending
        case .approved:
            return .approved
        case .rejected:
            return .rejected
        }
    }
}

private struct StreetRecordStatusList: View {
    let status: StreetRecordStatus
    let records: [StreetReviewRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无\(status.title)记录",
                    systemImage: "tray",
                    description: Text("双击底部“扫街”可重新加载")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(ProfilePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            StreetReviewRecordDetailView(record: record)
                        } label: {
                            StreetRecordRow(record: record)
                        }
                        .buttonStyle(.plain)

                        if index < records.count - 1 {
                            ProfileRowDivider()
                        }
                    }
                }
                .background(ProfilePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct StreetRecordRow: View {
    let record: StreetReviewRecord

    var body: some View {
        HStack(spacing: 12) {
            ShopPhoto(path: record.imageURL, symbol: "storefront.fill")
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ProfilePalette.label)
                        .lineLimit(1)

                    Spacer()

                    Text(record.reviewState.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(record.reviewState.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(record.reviewState.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ProfilePalette.secondaryLabel)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(phoneText, systemImage: "phone.fill")
                    Label(locationText, systemImage: "location.fill")
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(ProfilePalette.secondaryLabel)

                if let timestamp = record.capturedAt {
                    Text(ShopDateFormatter.dateTime(timestamp))
                        .font(.caption2)
                        .foregroundStyle(ProfilePalette.secondaryLabel)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ProfilePalette.tertiaryLabel)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var title: String {
        if !record.shopName.isEmpty {
            return record.shopName
        }
        return record.phoneNumber.isEmpty ? "未命名店铺" : record.phoneNumber
    }

    private var subtitle: String {
        if !record.serviceContent.isEmpty {
            return record.serviceContent
        }

        let text = record.fullText.replacingOccurrences(of: "\n", with: " ")
        if text.isEmpty {
            return "服务内容待完善"
        }
        return String(text.prefix(36))
    }

    private var phoneText: String {
        record.phoneNumber.isEmpty ? "无号码" : record.phoneNumber
    }

    private var locationText: String {
        if record.latitude == 0 && record.longitude == 0 {
            return "未定位"
        }
        return "已记录位置"
    }
}

private extension StreetReviewState {
    var color: Color {
        switch self {
        case .pending:
            return ProfilePalette.systemOrange
        case .approved:
            return ProfilePalette.systemGreen
        case .rejected:
            return ProfilePalette.systemRed
        }
    }
}

private struct StreetReviewRecordDetailView: View {
    let record: StreetReviewRecord

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ShopPhoto(path: record.imageURL, symbol: "storefront.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 0) {
                    detailRow("审核状态", record.reviewState.title, valueColor: record.reviewState.color)
                    ProfileRowDivider()
                    detailRow("名称", record.shopName.isEmpty ? "未整理出名称" : record.shopName)
                    ProfileRowDivider()
                    detailRow("服务内容", record.serviceContent.isEmpty ? "未整理出服务内容" : record.serviceContent)
                    ProfileRowDivider()
                    detailRow("电话", record.phoneNumber.isEmpty ? "无号码" : record.phoneNumber)
                    ProfileRowDivider()
                    detailRow("位置", locationText)

                    if let capturedAt = record.capturedAt {
                        ProfileRowDivider()
                        detailRow("采集时间", ShopDateFormatter.dateTime(capturedAt))
                    }
                }
                .background(ProfilePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
        }
        .background(ProfilePalette.groupedBackground)
        .navigationTitle("扫街详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ title: String, _ value: String, valueColor: Color = ProfilePalette.secondaryLabel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .foregroundStyle(ProfilePalette.label)

            Spacer(minLength: 16)

            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(14)
    }

    private var locationText: String {
        if record.latitude == 0 && record.longitude == 0 {
            return "未定位"
        }
        return String(format: "%.6f, %.6f", record.latitude, record.longitude)
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

private enum ProfilePalette {
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
    static let systemBlue = Color(uiColor: .systemBlue)
    static let systemGreen = Color(uiColor: .systemGreen)
    static let systemOrange = Color(uiColor: .systemOrange)
    static let systemRed = Color(uiColor: .systemRed)
}

private enum DesignTokens {
    static let background = Color(red: 0.975, green: 0.968, blue: 0.944)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.075)
    static let secondaryText = Color(red: 0.39, green: 0.42, blue: 0.48)
    static let emerald = Color(red: 0.0, green: 0.52, blue: 0.37)
    static let softEmerald = Color(red: 0.9, green: 0.965, blue: 0.94)
    static let line = Color.black.opacity(0.07)
}
