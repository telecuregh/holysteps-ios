import SwiftUI
import PhotosUI

/// Android's skin journal (SkinJournal.kt, SkinJournalScreen.kt): one private photo a day with the person's own notes,
/// kept only on this iPhone (file protection on, excluded from iCloud backup, never uploaded). Compare two days and see
/// which notes come with which part of the cycle. It describes what she logged; it never judges or diagnoses skin.
enum SkinJournal {
    static let tags = ["Clear", "Breakout", "Dry", "Oily", "Red or irritated", "Glowing", "Tired"]
    static let maxEntries = 400
    struct Entry: Codable, Equatable, Identifiable { let date: String; var tags: [String]; var cycleDay: Int?; var id: String { date } }

    enum Stretch: String {
        case period = "during your period", after = "in the week after your period", middle = "around the middle of your cycle", before = "in the week or so before your period"
    }
    static func stretch(_ day: Int, cycleLength: Int) -> Stretch {
        let ov = min(45, max(21, cycleLength)) - 14
        if day <= 5 { return .period }
        if day < ov - 1 { return .after }
        if day <= ov + 2 { return .middle }
        return .before
    }
    struct Pattern: Equatable { let tag: String; let stretch: Stretch; let times, of: Int }
    /// For each note logged at least three times with a cycle day, the part of the cycle where 60% or more of them fell.
    static func patterns(_ list: [Entry], cycleLength: Int) -> [Pattern] {
        tags.compactMap { tag in
            let s = list.filter { $0.tags.contains(tag) }.compactMap { $0.cycleDay }.map { stretch($0, cycleLength: cycleLength) }
            guard s.count >= 3, let top = Dictionary(grouping: s, by: { $0 }).max(by: { $0.value.count < $1.value.count }) else { return nil }
            return top.value.count * 10 >= s.count * 6 ? Pattern(tag: tag, stretch: top.key, times: top.value.count, of: s.count) : nil
        }
    }
}

@MainActor
final class SkinStore: ObservableObject {
    static let shared = SkinStore()
    @Published private(set) var entries: [SkinJournal.Entry] = []
    private let dir: URL = {
        var d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("skin", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        var v = URLResourceValues(); v.isExcludedFromBackup = true; try? d.setResourceValues(v)
        return d
    }()
    private var listURL: URL { dir.appendingPathComponent("entries.json") }
    func photoURL(_ date: String) -> URL { dir.appendingPathComponent("skin_\(date).jpg") }

    private init() {
        entries = (try? JSONDecoder().decode([SkinJournal.Entry].self, from: Data(contentsOf: listURL))) ?? []
    }
    private func save() { try? JSONEncoder().encode(entries).write(to: listURL, options: [.atomic, .completeFileProtection]) }

    func keep(_ image: UIImage, tags: [String], cycleDay: Int?) {
        let d = AppStore.dayKey()
        let w: CGFloat = 1280, scale = min(1, w / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let small = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpg = small.jpegData(compressionQuality: 0.8) else { return }
        try? jpg.write(to: photoURL(d), options: [.atomic, .completeFileProtection])
        entries = Array((entries.filter { $0.date != d } + [.init(date: d, tags: tags, cycleDay: cycleDay)]).sorted { $0.date < $1.date }.suffix(SkinJournal.maxEntries))
        save()
    }
    func setTags(_ tags: [String]) {
        guard let i = entries.firstIndex(where: { $0.date == AppStore.dayKey() }) else { return }
        entries[i].tags = tags; save()
    }
    func delete(_ e: SkinJournal.Entry) { try? FileManager.default.removeItem(at: photoURL(e.date)); entries.removeAll { $0 == e }; save() }
    func image(_ e: SkinJournal.Entry) -> UIImage? { UIImage(contentsOfFile: photoURL(e.date).path) }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.cameraDevice = .front; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ u: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> C { C(done) }
    final class C: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void; init(_ d: @escaping (UIImage?) -> Void) { done = d }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo i: [UIImagePickerController.InfoKey: Any]) { done(i[.originalImage] as? UIImage) }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { done(nil) }
    }
}

