import SwiftUI

/// Android's TraditionPracticeScreen and TraditionPracticeCard (FaithScreen.kt, AppState.kt): today's prayers from
/// the person's tradition. Catholic: the day's Rosary mysteries, the Hail Mary and a saint. Orthodox: the Jesus
/// Prayer with a count, the Trisagion and a saint. Protestant: the ACTS prayer. The saint rotates by day of the year;
/// it is a "Saint Spotlight", not a feast-day claim.
enum TraditionPractice {
    struct Saint { let name, title, fact: String }

    static func saintOfTheDay(_ saints: [Saint]) -> Saint {
        saints[Calendar.current.ordinality(of: .day, in: .year, for: Date())! % saints.count]
    }

    static let catholicSaints = [
        Saint(name: "St. Francis of Assisi", title: "Patron of Animals & Ecology", fact: "Founded the Franciscan order and lived a radical, joyful simplicity in love of all creation."),
        Saint(name: "St. Teresa of Calcutta", title: "Missionaries of Charity", fact: "Founded the Missionaries of Charity and served the poorest of the poor in the streets of Kolkata."),
        Saint(name: "St. Thérèse of Lisieux", title: "The Little Flower", fact: "Taught the \"Little Way\" — finding holiness in small, hidden acts of love."),
        Saint(name: "St. Augustine of Hippo", title: "Doctor of the Church", fact: "A skeptic turned bishop whose \"Confessions\" remain one of the most honest accounts of conversion ever written."),
        Saint(name: "St. Thomas Aquinas", title: "Doctor of the Church", fact: "A Dominican friar whose Summa Theologica still shapes how the Church reasons about faith."),
        Saint(name: "St. Joan of Arc", title: "Maid of Orléans", fact: "Led the French army as a teenager, trusting visions she believed came from God, and was martyred for her faith."),
        Saint(name: "St. Ignatius of Loyola", title: "Founder of the Jesuits", fact: "Wrote the Spiritual Exercises, still used today to discern God's will in daily life."),
        Saint(name: "St. Padre Pio", title: "Capuchin Friar", fact: "Known for his devotion to the Eucharist and for spending hours each day hearing confessions."),
        Saint(name: "St. Monica", title: "Mother of St. Augustine", fact: "Prayed for her son's conversion for nearly two decades before seeing it answered."),
        Saint(name: "St. John Paul II", title: "Pope for 27 Years", fact: "Traveled further than any pope before him, carrying the Gospel across the globe."),
        Saint(name: "St. Maximilian Kolbe", title: "Martyr of Charity", fact: "A Polish friar who offered his own life in a Nazi camp so a stranger with a family could live."),
        Saint(name: "St. Catherine of Siena", title: "Doctor of the Church", fact: "A mystic who fearlessly counseled popes and kings to pursue peace and reform."),
        Saint(name: "St. Benedict of Nursia", title: "Father of Western Monasticism", fact: "His Rule of balanced prayer and work still shapes monastic life 1,500 years later."),
        Saint(name: "St. Bernadette Soubirous", title: "Visionary of Lourdes", fact: "A poor, sickly teenager whose reported visions of Mary made Lourdes a place of healing pilgrimage."),
        Saint(name: "St. Faustina Kowalska", title: "Apostle of Divine Mercy", fact: "Spread devotion to the boundless mercy of God through her diary and the Divine Mercy image."),
        Saint(name: "St. Rose of Lima", title: "First Saint of the Americas", fact: "Devoted her life to prayer and care for the poor and sick in colonial Peru."),
    ]

    static let orthodoxSaints = [
        Saint(name: "St. John Chrysostom", title: "The Golden-Mouthed", fact: "An Archbishop of Constantinople so famed for his preaching that the Church's main Divine Liturgy bears his name."),
        Saint(name: "St. Basil the Great", title: "Bishop of Caesarea", fact: "Wrote a Divine Liturgy still served today and shaped the monastic rules of the Eastern Church."),
        Saint(name: "St. Gregory the Theologian", title: "Archbishop of Constantinople", fact: "Defended the doctrine of the Trinity with such clarity that the Church calls him simply \"the Theologian.\""),
        Saint(name: "St. Nicholas of Myra", title: "Wonderworker", fact: "A bishop so famed for quiet generosity that his legend became the basis for Santa Claus."),
        Saint(name: "St. Mary of Egypt", title: "Penitent of the Desert", fact: "Left a life of excess to spend decades alone in the desert in radical repentance and prayer."),
        Saint(name: "St. Seraphim of Sarov", title: "Russian Wonderworker", fact: "A monk known for his hesychastic prayer and the gentle counsel, \"Acquire a peaceful spirit.\""),
        Saint(name: "St. Xenia of St. Petersburg", title: "Fool for Christ", fact: "Gave away everything after her husband's sudden death and spent decades in humble, hidden service."),
        Saint(name: "St. Sergius of Radonezh", title: "Abbot of All Russia", fact: "Founded the Holy Trinity Lavra and became one of the most beloved spiritual fathers of Russia."),
        Saint(name: "St. Herman of Alaska", title: "Enlightener of North America", fact: "A missionary monk who defended and served the native peoples of Alaska with tireless love."),
        Saint(name: "St. Anthony the Great", title: "Father of Monks", fact: "Withdrew into the Egyptian desert to pray, becoming the model for Christian monasticism."),
        Saint(name: "St. Mary Magdalene", title: "Equal to the Apostles", fact: "The first witness of the Resurrection, honored as the \"Apostle to the Apostles.\""),
        Saint(name: "St. Nektarios of Aegina", title: "Wonderworker of Aegina", fact: "A bishop known for deep humility and for miracles of healing attributed to his intercession."),
        Saint(name: "St. Paisios of Mount Athos", title: "Elder of Athos", fact: "A 20th-century monk whose plain, practical spiritual counsel continues to guide pilgrims today."),
        Saint(name: "St. Catherine of Alexandria", title: "Great Martyr", fact: "An early martyr remembered for her wisdom and unshaken faith under persecution."),
    ]

