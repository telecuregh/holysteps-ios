import SwiftUI
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

/// Apple's Journaling Suggestions (iOS 17.2+): the person picks a moment from their day (a walk, a place,
/// people, photos, music) and the journal starts a reflection from it. Apple shows the picker privately;
/// the app only sees the one moment chosen, and it stays on the phone.
struct JournalSuggestionButton: View {
    @Binding var draft: String

    var body: some View {
        #if canImport(JournalingSuggestions)
        if #available(iOS 17.2, *), Bundle.main.object(forInfoDictionaryKey: "HSJournalingEnabled") as? Bool ?? false {
            JournalingSuggestionsPicker {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    T("Reflect on a moment from your day").font(.hs(14, .semibold))
                }
                .foregroundStyle(HS.gold)
            } onCompletion: { suggestion in
                let when = suggestion.date.map { $0.start.formatted(.dateTime.weekday(.wide).hour().minute().locale(I18n.shared.locale)) }
                let head = [suggestion.title, when].compactMap { $0 }.joined(separator: " · ")
                draft = head + "\n" + tr("Where did I see God in this? What am I thankful for?") + "\n"
            }
        }
        #endif
    }
}
