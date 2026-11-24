import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
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
                                Text("First name").font(.subheadline).foregroundStyle(HS.textMuted)
                                TextField("Your first name", text: $store.name).textFieldStyle(.roundedBorder)
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Privacy").font(.subheadline).foregroundStyle(HS.textMuted)
                                Text("Your prayers, journal, and cycle dates are stored only on this iPhone.")
                                    .foregroundStyle(HS.text)
                            }
                        }
                        Button(role: .destructive) { confirmErase = true } label: {
                            Text("Erase all my data on this phone").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        Text("HolySteps 1.0.0").font(.footnote).foregroundStyle(HS.textMuted)
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Erase all data?", isPresented: $confirmErase) {
                Button("Erase", role: .destructive) {
                    store.prayers = []; store.journal = []; store.periodStarts = []
                    store.readDays = []; store.name = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes your prayers, journal, cycle dates and reading streak from this phone.") }
        }
    }
}
