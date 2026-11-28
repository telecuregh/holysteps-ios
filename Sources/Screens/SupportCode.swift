import SwiftUI

/// Android's "Calling HolySteps support?" card (ProfileScreen SupportCodeCard, POST /holysteps/api/support-code):
/// a one-time 6-digit code to read out on a call, so support knows it's really you. Works once, for 15 minutes.
struct SupportCodeCard: View {
    private struct Code { let code: String; let expiresAt: Date; let number: Int }
    @State private var code: Code?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                if let c = code, c.expiresAt > Date() {
                    T("Read this to the person helping you:").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    D(stride(from: 0, to: c.code.count, by: 3).map { i in
                        String(c.code.dropFirst(i).prefix(3)) }.joined(separator: " "))
                        .font(.system(size: 34, weight: .bold)).tracking(4).foregroundStyle(HS.text)
                        .accessibilityLabel(c.code.map(String.init).joined(separator: " "))
                    if c.number > 0 { D(tr("Member #") + c.number.formatted()).font(.hs(15, .semibold)).foregroundStyle(HS.faith) }
                    D(tr("Works once, until {0}. HolySteps will never ask for your password.")
                        .replacingOccurrences(of: "{0}", with: c.expiresAt.formatted(date: .omitted, time: .shortened)))
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                } else {
                    T("On a call with HolySteps? Get a one-time code to read out, so we know it's really you.").font(.hs(14)).foregroundStyle(HS.textSecondary)
                }
                if let e = error { D(e).font(.hs(13)).foregroundStyle(Color(hex: 0xEF4444)) }
                Button { Task { await fetch() } } label: {
                    T(busy ? "Getting a code…" : code != nil ? "Get a new code" : "Get a support code").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.faith.opacity(0.16)))
                }
                .buttonStyle(.plain).disabled(busy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fetch() async {
        busy = true; error = nil
        defer { busy = false }
        for attempt in 0..<2 {
            guard let tok = await AccountStore.shared.token(force: attempt == 1),
                  let url = URL(string: AppLinks.site + "/holysteps/api/support-code") else { break }
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.httpBody = Data("{}".utf8)
            guard let (data, resp) = try? await URLSession.shared.data(for: req) else { break }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 && attempt == 0 { continue }
            guard (200..<300).contains(status), let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let c = j["code"] as? String, c.count == 6 else { break }
            let exp = (j["expiresAt"] as? NSNumber)?.doubleValue ?? 0
            code = Code(code: c, expiresAt: Date(timeIntervalSince1970: exp / 1000), number: (j["number"] as? NSNumber)?.intValue ?? 0)
            return
        }
        error = tr("Couldn't get a code. Check you're online and try again.")
    }
}
