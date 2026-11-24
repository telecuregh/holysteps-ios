import SwiftUI

struct CycleView: View {
    @EnvironmentObject var store: AppStore
    @State private var date = Date()

    private var fmt: DateFormatter { let f = DateFormatter(); f.locale = I18n.shared.locale; f.dateStyle = .medium; return f }

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenPhoto(name: store.gender == "male" ? "screen_wellness_men" : "screen_cycle").padding(.horizontal, -20).padding(.top, -20)
                        ScreenTitle(text: "Cycle")
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("Next period (estimate)").font(.hs(14)).foregroundStyle(HS.textMuted)
                                if let next = store.nextPeriodEstimate, let len = store.averageCycleLength {
                                    Text(fmt.string(from: next)).font(.hs(26, .semibold)).foregroundStyle(HS.cycle)
                                    T("Based on your average cycle of \(len) days. Cycles vary, so treat this as a rough guide.")
                                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                                } else {
                                    T("Log at least two period start dates to see an estimate.")
                                        .foregroundStyle(HS.textSecondary)
                                }
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("Log a period start").font(.hs(14)).foregroundStyle(HS.textMuted)
                                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden().datePickerStyle(.compact)
                                GoldButton(title: "Save") {
                                    let day = Calendar.current.startOfDay(for: date)
                                    if !store.periodStarts.contains(day) { store.periodStarts.append(day) }
                                }
                            }
                        }
                        if !store.periodStarts.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    T("History").font(.hs(14)).foregroundStyle(HS.textMuted)
                                    ForEach(store.periodStarts.sorted(by: >), id: \.self) { d in
                                        HStack {
                                            Text(fmt.string(from: d)).foregroundStyle(HS.text)
                                            Spacer()
                                            Button(role: .destructive) {
                                                store.periodStarts.removeAll { $0 == d }
                                            } label: { Image(systemName: "trash") }
                                        }
                                    }
                                }
                            }
                        }
                        T("HolySteps is not a medical device. Talk to a doctor about heavy bleeding, severe pain, or missed periods.")
                            .font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    .padding(20)
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
