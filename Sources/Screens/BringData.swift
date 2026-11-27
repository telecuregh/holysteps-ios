import SwiftUI
import UniformTypeIdentifiers

/// Bring period history over from Flo, Clue or another tracker: a JSON, CSV or zip export (Clue's password-locked zip
/// included), or Apple Health. Read on this phone only; only period dates and lengths are kept.
struct BringDataView: View {
    @EnvironmentObject var store: AppStore
    @State private var picking = false
    @State private var pending: Data?
    @State private var password = ""
    @State private var askPassword = false
    @State private var wrongPassword = false
    @State private var found: [PeriodImport.Period] = []
    @State private var message = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🌸 CYCLE").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T("Bring your data").font(.hs(24)).foregroundStyle(HS.text)
                    T("Your period history can come with you, so your predictions start from what you've already logged. Nothing is uploaded: the file is read on this phone.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("🌸 Moving from Flo or Clue?").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            T("Clue: tap the menu (☰), then Settings, \"Download my data\" and \"Request data\". Copy the password Clue shows you. Clue emails a download link that expires after 72 hours, so save the zip to Files right away, then pick it below and type the password when HolySteps asks.")
                                .font(.hs(12)).foregroundStyle(HS.textSecondary)
                            T("Flo: Flo gives your data on request. In Flo, open Help, then Contact us, and ask for a copy of your data. It arrives as a text or JSON file. Save it to Files and pick it below.")
                                .font(.hs(12)).foregroundStyle(HS.textSecondary)
                            T("Only period dates and cycle length come in from these files. Symptoms and moods stay in the old app, so export them there first if you want to keep them.")
                                .font(.hs(11)).foregroundStyle(HS.textMuted)
                            GoldButton(title: "Pick my Flo or Clue file") { message = ""; picking = true }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("❤️ From Apple Health").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            T("If your other app or your watch shares with Apple Health, bring the periods and waking temperatures in from there.").font(.hs(12)).foregroundStyle(HS.textSecondary)
                            HealthImportButton()
                        }
                    }
                    if !message.isEmpty { D(message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }.padding(20)
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .commaSeparatedText, .plainText, .zip, .data]) { r in
            guard case .success(let url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count <= 8 << 20 else { message = tr("That file couldn't be opened, or it is larger than 8 MB."); return }
            open(data, password: nil)
        }
        .alert(tr("This file has a password"), isPresented: $askPassword) {
            SecureField(tr("Password"), text: $password)
            Button(tr("Open")) { let p = password; password = ""; if let d = pending { open(d, password: p) } }
            Button(tr("Cancel"), role: .cancel) { pending = nil; password = "" }
        } message: {
            T(wrongPassword ? "That password didn't open it. Check it and try again." : "Type the password the other app gave you. Clue shows it on screen when you tap Request data.")
        }
        .alert(tr("Bring in your period history?"), isPresented: Binding(get: { !found.isEmpty }, set: { if !$0 { found = [] } })) {
            Button(tr("Bring it in")) { bringIn() }
            Button(tr("Cancel"), role: .cancel) { found = [] }
        } message: {
            D(tr("Found \(found.count) periods, from \(found.first?.start ?? "") to \(found.last?.start ?? ""). Periods already in HolySteps stay as they are."))
        }
    }

    private func open(_ data: Data, password: String?) {
        let isZip = data.count > 3 && data[data.startIndex] == 0x50 && data[data.startIndex + 1] == 0x4B
        var texts: [String] = []
        if isZip {
            do {
                texts = try ZipReader.entries(data, password: password, want: PeriodImport.wanted).map { String(decoding: $0.data, as: UTF8.self) }
            } catch ZipReader.Failure.needsPassword {
                pending = data; wrongPassword = false; askPassword = true; return
            } catch ZipReader.Failure.wrongPassword {
                pending = data; wrongPassword = true; askPassword = true; return
            } catch {
                message = tr("That zip couldn't be read. Unzip it in Files and pick the JSON or CSV file inside."); return
            }
        } else {
            texts = [String(decoding: data, as: UTF8.self)]
        }
        pending = nil
        var all: [PeriodImport.Period] = []
        for t in texts { all += PeriodImport.read(t) }
        var seen = Set<String>()
        found = all.filter { seen.insert($0.start).inserted }.sorted { $0.start < $1.start }
        if found.isEmpty { message = tr("No period history was found in that file. If it came from Flo, make sure you picked the data file Flo sent, not the email.") }
    }

    private func bringIn() {
        var added = 0
        for p in found {
            guard let d = AppStore.date(fromKey: p.start) else { continue }
            if store.periodStarts.contains(where: { abs(CycleLogic.days($0, d)) < 10 }) { continue }
            store.logPeriodStart(d); added += 1
        }
        let lens = found.map(\.days).filter { (2...10).contains($0) }
        if lens.count >= 3 { store.periodLength = Int((Double(lens.reduce(0, +)) / Double(lens.count)).rounded()) }
        message = tr(added == 0 ? "Those periods were already in HolySteps." : "Brought in \(added) periods. Your predictions now use them.")
        found = []
    }
}
