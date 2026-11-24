import SwiftUI

/// Android's ProfileScreen: the meadow header card, then settings in labeled sections. Plans, account, backup,
/// devices and people-and-safety come with the account and community phases, so they're left out until then.
struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var i18n: I18n
    @ObservedObject private var listening = BibleListening.shared
    @Environment(\.openURL) private var openURL
    @AppStorage("stepGoal") private var stepGoal = 8000
    @State private var confirmErase = false
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable { case name, gender, language, cycleLength, periodLength, stepGoal, narrator, sermon; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Button { sheet = .name } label: { ProfileHeaderCard(name: store.name) }
                            .buttonStyle(.plain)
                            .accessibilityHint(tr("Change your name"))
                            .padding(.top, 48).padding(.horizontal, 20).padding(.bottom, 12)

                        group("Language") {
                            item("globe", "Language", i18n.choice == .system ? tr(i18n.choice.label) : i18n.choice.label, 0x8B5CF6) { sheet = .language }
                        }
                        SectionHeader(title: "Appearance").padding(.top, 8)
                        ThemeModeToggle().padding(.horizontal, 20)

                        group("About you") {
                            item(store.gender == "male" ? "person" : "person", "I am",
                                 store.gender == "male" ? tr("A man") : (store.gender == "female" ? tr("A woman") : tr("Tap to choose")), 0x14B8A6) { sheet = .gender }
                            if store.gender != "male" {
                                item("arrow.triangle.2.circlepath", "Cycle Length", tr("\(store.cycleLength) days"), 0xEC4899) { sheet = .cycleLength }
                                item("calendar", "Period Length", tr("\(store.periodLength) days"), 0xEC4899) { sheet = .periodLength }
                            }
                        }
                        group("Goals") {
                            item("figure.walk", "Daily Step Goal", tr("\(stepGoal.formatted()) steps"), 0x8B5CF6) { sheet = .stepGoal }
                        }
                        group("Faith and content") {
                            item("mic", "Narrator", VoicePacks.narrators.first { $0.id == listening.narrator }?.name ?? tr("Phone voice"), 0x8B5CF6) { sheet = .narrator }
                            item("calendar.badge.clock", "Weekly sermon", tr("Day and reminder"), 0x8B5CF6) { sheet = .sermon }
                        }
                        group("Reminders and routines") {
                            link("moon.stars", "Bedtime reminder", BedtimeReminder.on ? tr("On") : tr("Off"), 0x8B5CF6) { SleepView() }
                            link("calendar", "Weekly recap", RecapReminder.on ? tr("On") : tr("Off"), 0x8B5CF6) { WeeklyRecapView() }
                        }
                        group("About") {
                            item("doc.text", "Terms of Service", "", 0x9F948B) { openURL(URL(string: AppLinks.site + "/terms")!) }
                            item("lock", "Privacy Policy", "", 0x9F948B) { openURL(URL(string: AppLinks.site + "/privacy")!) }
                        }
                        group("Your data") {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    T("Privacy").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                    T("Your prayers, journal, cycle dates, Bible highlights and notes are stored only on this iPhone.")
                                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                                }
                            }
                            Button(role: .destructive) { confirmErase = true } label: {
                                T("Erase all my data on this phone").font(.hs(14, .semibold)).foregroundStyle(Color(hex: 0xFCA5A5))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0xFCA5A5).opacity(0.5), lineWidth: 1))
                            }
                        }
                        D("HolySteps \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.hs(12)).foregroundStyle(HS.textMuted).frame(maxWidth: .infinity).padding(.top, 20)
                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { s in sheetView(s) }
            .alert(tr("Erase all data?"), isPresented: $confirmErase) {
                Button(tr("Erase"), role: .destructive) {
                    store.prayers = []; store.journal = []; store.periodStarts = []
                    store.readDays = []; store.name = ""
                    BibleState.shared.eraseAll()
                    DevotionalState.shared.eraseAll()
                    SermonWeek.shared.eraseHeard()
                    QuizLog.shared.erase()
                    ActivityLog.shared.erase(); FirstWeek.shared.eraseAll(); CycleLog.shared.erase(); CheckInStore.shared.erase(); CoachLog.shared.erase()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: { T("This removes your prayers, journal, cycle dates, reading streak, Bible highlights and notes from this phone.") }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title).padding(.top, 8)
            VStack(spacing: 8) { content() }.padding(.horizontal, 20)
        }
    }

    private func item(_ symbol: String, _ title: String, _ value: String, _ hex: UInt32, action: @escaping () -> Void) -> some View {
        Button(action: action) { SettingsRow(symbol: symbol, title: title, value: value, hex: hex) }.buttonStyle(.plain)
    }

    private func link<Dest: View>(_ symbol: String, _ title: String, _ value: String, _ hex: UInt32, @ViewBuilder destination: @escaping () -> Dest) -> some View {
        NavigationLink { destination() } label: { SettingsRow(symbol: symbol, title: title, value: value, hex: hex) }.buttonStyle(.plain)
    }

    @ViewBuilder private func sheetView(_ s: Sheet) -> some View {
        switch s {
        case .name: NameSheet()
        case .gender:
            ChoiceSheet(title: "I am", options: [("female", "A woman"), ("male", "A man"), ("", "Not set")], selected: store.gender) { store.gender = $0 }
        case .language:
            ChoiceSheet(title: "Language", options: I18n.Choice.allCases.map { ($0.rawValue, $0 == .system ? tr($0.label) : $0.label) },
                        selected: i18n.choice.rawValue, note: "Automatic follows your iPhone's language.") {
                if let c = I18n.Choice(rawValue: $0) { i18n.setChoice(c) }
            }
        case .cycleLength: NumberSheet(title: "Cycle Length", suffix: "days", range: 15...90, value: store.cycleLength) { store.cycleLength = $0 }
        case .periodLength: NumberSheet(title: "Period Length", suffix: "days", range: 1...14, value: store.periodLength) { store.periodLength = $0 }
        case .stepGoal: StepGoalSheet()
        case .narrator:
            ChoiceSheet(title: "Narrator voice", options: VoicePacks.narrators.map { ($0.id, $0.name) } + [(VoicePacks.deviceVoice, tr("Phone voice"))],
                        selected: listening.narrator, note: "Applies to Bible listening.") { listening.narrator = $0 }
        case .sermon: SermonSettingsView()
        }
    }
}

