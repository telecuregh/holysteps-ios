import Foundation

/// Grace reads everything the app says aloud. The phone's own voice is never used: when a recording isn't there,
/// the caption stays on screen and nothing is spoken.
@MainActor
enum GraceVoice {
    private static let clip = ClipPlayer()

    /// Plays Grace's recording of `text` from the pack `packId` ("coach_cues", "prayer_guide", "stories"…).
    /// Returns false when there is no recording (offline on first use, or a line she hasn't recorded).
    @discardableResult
    static func say(_ text: String, pack packId: String) async -> Bool {
        let spanish = I18n.shared.spanish
        guard let p = await VoicePacks.shared.ensure(voice: spanish ? "es_heart" : "af_heart", packId: packId) else { return false }
        guard let d = (spanish ? p.audio(for: tr(text)) : nil) ?? p.audio(for: text) else { return false }
        return await clip.play(d)
    }

    static func stop() { clip.stop() }
}
