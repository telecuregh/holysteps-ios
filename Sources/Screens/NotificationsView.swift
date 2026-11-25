import SwiftUI
import UserNotifications

/// The notifications inbox behind the bell on Home: what HolySteps has sent (kept on the phone for 30 days, even after
/// they're cleared from Notification Center) and the reminders coming up. Nothing leaves the phone.
@MainActor
final class NotificationInbox: ObservableObject {
    static let shared = NotificationInbox()

    struct Item: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let body: String
        let date: Date
    }
    struct Upcoming: Identifiable { let id: String; let title: String; let body: String; let date: Date? }

    @Published private(set) var items: [Item] = []
    @Published private(set) var upcoming: [Upcoming] = []
    @Published private(set) var lastSeen: Date

    private static let key = "notificationInbox", seenKey = "notificationInboxSeen"
    var unseen: Int { items.filter { $0.date > lastSeen }.count }

    private init() {
        lastSeen = UserDefaults.standard.object(forKey: Self.seenKey) as? Date ?? .distantPast
        if let d = UserDefaults.standard.data(forKey: Self.key), let saved = try? JSONDecoder().decode([Item].self, from: d) { items = saved }
    }

    /// Adds what Notification Center holds now and reads the scheduled reminders.
    func refresh() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        var byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for n in delivered {
            let c = n.request.content
            guard !c.title.isEmpty || !c.body.isEmpty else { continue }
            let id = n.request.identifier + "|" + String(Int(n.date.timeIntervalSince1970))
            byId[id] = Item(id: id, title: c.title, body: c.body, date: n.date)
        }
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        items = byId.values.filter { $0.date > cutoff }.sorted { $0.date > $1.date }.prefix(100).map { $0 }
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: Self.key) }

        let pending = await center.pendingNotificationRequests()
        upcoming = pending.compactMap { r in
            let c = r.content
            guard !c.title.isEmpty || !c.body.isEmpty else { return nil }
            let next = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (r.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
            return Upcoming(id: r.identifier, title: c.title, body: c.body, date: next)
        }
        .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    func markSeen() {
        lastSeen = Date()
        UserDefaults.standard.set(lastSeen, forKey: Self.seenKey)
    }

    func clear() {
        items = []
        UserDefaults.standard.removeObject(forKey: Self.key)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

struct NotificationsView: View {
    @ObservedObject private var inbox = NotificationInbox.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var allowed: UNAuthorizationStatus = .authorized
    @State private var seenBefore = Date.distantPast

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if allowed == .denied {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    T("Notifications are off").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    T("Turn them on to get your sermon, bedtime and recap reminders.").font(.hs(13)).foregroundStyle(HS.textMuted)
                                    GoldButton(title: "Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                                }
                            }
                        }
                        if inbox.items.isEmpty && inbox.upcoming.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "bell").font(.system(size: 34)).foregroundStyle(HS.gold)
                                T("You're all caught up").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                                T("Reminders HolySteps sends you will show here.").font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 60)
                        }
                        if !inbox.items.isEmpty {
                            SectionHeader(title: "Recent").padding(.horizontal, -20)
                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(inbox.items) { n in row(n.title, n.body, n.date, new: n.date > seenBefore) }
                                }
                            }
                        }
                        if !inbox.upcoming.isEmpty {
                            SectionHeader(title: "Coming up").padding(.horizontal, -20)
                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(inbox.upcoming) { n in row(n.title, n.body, n.date, new: false, upcoming: true) }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(tr("Notifications")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { dismiss() } }
                if !inbox.items.isEmpty {
                    ToolbarItem(placement: .confirmationAction) { Button(tr("Clear")) { inbox.clear() } }
                }
            }
        }
        .task {
            seenBefore = inbox.lastSeen
            await inbox.refresh()
            allowed = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            inbox.markSeen()
        }
    }

    private func row(_ title: String, _ body: String, _ date: Date?, new: Bool, upcoming: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: upcoming ? "clock" : "bell.fill").font(.system(size: 14)).foregroundStyle(HS.gold)
                .frame(width: 30, height: 30).background(Circle().fill(HS.overlay(0.07)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if new { Circle().fill(HS.goldButton).frame(width: 7, height: 7).accessibilityLabel(tr("New")) }
                    if !title.isEmpty { D(title).font(.hs(14, .semibold)).foregroundStyle(HS.text) }
                }
                if !body.isEmpty { D(body).font(.hs(13)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true) }
                if let date {
                    D(upcoming ? date.formatted(.dateTime.weekday(.wide).hour().minute().locale(I18n.shared.locale))
                               : date.formatted(.relative(presentation: .named).locale(I18n.shared.locale)))
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