/// Android's SettingsItem: a tinted icon square, the title, a short value on the right (or a longer one beneath), ›.
struct SettingsRow: View {
    let symbol: String, title: String, value: String, hex: UInt32
    var body: some View {
        let asSubtitle = value.count > 18
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(HS.readable(hex))
                .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: hex).opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                T(title).font(.hs(14)).foregroundStyle(HS.text)
                if asSubtitle { D(value).font(.hs(12)).foregroundStyle(HS.textMuted) }
            }
            Spacer(minLength: 6)
            if !asSubtitle && !value.isEmpty { D(value).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(1) }
            D("›").font(.hs(18)).foregroundStyle(HS.textMuted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0xD9B49F).opacity(0.22), lineWidth: 1))
        .contentShape(Rectangle())
    }
}

struct ChoiceSheet: View {
    let title: String
    let options: [(String, String)]
    let selected: String
    var note: String? = nil
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: title) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let o = options[i]
                    Button { onPick(o.0); dismiss() } label: {
                        HStack {
                            D(o.1).font(.hs(15, o.0 == selected ? .semibold : .regular)).foregroundStyle(HS.text)
                            Spacer()
                            if o.0 == selected { Image(systemName: "checkmark").foregroundStyle(HS.gold) }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(o.0 == selected ? HS.goldButton.opacity(0.18) : HS.cardFill))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let note { T(note).font(.hs(12)).foregroundStyle(HS.textMuted).padding(.top, 4) }
                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }
}

/// Android's number dialog: − value +, then Save.
struct NumberSheet: View {
    let title: String, suffix: String
    let range: ClosedRange<Int>
    @State var value: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: title) {
            VStack(spacing: 20) {
                HStack(spacing: 28) {
                    Button { value = max(range.lowerBound, value - 1) } label: { D("−").font(.hs(28)).foregroundStyle(HS.faith).frame(width: 44, height: 44) }
                        .accessibilityLabel(tr("Less"))
                    T("\(value) \(suffix)").font(.hs(28, .bold)).foregroundStyle(HS.text)
                    Button { value = min(range.upperBound, value + 1) } label: { D("+").font(.hs(28)).foregroundStyle(HS.faith).frame(width: 44, height: 44) }
                        .accessibilityLabel(tr("More"))
                }
                GoldButton(title: "Save") { onSave(value); dismiss() }
            }
            .padding(24)
        }
        .presentationDetents([.height(260)])
    }
}

struct NameSheet: View {
    @EnvironmentObject var store: AppStore
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: "Your name") {
            VStack(spacing: 18) {
                TextField(tr("Your first name"), text: $name).textFieldStyle(.roundedBorder).textContentType(.givenName)
                GoldButton(title: "Save") { store.name = name.trimmingCharacters(in: .whitespaces); dismiss() }
            }
            .padding(24)
        }
        .presentationDetents([.height(220)])
        .onAppear { name = store.name }
    }
}

/// Profile › Appearance (Android ProfileScreen ThemeModeToggle): Dark, Light and Pearl in one rounded row; the chosen
/// one is filled gold.
struct ThemeModeToggle: View {
    @EnvironmentObject var appearance: Appearance
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ThemeMode.allCases) { m in
                let on = appearance.mode == m
                Button { appearance.mode = m } label: {
                    HStack(spacing: 4) {
                        T(m.emoji).font(.system(size: 13))
                        T(m.label).font(.hs(13, on ? .bold : .regular))
                    }
                    .foregroundStyle(on ? HS.onGold : HS.textMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("theme-\(m.rawValue)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xD9B49F).opacity(0.24), lineWidth: 1))
    }
}

/// Android's Profile header: the meadow photo is the card, under a soft shade that deepens toward the bottom, with a
/// violet-gold edge, the gold avatar with initials, and the name.
struct ProfileHeaderCard: View {
    let name: String
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xF1D7A8), HS.goldButton, Color(hex: 0xB98C52)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(Color(hex: 0xD9B49F), lineWidth: 1.5)
                if initials.isEmpty { Image(systemName: "person.fill").font(.system(size: 30)).foregroundStyle(HS.onGold) }
                else { D(initials).font(.hs(28, .bold)).foregroundStyle(HS.onGold) }
            }
            .frame(width: 80, height: 80)
            D(name.isEmpty ? tr("Welcome") : name).font(.hs(22, .semibold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.vertical, 22)
        .background {
            Image("profile_bg_meadow").resizable().scaledToFill().accessibilityHidden(true)
                .overlay(LinearGradient(colors: [Color(hex: 0x140C18, alpha: Double(0x38) / 255), Color(hex: 0x140C18, alpha: Double(0x66) / 255),
                                                 Color(hex: 0x140C18, alpha: Double(0xB3) / 255)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [Color(hex: 0x9D7FEA), Color(hex: 0xD9B49F), Color(hex: 0x9D7FEA)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    }
}
