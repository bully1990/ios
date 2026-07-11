import CoreLocation
import Foundation
import MapKit
import SwiftUI
import UIKit

struct AdministrativeDivision: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let children: [AdministrativeDivision]

    var id: String { code }

    private enum CodingKeys: String, CodingKey {
        case code = "c"
        case name = "n"
        case children = "ch"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringCode = try? container.decode(String.self, forKey: .code) {
            code = stringCode
        } else {
            code = String(try container.decode(Int.self, forKey: .code))
        }
        name = try container.decode(String.self, forKey: .name)
        children = try container.decodeIfPresent([AdministrativeDivision].self, forKey: .children) ?? []
    }

    init(code: String, name: String, children: [AdministrativeDivision]) {
        self.code = code
        self.name = name
        self.children = children
    }
}

struct AdministrativeDivisionStore {
    let provinces: [AdministrativeDivision]

    static let shared = AdministrativeDivisionStore()

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "pca", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([AdministrativeDivision].self, from: data) else {
            provinces = []
            return
        }
        provinces = decoded
    }

    init(data: Data) throws {
        provinces = try JSONDecoder().decode([AdministrativeDivision].self, from: data)
    }

    func cities(in province: AdministrativeDivision) -> [AdministrativeDivision] {
        guard let first = province.children.first else { return [] }
        if first.children.isEmpty {
            return [AdministrativeDivision(code: province.code, name: province.name, children: province.children)]
        }
        return province.children
    }

    func selection(
        provinceName: String?,
        cityName: String?,
        districtName: String?,
        requireDistrictMatch: Bool = false
    ) -> (AdministrativeDivision, AdministrativeDivision, AdministrativeDivision)? {
        guard let province = bestMatch(in: provinces, name: provinceName) else { return nil }
        let cities = cities(in: province)
        guard let city = bestMatch(in: cities, name: cityName) ?? cities.first else { return nil }
        let matchedDistrict = bestMatch(in: city.children, name: districtName)
        guard let district = matchedDistrict ?? (requireDistrictMatch ? nil : city.children.first) else { return nil }
        return (province, city, district)
    }

    func selection(cityName: String, districtName: String? = nil) -> (AdministrativeDivision, AdministrativeDivision, AdministrativeDivision)? {
        for province in provinces {
            let cities = cities(in: province)
            if let city = bestMatch(in: cities, name: cityName),
               let district = bestMatch(in: city.children, name: districtName) ?? city.children.first {
                return (province, city, district)
            }
        }
        return nil
    }

    private func bestMatch(in values: [AdministrativeDivision], name: String?) -> AdministrativeDivision? {
        guard let name, !name.isEmpty else { return nil }
        let target = Self.normalized(name)
        return values.first { Self.normalized($0.name) == target }
            ?? values.first { target.contains(Self.normalized($0.name)) || Self.normalized($0.name).contains(target) }
    }

    private static func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "特别行政区", with: "")
            .replacingOccurrences(of: "维吾尔自治区", with: "")
            .replacingOccurrences(of: "壮族自治区", with: "")
            .replacingOccurrences(of: "回族自治区", with: "")
            .replacingOccurrences(of: "自治区", with: "")
            .replacingOccurrences(of: "自治州", with: "")
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "区", with: "")
            .replacingOccurrences(of: "县", with: "")
    }
}

