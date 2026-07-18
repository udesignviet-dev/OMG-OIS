import SwiftUI
import MapKit
import CoreLocation

private enum MapSheet: Identifiable {
    case checkin
    case hazardPin
    case sos
    case menu

    var id: String {
        switch self {
        case .checkin: return "checkin"
        case .hazardPin: return "hazardPin"
        case .sos: return "sos"
        case .menu: return "menu"
        }
    }
}

private struct HazardCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color

    func matches(_ hazard: MHMHazard) -> Bool {
        guard title != "Tất cả" else { return true }
        let haystack = [hazard.type, hazard.severity, hazard.title]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let needle = title
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        return haystack.contains(needle)
            || needle.components(separatedBy: " / ").contains { haystack.contains($0) }
    }
}

private let hazardCategories: [HazardCategory] = [
    .init(title: "Tất cả", icon: "square.grid.2x2.fill", color: Color(hex: 0xF5A524)),
    .init(title: "Tai nạn giao thông", icon: "car.side.fill", color: Color(hex: 0xFF4D4D)),
    .init(title: "Tắc đường", icon: "road.lanes", color: Color(hex: 0xF97316)),
    .init(title: "Ngập lụt / Mưa lớn", icon: "cloud.heavyrain.fill", color: Color(hex: 0x2F80ED)),
    .init(title: "Sạt lở đất", icon: "mountain.2.fill", color: Color(hex: 0xA16207)),
    .init(title: "Bão / Gió lớn", icon: "wind", color: Color(hex: 0x64748B)),
    .init(title: "Cần cấp cứu / Cứu thương", icon: "cross.case.fill", color: Color(hex: 0xE11D48)),
    .init(title: "Hỏa hoạn", icon: "flame.fill", color: Color(hex: 0xEF4444)),
    .init(title: "SOS khẩn cấp", icon: "sos", color: Color(hex: 0xDC2626)),
    .init(title: "Cứu hộ xe", icon: "wrench.and.screwdriver.fill", color: Color(hex: 0xF59E0B)),
    .init(title: "Khác", icon: "mappin.and.ellipse", color: Color(hex: 0x8B5CF6))
]

