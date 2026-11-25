import SwiftUI

/// The daily verses (KJV, with the Reina-Valera 1909 in Spanish), shared by the app and the verse widget.
struct DailyVerse: Hashable {
    let id: Int
    let ref: String
    let text: String
    let es: String
}

enum DailyVerses {
    static let all: [DailyVerse] = [
        DailyVerse(id: 0, ref: "Psalm 46:10", text: "Be still, and know that I am God.", es: "Estad quietos, y conoced que yo soy Dios."),
        DailyVerse(id: 1, ref: "Proverbs 3:5", text: "Trust in the LORD with all thine heart; and lean not unto thine own understanding.", es: "Fíate de Jehová de todo tu corazón, y no estribes en tu prudencia."),
        DailyVerse(id: 2, ref: "Isaiah 41:10", text: "Fear thou not; for I am with thee: be not dismayed; for I am thy God.", es: "No temas, que yo soy contigo; no desmayes, que yo soy tu Dios que te esfuerzo."),
        DailyVerse(id: 3, ref: "Philippians 4:13", text: "I can do all things through Christ which strengtheneth me.", es: "Todo lo puedo en Cristo que me fortalece."),
        DailyVerse(id: 4, ref: "Psalm 23:1", text: "The LORD is my shepherd; I shall not want.", es: "Jehová es mi pastor; nada me faltará."),
        DailyVerse(id: 5, ref: "Joshua 1:9", text: "Be strong and of a good courage; be not afraid, neither be thou dismayed.", es: "Mira que te mando que te esfuerces y seas valiente: no temas ni desmayes."),
        DailyVerse(id: 6, ref: "Matthew 11:28", text: "Come unto me, all ye that labour and are heavy laden, and I will give you rest.", es: "Venid á mí todos los que estáis trabajados y cargados, que yo os haré descansar."),
        DailyVerse(id: 7, ref: "Romans 8:28", text: "And we know that all things work together for good to them that love God.", es: "Y sabemos que á los que á Dios aman, todas las cosas les ayudan á bien."),
        DailyVerse(id: 8, ref: "Psalm 121:1-2", text: "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the LORD.", es: "Alzaré mis ojos á los montes, de donde vendrá mi socorro. Mi socorro viene de Jehová."),
        DailyVerse(id: 9, ref: "Jeremiah 29:11", text: "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil.", es: "Porque yo sé los pensamientos que tengo acerca de vosotros, dice Jehová, pensamientos de paz, y no de mal."),
        DailyVerse(id: 10, ref: "John 14:27", text: "Peace I leave with you, my peace I give unto you.", es: "La paz os dejo, mi paz os doy."),
        DailyVerse(id: 11, ref: "Galatians 6:9", text: "And let us not be weary in well doing: for in due season we shall reap, if we faint not.", es: "No nos cansemos, pues, de hacer bien; que á su tiempo segaremos, si no hubiéremos desmayado.")
    ]
    static func forDay(_ date: Date = Date()) -> DailyVerse {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return all[day % all.count]
    }
    /// Spanish book names for the references (the widget can't use the app's translation table).
    static func spanishRef(_ ref: String) -> String {
        let books = ["Psalm": "Salmo", "Proverbs": "Proverbios", "Isaiah": "Isaías", "Philippians": "Filipenses", "Joshua": "Josué",
                     "Matthew": "Mateo", "Romans": "Romanos", "Jeremiah": "Jeremías", "John": "Juan", "Galatians": "Gálatas"]
        guard let sp = ref.lastIndex(of: " ") else { return ref }
        let book = String(ref[..<sp])
        return (books[book] ?? book) + ref[sp...]
    }
}

/// The Navy Glass verse design (picked Nov 25, 2026): deep navy with a soft blue and gold glow, a frosted glass card
/// with a thin gold edge, the verse in Playfair italic, the reference in gold and the HolySteps wordmark. Used for
/// the shared verse image and the home-screen widgets.
enum NavyGlass {
    static let navy = Color(red: 11 / 255, green: 21 / 255, blue: 48 / 255)
    static let gold = Color(red: 222 / 255, green: 190 / 255, blue: 130 / 255)
    static let ink = Color(red: 244 / 255, green: 236 / 255, blue: 221 / 255)
}

/// The background: navy with a blue glow top-left and a gold glow bottom-right.
struct NavyGlassBackground: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                NavyGlass.navy
                Circle().fill(Color(red: 43 / 255, green: 74 / 255, blue: 140 / 255)).opacity(0.55)
                    .frame(width: w * 0.78, height: w * 0.78).blur(radius: w * 0.17)
                    .position(x: w * 0.13, y: h * 0.05)
                Circle().fill(Color(red: 199 / 255, green: 154 / 255, blue: 82 / 255)).opacity(0.28)
                    .frame(width: w * 0.67, height: w * 0.67).blur(radius: w * 0.18)
                    .position(x: w * 0.98, y: h * 0.97)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The glass card holding the verse. `scale` 1 is the 540-point-wide design.
struct NavyGlassVerseCard: View {
    let header: String
    let text: String
    let ref: String
    var scale: CGFloat = 1
    var verseSize: CGFloat = 30
    var showFooter = true

    var body: some View {
        VStack(spacing: 26 * scale) {
            if !header.isEmpty {
                Text(header).font(.custom("Inter-SemiBold", size: 11 * scale)).tracking(4 * scale).foregroundStyle(NavyGlass.gold)
            }
            Text("“\(text)”").font(.custom("PlayfairDisplay-Italic", size: verseSize * scale)).lineSpacing(verseSize * scale * 0.3)
                .foregroundStyle(NavyGlass.ink).multilineTextAlignment(.center).minimumScaleFactor(0.4)
            if showFooter {
                Rectangle().fill(NavyGlass.gold.opacity(0.35)).frame(height: 1)
                HStack {
                    Text(ref).font(.custom("Inter-SemiBold", size: 14 * scale)).foregroundStyle(NavyGlass.gold).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 8)
                    Text("HOLYSTEPS").font(.custom("Inter-SemiBold", size: 11 * scale)).tracking(3 * scale).foregroundStyle(NavyGlass.ink.opacity(0.7))
                }
            }
        }
        .padding(.top, 48 * scale).padding(.horizontal, 40 * scale).padding(.bottom, 40 * scale)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24 * scale).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 24 * scale).strokeBorder(NavyGlass.gold.opacity(0.6), lineWidth: 1))
    }
}
