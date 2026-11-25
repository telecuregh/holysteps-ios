import SwiftUI

/// Android's WebPlansPaywall: why this is locked, Complete first, then each plan, family and couple, the free week
/// and "I have a code". Payment happens on holysteps.org; the plan switches on here by itself once paid.
struct PlansView: View {
    var feature: Feature? = nil
    @ObservedObject private var account = AccountStore.shared
    @ObservedObject private var prices = StorePrices.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var yearly = true
    @State private var busy: String?
    @State private var note: String?
    @State private var showRedeem = false

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        T(headline).font(.hs(24, .semibold)).foregroundStyle(HS.text)
                        T("After you pay, your plan switches on here by itself.").font(.hs(14)).foregroundStyle(HS.textSecondary)
                        if let note { D(note).font(.hs(13)).foregroundStyle(HS.peach) }

                        Picker("", selection: $yearly) {
                            D(tr("Monthly")).tag(false)
                            D(tr("Yearly")).tag(true)
                        }.pickerStyle(.segmented)

                        completeCard
                        T("Or just the plan you use").font(.hs(15, .semibold)).foregroundStyle(HS.textSecondary).padding(.top, 4)
                        ForEach(orderedPlans) { planCard($0) }
                        if let c = prices.item("couple_yearly") { simpleCard(c, "Best for couples", "Cycle for her and Wellness for him, with partner coaching") }
                        if let f = prices.item("family_yearly") { simpleCard(f, "Family", "All four plans for everyone in your home") }

                        if account.trialOpen { trialCard }
                        Button { showRedeem = true } label: {
                            T("Have a license key or QR code?").font(.hs(15, .semibold)).foregroundStyle(HS.gold).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        T("Plans are paid by card on holysteps.org (secure checkout by Stripe) and renew until you cancel. Cancel anytime at holysteps.org/manage and keep your plan to the end of the time you've paid for. Free forever: steps and walks, the daily devotional, reading the prayer wall, hymns and worship songs, Freedom support, period tracking, a safety circle with SOS. Groups, duels and circles come with any plan; your church with Complete.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    .padding(20)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { dismiss() } } }
            .sheet(isPresented: $showRedeem) { RedeemSheet() }
            .task { await prices.refresh() }
            .onChange(of: phase) { _, p in if p == .active { Task { await account.refreshAccount(); if let feature, account.canUse(feature) { dismiss() } } } }
        }
    }

    private var headline: String { feature?.lockMessage ?? "Choose what you need" }

    private var orderedPlans: [Plan] {
        guard let s = feature?.suggestedPlan else { return Plan.allCases }
        return [s] + Plan.allCases.filter { $0 != s }
    }

    private var completeCard: some View {
        let id = yearly ? "complete_yearly" : "complete_monthly"
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T("HolySteps Complete").font(.hs(20, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    T("Best value").font(.hs(11, .semibold)).foregroundStyle(HS.onGold).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(HS.goldButton))
                }
                T("All four plans, working together").font(.hs(13)).foregroundStyle(HS.textSecondary)
                ForEach(Plan.everyPlanPerks, id: \.self) { bullet($0) }
                priceLine(id)
                buy(id)
                if yearly, let two = prices.item("complete_2yr") {
                    Button { checkout(two.id) } label: {
                        D(tr("Or 2 years for") + " " + two.priceText).font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                    }
                }
            }
        }
    }

    private func planCard(_ p: Plan) -> some View {
        let id = "\(p.rawValue)_\(yearly ? "yearly" : "monthly")"
        let running = account.runningPlans.contains(p)
        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    D(p.emoji + " " + tr(p.name)).font(.hs(18, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    if running { T("Active").font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                }
                T(p.tagline).font(.hs(13)).foregroundStyle(HS.textSecondary)
                ForEach(p.features.prefix(feature?.suggestedPlan == p ? 99 : 4), id: \.self) { bullet($0) }
                priceLine(id)
                if !running { buy(id) }
            }
        }
    }

    private func simpleCard(_ item: StoreItem, _ title: String, _ sub: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T(title).font(.hs(18, .semibold)).foregroundStyle(HS.text)
                T(sub).font(.hs(13)).foregroundStyle(HS.textSecondary)
                priceLine(item.id)
                buy(item.id)
            }
        }
    }

    private var trialCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("Try everything free for 7 days").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                T("All four plans. No card, nothing to cancel: after a week you're simply back on the free app, with everything you saved.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                GoldButton(title: busy == "trial" ? "Starting…" : "Start my free week") {
                    busy = "trial"
                    Task { note = await account.startTrial(); busy = nil }
                }.disabled(busy != nil)
            }
        }
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(HS.gold).padding(.top, 3).accessibilityHidden(true)
            T(s).font(.hs(13)).foregroundStyle(HS.text)
        }
    }

    @ViewBuilder private func priceLine(_ id: String) -> some View {
        if let i = prices.item(id) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                D(i.priceText).font(.hs(24, .semibold)).foregroundStyle(HS.text)
                D(i.per).font(.hs(13)).foregroundStyle(HS.textSecondary)
                if i.listPrice > i.price { D(String(format: "$%.2f", i.listPrice)).font(.hs(13)).strikethrough().foregroundStyle(HS.textMuted) }
            }
        }
    }

    private func buy(_ id: String) -> some View {
        GoldButton(title: busy == id ? "Opening checkout…" : "Finish on our website") { checkout(id) }.disabled(busy != nil)
    }

    private func checkout(_ id: String) {
        busy = id
        Task {
            let (url, why) = await account.checkoutURL(planId: id)
            note = why
            busy = nil
            openURL(url)
        }
    }
}

