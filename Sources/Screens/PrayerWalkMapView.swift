import SwiftUI
import MapKit
import CoreLocation

// MARK: - Prayer data

private struct PrayerPrompt: Identifiable {
    let id = UUID()
    let category: String
    let prayer: String
    let icon: String
    let color: UInt32
}

private let prayerDeck: [PrayerPrompt] = [
    PrayerPrompt(category: "Homes", prayer: "Lord, bless every family behind these doors. Bring peace, love, and your presence into each home.", icon: "house.fill", color: 0x56B892),
    PrayerPrompt(category: "Schools", prayer: "Father, guard every child and teacher here. Give them wisdom, safety, and a hunger for truth.", icon: "book.fill", color: 0x64A5E8),
    PrayerPrompt(category: "Churches", prayer: "Unite your people here, Lord. Let this church be a light to the city and a shelter for the weary.", icon: "cross.fill", color: 0xF3D5C0),
    PrayerPrompt(category: "Hospitals", prayer: "Heal those who suffer near here, Lord. Strengthen every doctor, nurse, and caregiver with your grace.", icon: "cross.case.fill", color: 0xE57A9E),
    PrayerPrompt(category: "Parks", prayer: "Thank you, Creator, for the beauty around me. Let this open space remind every neighbor of your goodness.", icon: "leaf.fill", color: 0x8BC34A),
    PrayerPrompt(category: "Streets", prayer: "Lord, bless the strangers I pass today. May each person sense your love through kindness they cannot explain.", icon: "figure.walk", color: 0xD8B27A),
    PrayerPrompt(category: "Businesses", prayer: "Prosper honest work here, Father. May the people who labor in this place find purpose and provision.", icon: "building.2.fill", color: 0x9F948B),
    PrayerPrompt(category: "Neighborhoods", prayer: "Knit this neighborhood together, Lord. Let unity and trust grow where division once lived.", icon: "person.3.fill", color: 0xA78BD0),
    PrayerPrompt(category: "The vulnerable", prayer: "Be near the lonely, the struggling, and the unseen near this place. Let your comfort find them today.", icon: "heart.fill", color: 0xE57A9E),
    PrayerPrompt(category: "City leaders", prayer: "Give our leaders wisdom to serve with integrity. Raise up righteous voices in every hall of power.", icon: "building.columns.fill", color: 0x64A5E8),
    PrayerPrompt(category: "The lost", prayer: "Draw near to everyone on this street who does not yet know you, Lord. Let today be the day they begin to seek.", icon: "magnifyingglass", color: 0xF3D5C0),
    PrayerPrompt(category: "First responders", prayer: "Protect every firefighter, officer, and EMT who serves this community. Keep them safe and give them courage.", icon: "staroflife.fill", color: 0xD8B27A),
    PrayerPrompt(category: "Youth", prayer: "Raise up a generation of young people here, Lord, who know who they are and whose they are. Guard them from harm.", icon: "figure.run", color: 0x8BC34A),
    PrayerPrompt(category: "Seniors", prayer: "Honor the elders near this place, Lord. Bring companions to the lonely and comfort to those in their final years.", icon: "figure.walk.cane", color: 0x56B892),
    PrayerPrompt(category: "Revival", prayer: "Pour out your Spirit on this place, Father. Let a spiritual awakening begin right here, in this city, in this generation.", icon: "flame.fill", color: 0xE8945A),
]

// MARK: - Prayer pin model

private struct PrayerPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let prompt: PrayerPrompt
    let distanceM: Double   // cumulative distance when this pin was dropped
}

// MARK: - Main view

struct PrayerWalkMapView: View {
    @ObservedObject private var rec = WalkRecorder.shared
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pins: [PrayerPin] = []
    @State private var current: PrayerPrompt? = nil
    @State private var showCard = false
    @State private var prayerDeckIndex = 0
    @State private var lastPinDistance: Double = -300        // drop first pin right away
    @State private var cardTimer: Timer? = nil