struct MapScreen: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @StateObject private var locationManager = LocationManager()
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542)
    @State private var activeSheet: MapSheet?
    @State private var selectedCategory = "Tất cả"

    private var filteredHazards: [MHMHazard] {
        guard let category = hazardCategories.first(where: { $0.title == selectedCategory }) else {
            return syncEngine.hazards
        }
        return syncEngine.hazards.filter(category.matches)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MHMMapView(
                    hazards: filteredHazards,
                    checkins: syncEngine.checkins,
                    userCoordinate: locationManager.coordinate,
                    centerCoordinate: $centerCoordinate
                )
                .ignoresSafeArea()

                mapAtmosphere

                VStack(spacing: 12) {
                    topCommandCenter
                    categoryRail
                    Spacer()
                    bottomDock
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)

                centerReticle

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingControls
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 150)
                }

                if let message = syncEngine.errorMessage {
                    VStack {
                        errorBanner(message)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 112)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                locationManager.request()
                await syncEngine.sync()
            }
            .onChange(of: locationManager.coordinate?.latitude) { _, _ in
                if let coordinate = locationManager.coordinate {
                    centerCoordinate = coordinate
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .checkin:
                    CheckinSheet(coordinate: centerCoordinate)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                case .hazardPin:
                    HazardPinSheet(coordinate: centerCoordinate)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .sos:
                    SOSSheet(coordinate: locationManager.coordinate ?? centerCoordinate)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                case .menu:
                    MainMenuSheet()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var mapAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x07111F).opacity(0.64),
                    Color.clear,
                    Color(hex: 0x07111F).opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color(hex: 0xF97316).opacity(0.18), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topCommandCenter: some View {
        GlassCard(cornerRadius: 28) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: 0xFFB703), Color(hex: 0xFB5607)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "motorcycle.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 46, height: 46)
                    .shadow(color: Color(hex: 0xFB5607).opacity(0.45), radius: 18, y: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maps Biker")
                            .font(.system(.title3, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                        Text("Cộng đồng cảnh báo & cứu hộ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    liveBadge

                    Button {
                        activeSheet = .menu
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.13), in: Circle())
                    }
                    .accessibilityLabel("Mở menu")
                }

                Button {
                    locationManager.request()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(hex: 0xFBBF24))
                        Text("Tìm địa điểm, cung đường, quận...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.74))
                        Spacer()
                        Image(systemName: "scope")
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color(hex: 0x0F172A).opacity(0.62), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(syncEngine.isSyncing ? Color(hex: 0xFBBF24) : Color(hex: 0x22C55E))
                .frame(width: 8, height: 8)
            Text(syncEngine.isSyncing ? "SYNC" : "LIVE")
                .font(.caption2.monospaced().weight(.black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(hazardCategories) { category in
                    CategoryChip(
                        category: category,
                        isSelected: category.title == selectedCategory
                    ) {
                        selectedCategory = category.title
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var centerReticle: some View {
        VStack(spacing: 0) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: 0x0F172A).opacity(0.82), in: Circle())
                .overlay(Circle().stroke(Color(hex: 0xF59E0B), lineWidth: 2))
            Rectangle()
                .fill(Color(hex: 0xF59E0B))
                .frame(width: 2, height: 18)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .allowsHitTesting(false)
    }

    private var floatingControls: some View {
        VStack(spacing: 10) {
            RoundIconButton(systemName: syncEngine.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise") {
                Task { await syncEngine.sync() }
            }
            RoundIconButton(systemName: "location.fill") {
                if let coordinate = locationManager.coordinate {
                    centerCoordinate = coordinate
                } else {
                    locationManager.request()
                }
            }
            RoundIconButton(systemName: "map.fill") {}
        }
    }

    private var bottomDock: some View {
        GlassCard(cornerRadius: 30) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    StatPill(
                        value: "\(filteredHazards.count)",
                        title: "cảnh báo",
                        icon: "exclamationmark.triangle.fill",
                        color: Color(hex: 0xEF4444)
                    )
                    StatPill(
                        value: "\(syncEngine.checkins.count)",
                        title: "checkin",
                        icon: "mappin.circle.fill",
                        color: Color(hex: 0xF97316)
                    )
                    StatPill(
                        value: "\(syncEngine.journey.count)",
                        title: "hành trình",
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        color: Color(hex: 0x38BDF8)
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        activeSheet = .sos
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sos")
                                .font(.title3.weight(.black))
                            Text("SOS")
                                .font(.headline.weight(.black))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 106, height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xFF2D55), Color(hex: 0xB91C1C)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .shadow(color: Color(hex: 0xFF2D55).opacity(0.4), radius: 18, y: 8)
                    }

                    ActionPill(title: "Ghim", icon: "pin.fill", tint: Color(hex: 0xF59E0B)) {
                        activeSheet = .hazardPin
                    }
                    ActionPill(title: "Checkin", icon: "camera.fill", tint: Color(hex: 0xFB923C)) {
                        activeSheet = .checkin
                    }
                    ActionPill(title: "Menu", icon: "person.crop.circle.fill", tint: Color(hex: 0x38BDF8)) {
                        activeSheet = .menu
                    }
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: 0xFBBF24))
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(Color(hex: 0x7F1D1D).opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
    }
}

private struct CategoryChip: View {
    let category: HazardCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.black))
                Text(category.title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isSelected ? Color(hex: 0x07111F) : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? category.color : Color(hex: 0x0F172A).opacity(0.70), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.white.opacity(0.0) : Color.white.opacity(0.12)))
            .shadow(color: isSelected ? category.color.opacity(0.35) : .clear, radius: 14, y: 7)
        }
    }
}

private struct StatPill: View {
    let value: String
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: -1) {
                Text(value)
                    .font(.headline.monospacedDigit().weight(.black))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ActionPill: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.10)))
        }
    }
}

private struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18)))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
    }
}

