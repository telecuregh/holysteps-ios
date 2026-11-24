import Foundation

struct Verse: Identifiable {
    let id: Int
    let ref: String
    let text: String
    /// The same verse in the Reina-Valera 1909 (RVES), shown when the app is in Spanish.
    let es: String
    var shown: String { I18n.shared.spanish ? es : text }
}

/// A small set of public-domain verses (KJV, with the Reina-Valera 1909 in Spanish) for the daily verse. The full Bible reader is a later step.
enum AppContent {
    static let verses: [Verse] = [
        Verse(id: 0, ref: "Psalm 46:10", text: "Be still, and know that I am God.", es: "Estad quietos, y conoced que yo soy Dios."),
        Verse(id: 1, ref: "Proverbs 3:5", text: "Trust in the LORD with all thine heart; and lean not unto thine own understanding.", es: "Fíate de Jehová de todo tu corazón, y no estribes en tu prudencia."),
        Verse(id: 2, ref: "Isaiah 41:10", text: "Fear thou not; for I am with thee: be not dismayed; for I am thy God.", es: "No temas, que yo soy contigo; no desmayes, que yo soy tu Dios que te esfuerzo."),
        Verse(id: 3, ref: "Philippians 4:13", text: "I can do all things through Christ which strengtheneth me.", es: "Todo lo puedo en Cristo que me fortalece."),
        Verse(id: 4, ref: "Psalm 23:1", text: "The LORD is my shepherd; I shall not want.", es: "Jehová es mi pastor; nada me faltará."),
        Verse(id: 5, ref: "Joshua 1:9", text: "Be strong and of a good courage; be not afraid, neither be thou dismayed.", es: "Mira que te mando que te esfuerces y seas valiente: no temas ni desmayes."),
        Verse(id: 6, ref: "Matthew 11:28", text: "Come unto me, all ye that labour and are heavy laden, and I will give you rest.", es: "Venid á mí todos los que estáis trabajados y cargados, que yo os haré descansar."),
        Verse(id: 7, ref: "Romans 8:28", text: "And we know that all things work together for good to them that love God.", es: "Y sabemos que á los que á Dios aman, todas las cosas les ayudan á bien."),
        Verse(id: 8, ref: "Psalm 121:1-2", text: "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the LORD.", es: "Alzaré mis ojos á los montes, de donde vendrá mi socorro. Mi socorro viene de Jehová."),
        Verse(id: 9, ref: "Jeremiah 29:11", text: "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil.", es: "Porque yo sé los pensamientos que tengo acerca de vosotros, dice Jehová, pensamientos de paz, y no de mal."),
        Verse(id: 10, ref: "John 14:27", text: "Peace I leave with you, my peace I give unto you.", es: "La paz os dejo, mi paz os doy."),
        Verse(id: 11, ref: "Galatians 6:9", text: "And let us not be weary in well doing: for in due season we shall reap, if we faint not.", es: "No nos cansemos, pues, de hacer bien; que á su tiempo segaremos, si no hubiéremos desmayado.")
    ]

    static func verseOfTheDay(_ date: Date = Date()) -> Verse {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return verses[day % verses.count]
    }

    static let prayerPrompts = [
        "Thank God for three things from today.",
        "Pray for someone who is struggling right now.",
        "Ask for peace over what you cannot control.",
        "Pray for your family by name.",
        "Confess something you have been carrying, and receive grace."
    ]
}