struct LinkedCitySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationProvider: LocationProvider

    let onSelect: (CitySelectionResult) -> Void

    private let store = AdministrativeDivisionStore.shared

    @State private var province: AdministrativeDivision
    @State private var city: AdministrativeDivision
    @State private var district: AdministrativeDivision
    @State private var mapPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var actualCoordinate: CLLocationCoordinate2D?
    @State private var actualLocationText: String
    @State private var selectionIsActualLocation = false
    @State private var selectionIsMapCoordinate = false
    @State private var isLocating = false
    @State private var locationMessage: String?
    @State private var geocodeRequestID = UUID()
    @State private var mapLookupRequestID = UUID()
    @State private var relocationRequestID = UUID()
    @State private var ignoreMapChangesUntil: Date
    @State private var mapSelectionMessage: String?
    @State private var isShowingLocationPermissionAlert = false

    init(
        selectedCityName: String,
        initialCurrentCity: String,
        initialCurrentAddress: String,
        onSelect: @escaping (CitySelectionResult) -> Void
    ) {
        self.onSelect = onSelect

        let store = AdministrativeDivisionStore.shared
        let fallbackProvince = store.provinces.first { $0.name.contains("河北") } ?? store.provinces.first!
        let fallbackCities = store.cities(in: fallbackProvince)
        let fallbackCity = fallbackCities.first { $0.name.contains("石家庄") } ?? fallbackCities.first!
        let fallbackDistrict = fallbackCity.children.first { $0.name == "长安区" } ?? fallbackCity.children.first!
        let initial = store.selection(cityName: selectedCityName, districtName: initialCurrentAddress)
            ?? (fallbackProvince, fallbackCity, fallbackDistrict)
        let coordinate = CLLocationCoordinate2D(latitude: 38.0428, longitude: 114.5149)

        _province = State(initialValue: initial.0)
        _city = State(initialValue: initial.1)
        _district = State(initialValue: initial.2)
        _selectedCoordinate = State(initialValue: coordinate)
        _mapPosition = State(initialValue: .region(Self.region(center: coordinate)))
        _actualLocationText = State(initialValue: initialCurrentAddress.isEmpty ? "尚未获取实际位置" : initialCurrentAddress)
        _ignoreMapChangesUntil = State(initialValue: Date().addingTimeInterval(1))
    }

    private var availableProvinces: [AdministrativeDivision] { store.provinces.filter { !$0.children.isEmpty } }
    private var cities: [AdministrativeDivision] { store.cities(in: province) }
    private var districts: [AdministrativeDivision] { city.children.filter { $0.name != "市辖区" } }
    private var selectionQuery: String { "\(province.name) \(city.name) \(district.name)" }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            locationBand
            selectors
            confirmButton
        }
        .background(Color(red: 0.975, green: 0.968, blue: 0.944).ignoresSafeArea())
        .navigationTitle("选择城市")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectionQuery) { await updateMapForSelection() }
        .alert("定位权限未开启", isPresented: $isShowingLocationPermissionAlert) {
            if locationProvider.authorizationStatus == .denied {
                Button("去设置") { openLocationSettings() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("开启定位后可重新获取当前实际位置，也可以继续手动选择省市区。")
        }
    }

    private var mapSection: some View {
        Map(position: $mapPosition) {
            if let actualCoordinate {
                Marker("我的位置", systemImage: "location.fill", coordinate: actualCoordinate)
                    .tint(.blue)
            }
        }
        .mapControls { MapCompass() }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard Date() >= ignoreMapChangesUntil else { return }
            let coordinate = context.region.center
            selectedCoordinate = coordinate
            selectionIsActualLocation = false
            selectionIsMapCoordinate = true
            Task { await updateSelectionForMapCenter(coordinate) }
        }
        .frame(height: 300)
        .overlay {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Self.emerald)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                .offset(y: -17)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            Text(mapSelectionMessage ?? "拖动地图选择位置")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { Task { await relocate() } } label: {
                Image(systemName: "location.fill")
                    .font(.headline)
                    .foregroundStyle(Self.emerald)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
            .disabled(isLocating)
            .padding(14)
            .accessibilityLabel("重新定位当前实际位置")
        }
    }

    private var locationBand: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle.fill")
                .font(.title3)
                .foregroundStyle(Self.emerald)

            VStack(alignment: .leading, spacing: 3) {
                Text("当前实际位置").font(.subheadline.weight(.semibold))
                Text(locationMessage ?? actualLocationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isLocating {
                ProgressView()
            } else {
                Button("重新定位") { Task { await relocate() } }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var selectors: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                columnTitle("省份")
                columnTitle("城市")
                columnTitle("区县")
            }
            .frame(height: 42)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                divisionColumn(availableProvinces, selection: province) { newProvince in
                    selectionIsActualLocation = false
                    selectionIsMapCoordinate = false
                    province = newProvince
                    guard let firstCity = store.cities(in: newProvince).first,
                          let firstDistrict = firstCity.children.first(where: { $0.name != "市辖区" }) ?? firstCity.children.first else { return }
                    city = firstCity
                    district = firstDistrict
                }
                Divider()
                divisionColumn(cities, selection: city) { newCity in
                    selectionIsActualLocation = false
                    selectionIsMapCoordinate = false
                    city = newCity
                    guard let firstDistrict = newCity.children.first(where: { $0.name != "市辖区" }) ?? newCity.children.first else { return }
                    district = firstDistrict
                }
                Divider()
                divisionColumn(districts, selection: district) {
                    selectionIsActualLocation = false
                    selectionIsMapCoordinate = false
                    district = $0
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(.background)
    }

    private func columnTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func divisionColumn(
        _ values: [AdministrativeDivision],
        selection: AdministrativeDivision,
        onSelect: @escaping (AdministrativeDivision) -> Void
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values) { value in
                        Button { onSelect(value) } label: {
                            Text(value.name)
                                .font(.subheadline.weight(value == selection ? .semibold : .regular))
                                .foregroundStyle(value == selection ? Self.emerald : .primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 46)
                                .padding(.horizontal, 4)
                                .background(value == selection ? Self.softEmerald : .clear)
                        }
                        .buttonStyle(.plain)
                        .id(value.id)
                    }
                }
            }
            .onAppear { proxy.scrollTo(selection.id, anchor: .center) }
            .onChange(of: selection.id) { _, id in
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var confirmButton: some View {
        Button {
            let option = CityOption(
                name: displayCityName,
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                address: district.name
            )
            onSelect(selectionIsActualLocation ? .current(option) : .manual(option))
            dismiss()
        } label: {
            Text("确认切换")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Self.emerald)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
        .background(.background)
    }

    private var displayCityName: String { city.code == province.code ? province.name : city.name }

    @MainActor
    private func updateMapForSelection() async {
        guard !selectionIsActualLocation, !selectionIsMapCoordinate else { return }
        let requestID = UUID()
        geocodeRequestID = requestID
        try? await Task.sleep(for: .milliseconds(300))
        guard requestID == geocodeRequestID,
              let placemark = try? await CLGeocoder().geocodeAddressString("\(selectionQuery), 中国").first,
              let coordinate = placemark.location?.coordinate,
              requestID == geocodeRequestID else { return }

        selectedCoordinate = coordinate
        withAnimation(.easeInOut(duration: 0.35)) {
            moveMap(to: coordinate)
        }
    }

    @MainActor
    private func updateSelectionForMapCenter(_ coordinate: CLLocationCoordinate2D) async {
        let requestID = UUID()
        mapLookupRequestID = requestID
        mapSelectionMessage = "正在识别地图位置"

        guard let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            .first,
              requestID == mapLookupRequestID else {
            if requestID == mapLookupRequestID { mapSelectionMessage = "无法识别地图位置" }
            return
        }

        let districtName = placemark.subLocality ?? placemark.subAdministrativeArea
        guard let matched = store.selection(
            provinceName: placemark.administrativeArea,
            cityName: placemark.locality ?? placemark.administrativeArea,
            districtName: districtName,
            requireDistrictMatch: true
        ), requestID == mapLookupRequestID else {
            mapSelectionMessage = "当前位置不在可选行政区内"
            return
        }

        province = matched.0
        city = matched.1
        district = matched.2
        selectionIsMapCoordinate = true
        mapSelectionMessage = "已选择 \(matched.2.name)"
    }

    @MainActor
    private func relocate() async {
        guard !isLocating else { return }
        locationProvider.requestWhenInUseAuthorization()
        if locationProvider.authorizationStatus == .notDetermined {
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                if locationProvider.authorizationStatus != .notDetermined { break }
            }
        }

        guard locationProvider.authorizationStatus == .authorizedAlways
                || locationProvider.authorizationStatus == .authorizedWhenInUse else {
            isShowingLocationPermissionAlert = true
            return
        }

        isLocating = true
        locationMessage = "正在获取当前位置"
        defer { isLocating = false }

        let requestID = UUID()
        relocationRequestID = requestID
        let recentLocation = locationProvider.recentLocation(maxAge: 60)
        async let freshLocation = locationProvider.freshLocation(
            timeout: 6,
            desiredAccuracy: kCLLocationAccuracyHundredMeters
        )

        if let recentLocation {
            actualCoordinate = recentLocation.coordinate
            moveMap(to: recentLocation.coordinate)
            locationMessage = "正在更新定位精度"
            await applyLocatedPosition(recentLocation, requestID: requestID)
        }

        guard requestID == relocationRequestID else { return }
        guard let location = await freshLocation else {
            if recentLocation == nil {
                locationMessage = "定位失败，请重试"
            } else {
                locationMessage = nil
            }
            return
        }

        if let recentLocation,
           location.timestamp == recentLocation.timestamp,
           location.coordinate.latitude == recentLocation.coordinate.latitude,
           location.coordinate.longitude == recentLocation.coordinate.longitude {
            locationMessage = nil
            return
        }

        await applyLocatedPosition(location, requestID: requestID)
    }

    @MainActor
    private func applyLocatedPosition(_ location: CLLocation, requestID: UUID) async {
        guard requestID == relocationRequestID else { return }

        actualCoordinate = location.coordinate
        moveMap(to: location.coordinate)

        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
              requestID == relocationRequestID else {
            actualLocationText = "已获取坐标，暂时无法识别行政区"
            locationMessage = nil
            return
        }

        let provinceName = placemark.administrativeArea
        let cityName = placemark.locality ?? placemark.administrativeArea
        let districtName = placemark.subLocality ?? placemark.subAdministrativeArea
        actualLocationText = [provinceName, cityName, districtName, placemark.thoroughfare]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        locationMessage = nil

        if let matched = store.selection(
            provinceName: provinceName,
            cityName: cityName,
            districtName: districtName,
            requireDistrictMatch: true
        ) {
            province = matched.0
            city = matched.1
            district = matched.2
            selectedCoordinate = location.coordinate
            selectionIsActualLocation = true
            selectionIsMapCoordinate = false
        }
    }

    private func moveMap(to coordinate: CLLocationCoordinate2D) {
        ignoreMapChangesUntil = Date().addingTimeInterval(0.8)
        mapPosition = .region(Self.region(center: coordinate))
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static let emerald = Color(red: 0, green: 0.52, blue: 0.37)
    private static let softEmerald = Color(red: 0.9, green: 0.965, blue: 0.94)

    private static func region(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    }
}
