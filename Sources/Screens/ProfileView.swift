import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var i18n: I18n
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(text: "Profile")
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("First name").font(.hs(14)).foregroundStyle(HS.textMuted)
                                TextField(tr("Your first name"), text: $store.name).textFieldStyle(.roundedBorder)
                                T("I am").font(.hs(14)).foregroundStyle(HS.textMuted).padding(.top, 6)
                                Picker("", selection: $store.gender) {
                                    T("A woman").tag("female")
                                    T("A man").tag("male")
                                    T("Not set").tag("")
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("App language").font(.hs(14)).foregroundStyle(HS.textMuted)
                                Picker("", selection: Binding(get: { i18n.choice }, set: { i18n.setChoice($0) })) {
                                    ForEach(I18n.Choice.allCases) { c in
                                        D(c == .system ? tr(c.label) : c.label).tag(c)
                                    }
                                }
                                .pickerStyle(.segmented)
                                T("Automatic follows your iPhone's language.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                        SectionHeader(title: "Appearance").padding(.horizontal, -20).padding(.bottom, -8)
                        ThemeModeToggle()
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("Privacy").font(.hs(14)).foregroundStyle(HS.textMuted)
                                T("Your prayers, journal, cycle dates, Bible highlights and notes are stored only on this iPhone.")
                                    .foregroundStyle(HS.text)
                            }
                        }
                        Button(role: .destructive) { confirmErase = true } label: {
                            T("Erase all my data on this phone").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        T("HolySteps 1.0.0").font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert(tr("Erase all data?"), isPresented: $confirmErase) {
                Button(tr("Erase"), role: .destructive) {
                    store.prayers = []; store.journal = []; store.periodStarts = []
                    store.readDays = []; store.name = ""
                    BibleState.shared.eraseAll()
                    DevotionalState.shared.eraseAll()
                    SermonWeek.shared.eraseHeard()
                    QuizLog.shared.erase()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: { T("This removes your prayers, journal, cycle dates, reading streak, Bible highlights and notes from this phone.") }
        }
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
