import SwiftUI

/// Android's InviteLinks and JoinInviteScreen: an invite opened from a link (https://holysteps.org/join?c=CODE, or
/// holysteps://join?c=CODE from the join page's "Open in HolySteps" button) says what it is for and joins only when the
/// person taps Join, so a link alone never adds anyone to anything. The code is then filled in on that feature's screen.
enum InviteInbox {
    struct Invite: Hashable { let code: String; let kind: String }

    static let prefixes: Set<String> = ["FAITH", "RELAY", "LINK", "CIRCLE", "HABIT", "PAIR", "READ", "CHURCH"]
    static let kinds: Set<String> = ["safety", "baby"]

    /// The invite inside one of our links, checked the same way as Android (InviteLinks.parse / validate).
    static func parse(_ url: URL) -> Invite? {
        let ours = (url.scheme == "holysteps" && url.host == "join")
            || (url.scheme == "https" && url.host?.lowercased() == "holysteps.org" && (url.path == "/join" || url.path == "/join/"))
        guard ours, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let code = (items.first { $0.name.lowercased() == "c" }?.value ?? "").trimmingCharacters(in: .whitespaces)
        let rawKind = items.first { $0.name.lowercased() == "t" }?.value?.trimmingCharacters(in: .whitespaces).lowercased()
        return validate(code: code, kind: rawKind)
    }

    static func validate(code: String, kind: String?) -> Invite? {
        guard code.range(of: "^[A-Za-z0-9-]{6,80}$", options: .regularExpression) != nil else { return nil }
        let prefix = code.contains("-") ? String(code.prefix { $0 != "-" }).uppercased() : ""
        if prefixes.contains(prefix) { return Invite(code: code.uppercased(), kind: prefix) }
        if let kind, kinds.contains(kind) { return Invite(code: code, kind: kind) }
        return nil
    }

    /// The invite whose Join was tapped, waiting for its screen to fill the code in once.
    private static var pending: Invite?
    static func hold(_ i: Invite) { pending = i }
    /// Whether a code of this kind is waiting (without taking it).
    static func waiting(_ kind: String) -> Bool { pending?.kind == kind }
    /// The waiting code for this kind of invite, or "" (and it is only given out once).
    static func take(_ kind: String) -> String {
        guard let p = pending, p.kind == kind else { return "" }
        pending = nil
        return p.code
    }
}

struct JoinInviteView: View {
    let invite: InviteInbox.Invite?
    @Environment(\.dismiss) private var dismiss
    @State private var go = false

    private var what: (String, String) {
        switch invite?.kind ?? "" {
        case "FAITH": ("a faith league", "🏆")
        case "RELAY": ("a family faith relay", "🔥")
        case "LINK": ("partner coaching", "💞")
        case "CIRCLE": ("a cycle circle", "💗")
        case "HABIT": ("a habit circle", "🤝")
        case "PAIR": ("an accountability partnership", "🛡️")
        case "READ": ("a Bible reading group", "📖")
        case "CHURCH": ("a church", "⛪")
        case "safety": ("a safety circle", "🧭")
        case "baby": ("a shared baby log", "👶")
        default: ("", "✉️")
        }
    }

    /// Invites for something the iPhone app doesn't have yet.
    private var notOnIPhone: Bool { false }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 12) {
                Text(what.1).font(.system(size: 52))
                if let invite {
                    D(tr("You're invited to {0}").replacingOccurrences(of: "{0}", with: tr(what.0)))
                        .font(.hs(20, .bold)).foregroundStyle(HS.text).multilineTextAlignment(.center)
                    Text(invite.code).font(.system(size: 15, design: .monospaced)).foregroundStyle(HS.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.08)))
                    if notOnIPhone {
                        T("This kind of invite isn't on iPhone yet. Open it on an Android phone with HolySteps.")
                            .font(.hs(14)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                        Button { dismiss() } label: { T("Close").font(.hs(15)).foregroundStyle(HS.peach) }.frame(minHeight: 48)
                    } else {
                        T("Only join if you know who sent this.").font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                        GoldButton(title: "Join") { InviteInbox.hold(invite); go = true }.padding(.top, 10)
                        Button { dismiss() } label: { T("Not now").font(.hs(15)).foregroundStyle(HS.textMuted) }.frame(minHeight: 48)
                    }
                } else {
                    T("This invite link isn't complete").font(.hs(20, .bold)).foregroundStyle(HS.text).multilineTextAlignment(.center)
                    T("Ask the person who invited you to send it again.").font(.hs(14)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                    Button { dismiss() } label: { T("Back").font(.hs(15)).foregroundStyle(HS.peach) }.frame(minHeight: 48)
                }
            }
            .padding(24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $go) { destination }
    }

    /// The feature's own screen, where the code is already filled in and the person confirms with their name.
    @ViewBuilder private var destination: some View {
        switch invite?.kind ?? "" {
        case "FAITH": FaithGroupsView()
        case "RELAY": FamilyRelayView()
        case "LINK": PartnerCoachingView()
        case "CIRCLE": CycleCirclesView()
        case "HABIT": CirclesView()
        case "READ": ReadingTogetherView()
        case "CHURCH": ChurchTab()
        case "safety": SafetyCircleView()
        case "PAIR": AccountabilityPartnerView()
        case "baby": BabyView()
        default: EmptyView()
        }
    }
}