    /// The usual weekly schedule: Joyful Monday and Saturday, Sorrowful Tuesday and Friday, Glorious Wednesday and
    /// Sunday, Luminous Thursday.
    static func rosaryToday() -> (name: String, meditations: [String]) {
        switch Calendar.current.component(.weekday, from: Date()) {
        case 2, 7: ("Joyful Mysteries", ["The Annunciation", "The Visitation", "The Nativity", "The Presentation in the Temple", "The Finding in the Temple"])
        case 3, 6: ("Sorrowful Mysteries", ["The Agony in the Garden", "The Scourging at the Pillar", "The Crowning with Thorns", "The Carrying of the Cross", "The Crucifixion"])
        case 4, 1: ("Glorious Mysteries", ["The Resurrection", "The Ascension", "The Descent of the Holy Spirit", "The Assumption of Mary", "The Coronation of Mary"])
        default: ("Luminous Mysteries", ["The Baptism in the Jordan", "The Wedding at Cana", "The Proclamation of the Kingdom", "The Transfiguration", "The Institution of the Eucharist"])
        }
    }

    static let hailMary = "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
    static let jesusPrayer = "Lord Jesus Christ, Son of God, have mercy on me, a sinner."
    static let trisagion = "Holy God, Holy Mighty, Holy Immortal, have mercy on us."
    static let acts: [(letter: String, title: String, prompt: String)] = [
        ("A", "Adoration", "Praise God for who He is — His character, His goodness, His worth, apart from anything He gives."),
        ("C", "Confession", "Be honest with God about where you've fallen short today. He already knows — naming it brings freedom."),
        ("T", "Thanksgiving", "Thank Him for three specific things from the last day — ordinary or extraordinary."),
        ("S", "Supplication", "Bring your real requests to Him — for yourself and for others who are on your heart."),
    ]
}

struct TraditionPracticeView: View {
    @State private var taps = 0
    private let tradition = Profile.tradition
    private var info: (String, String, String, String) { Profile.traditions.first { $0.0 == tradition } ?? Profile.traditions[3] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    D("\(info.1) \(tr("FAITH"))").font(.hs(12, .bold)).foregroundStyle(HS.peach)
                    D(tr("Your {0} practice").replacingOccurrences(of: "{0}", with: tr(info.2))).font(.hs(26, .heavy)).foregroundStyle(HS.text)
                        .accessibilityAddTraits(.isHeader)
                    T(tradition == "NON_DENOMINATIONAL" ? "Pick a tradition in Profile to get its daily prayers here." : "Today's prayers from your tradition.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                }
                switch tradition {
                case "CATHOLIC": catholic
                case "ORTHODOX": orthodox
                case "PROTESTANT": protestant
                default: EmptyView()
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Your practice"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var catholic: some View {
        let m = TraditionPractice.rosaryToday()
        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                D("\(tr("Today's Rosary")) — \(tr(m.name))").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                ForEach(Array(m.meditations.enumerated()), id: \.offset) { i, s in
                    D("\(i + 1). \(tr(s))").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                T("\"\(TraditionPractice.hailMary)\"").font(.hs(12).italic()).foregroundStyle(HS.textSecondary).padding(.top, 4)
                spotlight(TraditionPractice.saintOfTheDay(TraditionPractice.catholicSaints))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var orthodox: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("The Jesus Prayer").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                T("\"\(TraditionPractice.jesusPrayer)\"").font(.hs(13).italic()).foregroundStyle(HS.textSecondary)
                HStack {
                    VStack(alignment: .leading) {
                        T("Repetitions today").font(.hs(11)).foregroundStyle(HS.textMuted)
                        Text("\(taps)").font(.hs(22, .semibold)).foregroundStyle(HS.gold)
                    }
                    Spacer()
                    Button { taps += 1 } label: {
                        T("Pray it again").font(.hs(13, .semibold)).foregroundStyle(HS.onGold)
                            .padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(HS.goldButton))
                    }
                    .buttonStyle(.plain)
                }
                T("\"\(TraditionPractice.trisagion)\"").font(.hs(11).italic()).foregroundStyle(HS.textMuted)
                spotlight(TraditionPractice.saintOfTheDay(TraditionPractice.orthodoxSaints))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var protestant: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    T("Today's ACTS Prayer").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Adoration · Confession · Thanksgiving · Supplication").font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                ForEach(TraditionPractice.acts, id: \.letter) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(step.letter).font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                            .frame(width: 26, height: 26).background(Circle().fill(HS.goldButton.opacity(0.22)))
                        VStack(alignment: .leading, spacing: 2) {
                            T(step.title).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                            T(step.prompt).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func spotlight(_ s: TraditionPractice.Saint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            T("Saint Spotlight").font(.hs(11, .semibold)).foregroundStyle(HS.gold)
            D("\(s.name) · \(tr(s.title))").font(.hs(13, .semibold)).foregroundStyle(HS.text)
            T(s.fact).font(.hs(11)).foregroundStyle(HS.textMuted)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.28), lineWidth: 1))
        .padding(.top, 4)
    }
}