    private let pinInterval: Double = 300    // drop a prayer every 300 m

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            VStack(spacing: 0) {
                Spacer()
                if !rec.started {
                    noWalkBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if showCard, let p = current {
                    prayerCard(p)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: showCard)
            .animation(.spring(response: 0.4), value: rec.started)
        }
        .navigationTitle(D(tr("Prayer Walk Map")))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rec.distanceM) { _, dist in
            checkDropPin(at: dist)
        }
        .onChange(of: rec.route.last) { _, _ in
            syncCamera()
        }
        .onAppear {
            prayerDeckIndex = Int.random(in: 0..<prayerDeck.count)
            syncCamera()
            if rec.started { buildPinsFromExisting() }
        }
        .onDisappear { cardTimer?.invalidate() }
    }

    // MARK: Map

    private var mapLayer: some View {
        Map(position: $camera) {
            UserAnnotation()
            // Route polyline
            ForEach(routeSegments.indices, id: \.self) { i in
                MapPolyline(coordinates: routeSegments[i])
                    .stroke(Color(hex: 0x56B892), lineWidth: 5)
            }
            // Prayer pins
            ForEach(pins) { pin in
                Annotation("", coordinate: pin.coordinate) {
                    prayerPinBadge(pin.prompt)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .all))
        .ignoresSafeArea(edges: .top)
    }

    private func prayerPinBadge(_ p: PrayerPrompt) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color(hex: p.color))
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                Image(systemName: p.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
            Triangle()
                .fill(Color(hex: p.color))
                .frame(width: 10, height: 6)
        }
    }

    // MARK: Prayer card

    private func prayerCard(_ p: PrayerPrompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: p.color).opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: p.icon).font(.system(size: 15)).foregroundStyle(Color(hex: p.color))
                }
                VStack(alignment: .leading, spacing: 1) {
                    T("Prayer for").font(.hs(10)).foregroundStyle(HS.textMuted)
                    D(tr(p.category)).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                }
                Spacer()
                Button { dismissCard() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(HS.textMuted)
                }
            }
            T(tr(p.prayer)).font(.hs(14)).foregroundStyle(HS.text).fixedSize(horizontal: false, vertical: true)
            Button {
                nextPrayer()
            } label: {
                T(tr("Next prayer")).font(.hs(13, .semibold)).foregroundStyle(HS.onGold)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(HS.goldButton))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(HS.solidSurface)
                .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: No walk banner

    private var noWalkBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk").font(.system(size: 24)).foregroundStyle(HS.goldButton)
                VStack(alignment: .leading, spacing: 2) {
                    T("Start a Walk to begin").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Prayers will appear as you move through your neighborhood").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                Spacer()
            }
            NavigationLink {
                WalkSetupView()
            } label: {
                T(tr("Start walking")).font(.hs(14, .semibold)).foregroundStyle(HS.onGold)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Capsule().fill(HS.goldButton))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(HS.solidSurface)
                .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: Logic

    private func checkDropPin(at dist: Double) {
        guard rec.started, rec.outdoor else { return }
        guard dist - lastPinDistance >= pinInterval else { return }
        guard let last = rec.route.last else { return }
        lastPinDistance = dist
        let prompt = prayerDeck[prayerDeckIndex % prayerDeck.count]
        prayerDeckIndex += 1
        let pin = PrayerPin(
            coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon),
            prompt: prompt,
            distanceM: dist
        )
        pins.append(pin)
        showPrayer(prompt)
    }

    private func showPrayer(_ p: PrayerPrompt) {
        cardTimer?.invalidate()
        current = p
        showCard = true
        // Auto-dismiss after 25 seconds if user doesn't tap next/close
        cardTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { _ in
            DispatchQueue.main.async { dismissCard() }
        }
    }

    private func dismissCard() {
        cardTimer?.invalidate()
        showCard = false
    }

    private func nextPrayer() {
        cardTimer?.invalidate()
        let p = prayerDeck[prayerDeckIndex % prayerDeck.count]
        prayerDeckIndex += 1
        showPrayer(p)
    }

    private func syncCamera() {
        guard let last = rec.route.last else { return }
        let coord = CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon)
        camera = .camera(MapCamera(centerCoordinate: coord, distance: 500, heading: 0, pitch: 0))
    }

    private func buildPinsFromExisting() {
        // Reconstruct pins for route already in progress
        guard rec.outdoor else { return }
        let route = rec.route
        var cumulDist: Double = 0
        var prevLat = route.first?.lat ?? 0
        var prevLon = route.first?.lon ?? 0
        var nextPinAt: Double = pinInterval
        var idx = prayerDeckIndex

        for pt in route.dropFirst() {
            let d = haversineM(prevLat, prevLon, pt.lat, pt.lon)
            cumulDist += d
            prevLat = pt.lat; prevLon = pt.lon
            if cumulDist >= nextPinAt {
                let prompt = prayerDeck[idx % prayerDeck.count]; idx += 1
                pins.append(PrayerPin(
                    coordinate: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lon),
                    prompt: prompt,
                    distanceM: cumulDist
                ))
                nextPinAt += pinInterval
            }
        }
        prayerDeckIndex = idx
        lastPinDistance = pins.last?.distanceM ?? -pinInterval
    }

    private var routeSegments: [[CLLocationCoordinate2D]] {
        Dictionary(grouping: rec.route, by: \.seg)
            .sorted { $0.key < $1.key }
            .map(\.value)
            .filter { $0.count >= 2 }
            .map { pts in pts.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } }
    }

    private func haversineM(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1 * .pi/180)*cos(lat2 * .pi/180)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }
}

// MARK: - Triangle shape (pin pointer)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Gated entry point

struct PrayerWalkFeatureView: View {
    var body: some View {
        Gated(feature: .prayerWalkMap) {
            PrayerWalkMapView()
        }
    }
}