struct SkinJournalView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var skin = SkinStore.shared
    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var tags: Set<String> = []
    @State private var left: SkinJournal.Entry?

    private var todayEntry: SkinJournal.Entry? { skin.entries.last { $0.date == AppStore.dayKey() } }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🪞 SKIN JOURNAL").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF43F5E))
                    T("Your skin, over time").font(.hs(24)).foregroundStyle(HS.text)
                    T("One photo a day in the same light, with a note or two. Compare any two days, and see how your skin follows your cycle. Photos stay on this iPhone only: never uploaded, never backed up.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    HStack {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { GoldButton(title: todayEntry == nil ? "Take today's photo" : "Retake today's photo") { camera = true } }
                        PhotosPicker(selection: $pick, matching: .images) { Label(tr("From photos"), systemImage: "photo") }.buttonStyle(.bordered)
                    }
                    T("Tip: same spot, same window light, no makeup, for fair comparisons.").font(.hs(11)).foregroundStyle(HS.textMuted)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("How does it feel today?").font(.hs(13)).foregroundStyle(HS.textSecondary)
                            FlowTags(all: SkinJournal.tags, selected: tags) { t in
                                if tags.contains(t) { tags.remove(t) } else { tags.insert(t) }
                                skin.setTags(SkinJournal.tags.filter(tags.contains))
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("🌙 Your skin and your cycle").font(.hs(14, .bold)).foregroundStyle(HS.text)
                            let pats = SkinJournal.patterns(skin.entries, cycleLength: store.cycleLength)
                            if pats.isEmpty { T("Keep noting how your skin feels; patterns show once a note has come up three times.").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                            ForEach(pats, id: \.tag) { p in
                                D(tr("• \(tr(p.tag)): \(p.times) of \(p.of) times \(tr(p.stretch.rawValue)).")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    if let newest = skin.entries.last {
                        T("Compare").font(.hs(14, .bold)).foregroundStyle(HS.text)
                        T("Tap any day below to put it on the left; your newest photo stays on the right.").font(.hs(11)).foregroundStyle(HS.textMuted)
                        HStack(spacing: 8) { photo(left ?? skin.entries[0], h: 200); photo(newest, h: 200) }
                        ScrollView(.horizontal) {
                            HStack { ForEach(skin.entries.reversed()) { e in Button { left = e } label: { photo(e, h: 90) } .contextMenu { Button(tr("Delete"), role: .destructive) { skin.delete(e) } } } }
                        }
                    }
                    T("A journal for your own eyes, not a skin check. For a mole or spot that changes, bleeds or worries you, see a doctor or dermatologist.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }
        }
        .onAppear { tags = Set(todayEntry?.tags ?? []) }
        .fullScreenCover(isPresented: $camera) { CameraPicker { img in camera = false; if let img { keep(img) } }.ignoresSafeArea() }
        .onChange(of: pick) { _, item in
            Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { keep(img) }; pick = nil }
        }
    }

    private func keep(_ img: UIImage) {
        let day = Rhythm(store: store).cycleDay
        skin.keep(img, tags: SkinJournal.tags.filter(tags.contains), cycleDay: store.gender == "male" ? nil : day)
    }

    private func photo(_ e: SkinJournal.Entry, h: CGFloat) -> some View {
        VStack(spacing: 2) {
            if let i = skin.image(e) { Image(uiImage: i).resizable().scaledToFill().frame(width: h * 0.75, height: h).clipped().clipShape(RoundedRectangle(cornerRadius: 10)) }
            else { D("🪞").frame(width: h * 0.75, height: h) }
            D(e.date).font(.hs(10)).foregroundStyle(HS.textMuted)
        }
    }
}

/// Wrapping chips for a small set of tags.
struct FlowTags: View {
    let all: [String]; let selected: Set<String>; let toggle: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(all, id: \.self) { t in
                Button { toggle(t) } label: {
                    T(t).font(.hs(12, .semibold)).padding(.horizontal, 10).padding(.vertical, 6).frame(maxWidth: .infinity)
                        .background(Capsule().fill(selected.contains(t) ? Color(hex: 0xF472B6).opacity(0.3) : HS.text.opacity(0.06)))
                        .foregroundStyle(HS.text)
                }.buttonStyle(.plain)
            }
        }
    }
}
