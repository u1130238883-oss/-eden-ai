import Foundation

/// 十二宮在「好／正／壞」判讀下的具體表現（依 Hollow 十二宮關鍵詞整理）。
/// 中文最細；外語用較短的說法。
public enum PalaceLore {
    /// [宮-1][好, 正, 壞]
    static let zh: [[String]] = [
        ["自我狀態好，行動力強，敢表達自己的想法。", "情緒平穩，按自己的步調做事。", "容易煩躁、衝動、上火，說話前先停三秒，別傷到人也別傷到自己。"],
        ["收入和物質上比較順，有機會買到想要的東西，價值觀也清楚。", "收支平穩，花錢有節制就好。", "開銷變大、錢不太聽話，也要留意口腔和飲食，別衝動消費。"],
        ["溝通順、腦袋靈活，學習和談事情都有收穫，身邊同輩會幫你。", "交流照常，想法多但不亂。", "容易說錯話、想太多、跟同事或兄弟姊妹有摩擦，重要的事寫下來再說。"],
        ["家裡和睦、住得安心，內心有安全感。", "家庭平穩，偶爾會想東想西。", "不安全感上來、容易焦慮內耗，家裡的事比較多，給自己一個安靜的角落。"],
        ["人緣好、被看見，桃花和娛樂都旺，適合表現自己。", "有些小快樂，感情平平。", "容易為了被關注而用力過猛、感情波折或享樂過頭，量力而為。"],
        ["雖然忙但忙得有成果，社交和日常事務處理得很順。", "日常瑣事多，照清單一件件做。", "瑣事纏身、思緒亂、心累，容易被議論，先把最重要的一件事做完。"],
        ["遇到的人對你有幫助，伴侶和一對一的關係是助力。", "人際平穩，心思常放在別人身上。", "太在意別人、關係裡有拉扯或羈絆，先照顧好自己的界線。"],
        ["可能有意外之財或別人的資源幫你，身體狀況也穩。", "偶爾孤單無聊，但撐得過去。", "容易孤獨、煎熬、覺得時間很漫長，留意身體與金錢往來，別一個人硬撐。"],
        ["心情樂觀、運氣好，出遠門、文件、信仰相關的事都順。", "心態正向，小事順手。", "樂觀過頭或計畫變動，文件和行程要再三確認。"],
        ["事業有表現的機會，挑戰能轉成成績，有人看見你的努力。", "工作照常推進，壓力可控。", "壓力大、容易鬱悶沮喪、遇到麻煩或被排擠，把困難拆小、找人商量。"],
        ["朋友和群體帶來新的變化與機會，想法特別、很有創意。", "有些變動，保持彈性就好。", "變動多、不穩定、精神困擾，計畫容易被打亂，留一點備案。"],
        ["直覺和緣分很準，適合沉澱、藝術和內在探索。", "內心戲多一點，給自己獨處時間。", "容易迷茫、逃避、悲觀或沉迷某件事，別讓情緒把你拖進去。"],
    ]
    static let en: [[String]] = [
        ["You feel strong and assertive, ready to speak up.", "Emotions are even; you move at your own pace.", "Irritability and impulsiveness run high — pause before you speak."],
        ["Money and material things flow; your values are clear.", "Income and spending are balanced.", "Expenses grow and money slips away — avoid impulse buys."],
        ["Communication and learning go well; peers help you.", "Conversations are normal; lots of ideas.", "Misunderstandings and overthinking — put important things in writing."],
        ["Home feels harmonious and you feel safe.", "Home is steady, with some worrying.", "Insecurity and anxiety rise — find yourself a quiet corner."],
        ["You're noticed and attractive; romance and fun are strong.", "Small joys; love is calm.", "Trying too hard for attention or overindulging — pace yourself."],
        ["Busy but productive; social and daily tasks go smoothly.", "Lots of chores — work through a list.", "Tangled in chores and mentally tired — finish the one most important thing."],
        ["The people you meet help you; partnership is a support.", "Relationships are steady.", "Caring too much about others, tug-of-war in relationships — protect your boundaries."],
        ["Windfalls or others' resources help; health is stable.", "Occasional loneliness, but manageable.", "Loneliness and time dragging — watch your health and money dealings."],
        ["Optimism and luck; travel and paperwork go well.", "Positive mood; small things go right.", "Over-optimism or changed plans — double-check documents and schedules."],
        ["Chances to shine at work; challenges turn into results.", "Work moves along; pressure is manageable.", "Heavy pressure, frustration or obstacles — break problems down and ask for help."],
        ["Friends and groups bring new chances; creative ideas.", "Some changes — stay flexible.", "Lots of instability — keep a backup plan."],
        ["Intuition and serendipity are strong; good for reflection and art.", "More inner drama — give yourself alone time.", "Confusion, escapism or pessimism — don't let emotions pull you under."],
    ]