struct RedeemSheet: View {
    @ObservedObject private var account = AccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var error: String?
    @State private var busy = false
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("License code"), text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                } footer: {
                    if done { T("Your plan is on. Thank you!") } else if let error { D(error).foregroundStyle(.red) }
                    else { T("Codes come by email after you pay on holysteps.org, or from your church or family plan.") }
                }
            }
            .navigationTitle(tr("I have a code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr(done ? "Done" : "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Redeem")) {
                        busy = true
                        Task { error = await account.redeem(code); done = error == nil; busy = false }
                    }.disabled(busy || done || code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Android's Account screen: plan, end date, manage on the website, code, restore by code, and the account ID.
struct AccountView: View {
    @ObservedObject private var account = AccountStore.shared
    @Environment(\.openURL) private var openURL
    @State private var showPlans = false
    @State private var showRedeem = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("Your plan").font(.hs(13)).foregroundStyle(HS.textSecondary)
                            D(tr(account.planName)).font(.hs(24, .semibold)).foregroundStyle(HS.text)
                            if let end = account.latestEnd {
                                D(tr("Renews or ends on") + " " + end.formatted(date: .long, time: .omitted)).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    GoldButton(title: account.hasAnyPlan ? "Change plan" : "See plans") { showPlans = true }
                    if account.hasAnyPlan {
                        Button { openURL(URL(string: AccountStore.site + "/manage")!) } label: {
                            T("Manage or cancel on holysteps.org").font(.hs(15, .semibold)).foregroundStyle(HS.gold).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                    }
                    Button { showRedeem = true } label: {
                        T("I have a code").font(.hs(15, .semibold)).foregroundStyle(HS.gold).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    if let uid = account.uid {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("Account ID").font(.hs(13)).foregroundStyle(HS.textSecondary)
                                D(uid).font(.system(size: 13, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                                T("Share this only with HolySteps support if they ask for it.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                    if !account.status.isEmpty { D(account.status).font(.hs(13)).foregroundStyle(HS.peach) }
                }
                .padding(20)
            }
        }
        .navigationTitle(tr("Plan and account"))
        .sheet(isPresented: $showPlans) { PlansView() }
        .sheet(isPresented: $showRedeem) { RedeemSheet() }
        .task { await account.refreshAccount() }
    }
}

/// Shows the content when this person's plan covers the feature, otherwise a premium lock card that opens the plans.
struct Gated<Content: View>: View {
    let feature: Feature
    @ViewBuilder var content: () -> Content
    @ObservedObject private var account = AccountStore.shared
    @State private var showPlans = false

    var body: some View {
        if account.canUse(feature) {
            content()
        } else {
            PremiumLockCard(feature: feature) { showPlans = true }
                .sheet(isPresented: $showPlans) { PlansView(feature: feature) }
        }
    }
}

/// Premium paywall card shown whenever a Gated feature is locked.
struct PremiumLockCard: View {
    let feature: Feature
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x251810), Color(hex: 0x180F08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            RadialGradient(
                colors: [Color(hex: 0xD9B49F).opacity(0.14), .clear],
                center: .topLeading, startRadius: 0, endRadius: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xD9B49F).opacity(0.14))
                            .frame(width: 52, height: 52)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: 0xD9B49F))
                    }
                    Spacer()
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xD9B49F))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xD9B49F).opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color(hex: 0xD9B49F).opacity(0.3), lineWidth: 1))
                        .padding(.top, 4)
                }

                T(feature.lockMessage)
                    .font(.hs(16, .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    perk("Unlimited access, no interruptions")
                    perk("Synced across all your devices")
                    perk("New features added every month")
                }

                Button(action: onUnlock) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill").font(.system(size: 12))
                        T("Unlock now").font(.hs(15, .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x180F08))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LinearGradient(
                        colors: [Color(hex: 0xE8C4A0), Color(hex: 0xC99872)],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private func perk(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xD9B49F))
            T(text).font(.hs(13)).foregroundStyle(Color.white.opacity(0.75))
        }
    }
}