struct HazardPinSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    @State private var title = ""
    @State private var selectedType = hazardCategories[1].title
    @State private var severity = "Trung bình"
    @State private var note = ""

    private let severities = ["Nhẹ", "Trung bình", "Nghiêm trọng", "Khẩn cấp"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        icon: "pin.fill",
                        title: "Ghim cảnh báo",
                        subtitle: "Đặt ghim tại tâm bản đồ để cộng đồng biker né rủi ro.",
                        color: Color(hex: 0xF59E0B)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Loại cảnh báo")
                            .sheetLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                            ForEach(hazardCategories.filter { $0.title != "Tất cả" }) { category in
                                Button {
                                    selectedType = category.title
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: category.icon)
                                            .foregroundStyle(category.color)
                                        Text(category.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        selectedType == category.title ? category.color.opacity(0.16) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedType == category.title ? category.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nội dung")
                            .sheetLabel()
                        TextField("Tiêu đề ngắn gọn", text: $title)
                            .textFieldStyle(.roundedBorder)
                        Picker("Mức độ", selection: $severity) {
                            ForEach(severities, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        TextField("Mô tả thêm, hướng đi an toàn...", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }

                    CoordinateCard(coordinate: coordinate)

                    Text("Starter hiện có API checkin; phần gửi ghim/SOS được thiết kế sẵn giao diện để nối endpoint WordPress khi backend bổ sung.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .navigationTitle("Ghim cảnh báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu nháp") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct SOSSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                SheetHero(
                    icon: "sos",
                    title: "SOS khẩn cấp",
                    subtitle: "Gửi vị trí hiện tại cho nhóm cứu hộ và chuẩn bị gọi khẩn cấp.",
                    color: Color(hex: 0xEF4444)
                )

                HStack(spacing: 12) {
                    SOSQuickAction(title: "Gọi 115", icon: "phone.fill", color: Color(hex: 0xEF4444), url: URL(string: "tel:115"))
                    SOSQuickAction(title: "Cứu hộ xe", icon: "wrench.and.screwdriver.fill", color: Color(hex: 0xF59E0B), url: nil)
                }

                TextField("Bạn cần hỗ trợ gì?", text: $note, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)

                CoordinateCard(coordinate: coordinate)

                Button {
                    dismiss()
                } label: {
                    Label("Gửi tín hiệu SOS", systemImage: "paperplane.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            LinearGradient(colors: [Color(hex: 0xFF2D55), Color(hex: 0x991B1B)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }

                Spacer()
            }
            .padding(18)
            .navigationTitle("SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct MainMenuSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss

    private let items = [
        ("Tài khoản", "person.crop.circle.fill", Color(hex: 0x38BDF8)),
        ("Checkin", "camera.fill", Color(hex: 0xF97316)),
        ("Hành trình", "point.topleft.down.curvedto.point.bottomright.up", Color(hex: 0x22C55E)),
        ("FAQ", "questionmark.circle.fill", Color(hex: 0xA78BFA)),
        ("Liên hệ", "bubble.left.and.bubble.right.fill", Color(hex: 0xF59E0B)),
        ("Giới thiệu", "info.circle.fill", Color(hex: 0x94A3B8))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white)
                                    .font(.title2.weight(.black))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(authStore.user?.displayName ?? "Biker đang trực tuyến")
                                .font(.headline.weight(.black))
                            Text(authStore.user?.email ?? "Đồng bộ tài khoản website")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(items, id: \.0) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.1)
                                    .foregroundStyle(item.2)
                                    .frame(width: 32, height: 32)
                                    .background(item.2.opacity(0.14), in: Circle())
                                Text(item.0)
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                            }
                            .padding(13)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }

                    Button {
                        Task { await syncEngine.sync() }
                        dismiss()
                    } label: {
                        Label("Đồng bộ dữ liệu", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button(role: .destructive) {
                        authStore.logout()
                        dismiss()
                    } label: {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct SheetHero: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(color, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: color.opacity(0.32), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.black))
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoordinateCard: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tọa độ")
                .sheetLabel()
            HStack {
                Label("\(coordinate.latitude, specifier: "%.6f")", systemImage: "location.north.line.fill")
                Spacer()
                Label("\(coordinate.longitude, specifier: "%.6f")", systemImage: "location.north.fill")
            }
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(.secondary)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct SOSQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let url: URL?

    var body: some View {
        Group {
            if let url {
                Link(destination: url) { content }
            } else {
                Button(action: {}) { content }
            }
        }
    }

    private var content: some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.black))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }
}

extension Text {
    func sheetLabel() -> some View {
        self
            .font(.caption.weight(.black))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