    static let es: [[String]] = [
        ["Te sientes fuerte y decidido, listo para hablar.", "Emociones estables; vas a tu ritmo.", "Irritabilidad e impulsividad altas: respira antes de hablar."],
        ["El dinero y lo material fluyen; tus valores están claros.", "Ingresos y gastos equilibrados.", "Los gastos crecen: evita compras impulsivas."],
        ["La comunicación y el estudio van bien; los compañeros te ayudan.", "Conversaciones normales, muchas ideas.", "Malentendidos y demasiadas vueltas: pon lo importante por escrito."],
        ["El hogar está en armonía y te sientes seguro.", "Hogar estable, con alguna preocupación.", "Suben la inseguridad y la ansiedad: búscate un rincón tranquilo."],
        ["Te notan y atraes; amor y diversión fuertes.", "Pequeñas alegrías; el amor está en calma.", "Esforzarte demasiado por llamar la atención o excesos: ve con calma."],
        ["Ocupado pero productivo; lo social y lo cotidiano fluyen.", "Muchas tareas: ve por una lista.", "Enredado en tareas y cansado: termina lo más importante."],
        ["Las personas que conoces te ayudan; la pareja es un apoyo.", "Relaciones estables.", "Te importa demasiado lo que piensan otros: protege tus límites."],
        ["Dinero inesperado o recursos de otros te ayudan; salud estable.", "Algo de soledad, pero llevadera.", "Soledad y días largos: cuida tu salud y tus cuentas."],
        ["Optimismo y suerte; viajes y papeles van bien.", "Buen ánimo; lo pequeño sale bien.", "Exceso de optimismo o planes que cambian: revisa documentos y horarios."],
        ["Oportunidades de brillar en el trabajo.", "El trabajo avanza; presión manejable.", "Mucha presión u obstáculos: divide los problemas y pide ayuda."],
        ["Amigos y grupos traen nuevas oportunidades; ideas creativas.", "Algunos cambios: sé flexible.", "Mucha inestabilidad: ten un plan B."],
        ["Intuición y casualidades fuertes; bueno para reflexionar y crear.", "Más mundo interior: date tiempo a solas.", "Confusión, evasión o pesimismo: no te dejes arrastrar."],
    ]
    static let it: [[String]] = [
        ["Ti senti forte e deciso, pronto a parlare.", "Emozioni stabili; vai al tuo ritmo.", "Irritabilità e impulsività alte: respira prima di parlare."],
        ["Denaro e beni scorrono; i tuoi valori sono chiari.", "Entrate e uscite in equilibrio.", "Le spese crescono: evita acquisti d'impulso."],
        ["Comunicazione e studio vanno bene; i colleghi ti aiutano.", "Conversazioni normali, tante idee.", "Malintesi e rimuginare: metti per iscritto le cose importanti."],
        ["La casa è in armonia e ti senti al sicuro.", "Casa stabile, con qualche preoccupazione.", "Salgono insicurezza e ansia: trova un angolo tranquillo."],
        ["Ti notano e attrai; amore e divertimento forti.", "Piccole gioie; l'amore è calmo.", "Troppa voglia di attenzione o eccessi: vai piano."],
        ["Impegnato ma produttivo; vita sociale e quotidiana scorrono.", "Tante faccende: segui una lista.", "Sommerso dalle faccende e stanco: finisci la cosa più importante."],
        ["Le persone che incontri ti aiutano; il partner è un sostegno.", "Relazioni stabili.", "Ti importa troppo degli altri: proteggi i tuoi confini."],
        ["Soldi inattesi o risorse altrui ti aiutano; salute stabile.", "Un po' di solitudine, ma gestibile.", "Solitudine e giornate lunghe: cura la salute e i conti."],
        ["Ottimismo e fortuna; viaggi e documenti vanno bene.", "Buon umore; le piccole cose vanno bene.", "Troppo ottimismo o piani che cambiano: ricontrolla documenti e orari."],
        ["Occasioni per brillare nel lavoro.", "Il lavoro procede; pressione gestibile.", "Molta pressione o ostacoli: spezza i problemi e chiedi aiuto."],
        ["Amici e gruppi portano nuove occasioni; idee creative.", "Qualche cambiamento: resta flessibile.", "Molta instabilità: tieni un piano B."],
        ["Intuizione e coincidenze forti; bene per riflettere e creare.", "Più mondo interiore: prenditi tempo da solo.", "Confusione, fuga o pessimismo: non lasciarti trascinare."],
    ]

    public static func text(_ p: Int, _ v: NTVerdict, _ L: Lang) -> String {
        let i = NT.r12(p) - 1
        return (L == .zh ? zh : (L == .es ? es : (L == .it ? it : en)))[i][v.rawValue]
    }
}
