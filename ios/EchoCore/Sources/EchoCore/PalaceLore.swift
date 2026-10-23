import Foundation

/// 十二宮在「好／正／壞」判讀下的具體表現（依 Hollow 十二宮關鍵詞整理）。
/// 中文最細；外語用較短的說法。
public enum PalaceLore {
    /// [宮-1][好, 正, 壞]
    static let zh: [[String]] = [
        ["自我狀態好，行動力強，敢表達自己的想法。", "自我的能量很強：很有主見、很想做自己，情緒和行動都很明顯，用在對的地方就是力量。", "容易煩躁、衝動、上火，說話前先停三秒，別傷到人也別傷到自己。"],
        ["收入和物質上比較順，有機會買到想要的東西，價值觀也清楚。", "錢和物質的能量很強：很在意錢、吃、價值觀，收入和開銷都很明顯，用在對的地方就是力量。", "開銷變大、錢不太聽話，也要留意口腔和飲食，別衝動消費。"],
        ["溝通順、腦袋靈活，學習和談事情都有收穫，身邊同輩會幫你。", "交流的能量很強：話多、想法多、出門多，事情一直在動，用在對的地方就是力量。", "容易說錯話、想太多、跟同輩、同事或同胞有摩擦，重要的事寫下來再說。"],
        ["家裡和睦、住得安心，內心有安全感。", "家和安全感的能量很強：特別在意家人、母親、住的地方，內心感受很深，用在對的地方就是力量。", "不安全感上來、容易焦慮內耗，家裡的事比較多，給自己一個安靜的角落。"],
        ["人緣好、被看見，桃花和娛樂都旺，適合表現自己。", "吸引力的能量很強：很想被看見、很有魅力，桃花和享樂都很明顯，用在對的地方就是力量。", "容易為了被關注而用力過猛、感情波折或享樂過頭，量力而為。"],
        ["雖然忙但忙得有成果，社交和日常事務處理得很順。", "忙碌的能量很強：事情多、社交多、腦袋一直在轉，用在對的地方就是力量。", "瑣事纏身、思緒亂、心累，容易被議論，先把最重要的一件事做完。"],
        ["遇到的人對你有幫助，伴侶和一對一的關係是助力。", "關係的能量很強：心思都在對方、身邊的人身上，一對一關係是重心，用在對的地方就是力量。", "太在意別人、關係裡有拉扯或羈絆，先照顧好自己的界線。"],
        ["可能有意外之財或別人的資源幫你，身體狀況也穩。", "8宮的能量很強：身體、欲望、大錢和別人的資源都很明顯，獨處和焦灼感也比較深，用在對的地方就是力量。", "容易孤獨、煎熬、覺得時間很漫長，留意身體與金錢往來，別一個人硬撐。"],
        ["心情樂觀、運氣好，出遠門、文件、信仰相關的事都順。", "好運和理想的能量很強：很樂觀、很想往遠方去，機會、文書的事多，用在對的地方就是力量。", "樂觀過頭或計畫變動，文件和行程要再三確認。"],
        ["事業有表現的機會，挑戰能轉成成績，有人看見你的努力。", "事業的能量很強：工作、責任、地位是重心，壓力和成就都很明顯，用在對的地方就是力量。", "壓力大、容易鬱悶沮喪、遇到麻煩或被排擠，把困難拆小、找人商量。"],
        ["朋友和群體帶來新的變化與機會，想法特別、很有創意。", "朋友和變動的能量很強：朋友、群體、變化很多，想法特別，用在對的地方就是力量。", "變動多、不穩定、精神困擾，計畫容易被打亂，留一點備案。"],
        ["直覺和緣分很準，適合沉澱、藝術和內在探索。", "內心和緣分的能量很強：直覺、想像、玄學和隱藏的事都很明顯，內心戲很多，用在對的地方就是力量。", "容易迷茫、逃避、悲觀或沉迷某件事，別讓情緒把你拖進去。"],
    ]
    static let en: [[String]] = [
        ["You feel strong and assertive, ready to speak up.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Irritability and impulsiveness run high — pause before you speak."],
        ["Money and material things flow; your values are clear.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Expenses grow and money slips away — avoid impulse buys."],
        ["Communication and learning go well; peers help you.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Misunderstandings and overthinking — put important things in writing."],
        ["Home feels harmonious and you feel safe.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Insecurity and anxiety rise — find yourself a quiet corner."],
        ["You're noticed and attractive; romance and fun are strong.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Trying too hard for attention or overindulging — pace yourself."],
        ["Busy but productive; social and daily tasks go smoothly.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Tangled in chores and mentally tired — finish the one most important thing."],
        ["The people you meet help you; partnership is a support.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Caring too much about others, tug-of-war in relationships — protect your boundaries."],
        ["Windfalls or others' resources help; health is stable.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Loneliness and time dragging — watch your health and money dealings."],
        ["Optimism and luck; travel and paperwork go well.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Over-optimism or changed plans — double-check documents and schedules."],
        ["Chances to shine at work; challenges turn into results.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Heavy pressure, frustration or obstacles — break problems down and ask for help."],
        ["Friends and groups bring new chances; creative ideas.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Lots of instability — keep a backup plan."],
        ["Intuition and serendipity are strong; good for reflection and art.", "This area's energy is strong and amplified — intense rather than good or bad; it depends on how you use it.", "Confusion, escapism or pessimism — don't let emotions pull you under."],
    ]

    static let es: [[String]] = [
        ["Te sientes fuerte y decidido, listo para hablar.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Irritabilidad e impulsividad altas: respira antes de hablar."],
        ["El dinero y lo material fluyen; tus valores están claros.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Los gastos crecen: evita compras impulsivas."],
        ["La comunicación y el estudio van bien; los compañeros te ayudan.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Malentendidos y demasiadas vueltas: pon lo importante por escrito."],
        ["El hogar está en armonía y te sientes seguro.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Suben la inseguridad y la ansiedad: búscate un rincón tranquilo."],
        ["Te notan y atraes; amor y diversión fuertes.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Esforzarte demasiado por llamar la atención o excesos: ve con calma."],
        ["Ocupado pero productivo; lo social y lo cotidiano fluyen.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Enredado en tareas y cansado: termina lo más importante."],
        ["Las personas que conoces te ayudan; la pareja es un apoyo.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Te importa demasiado lo que piensan otros: protege tus límites."],
        ["Dinero inesperado o recursos de otros te ayudan; salud estable.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Soledad y días largos: cuida tu salud y tus cuentas."],
        ["Optimismo y suerte; viajes y papeles van bien.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Exceso de optimismo o planes que cambian: revisa documentos y horarios."],
        ["Oportunidades de brillar en el trabajo.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Mucha presión u obstáculos: divide los problemas y pide ayuda."],
        ["Amigos y grupos traen nuevas oportunidades; ideas creativas.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Mucha inestabilidad: ten un plan B."],
        ["Intuición y casualidades fuertes; bueno para reflexionar y crear.", "La energía de esta área es fuerte y amplificada: intensa, ni buena ni mala; depende de cómo la uses.", "Confusión, evasión o pesimismo: no te dejes arrastrar."],
    ]
    static let it: [[String]] = [
        ["Ti senti forte e deciso, pronto a parlare.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Irritabilità e impulsività alte: respira prima di parlare."],
        ["Denaro e beni scorrono; i tuoi valori sono chiari.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Le spese crescono: evita acquisti d'impulso."],
        ["Comunicazione e studio vanno bene; i colleghi ti aiutano.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Malintesi e rimuginare: metti per iscritto le cose importanti."],
        ["La casa è in armonia e ti senti al sicuro.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Salgono insicurezza e ansia: trova un angolo tranquillo."],
        ["Ti notano e attrai; amore e divertimento forti.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Troppa voglia di attenzione o eccessi: vai piano."],
        ["Impegnato ma produttivo; vita sociale e quotidiana scorrono.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Sommerso dalle faccende e stanco: finisci la cosa più importante."],
        ["Le persone che incontri ti aiutano; il partner è un sostegno.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Ti importa troppo degli altri: proteggi i tuoi confini."],
        ["Soldi inattesi o risorse altrui ti aiutano; salute stabile.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Solitudine e giornate lunghe: cura la salute e i conti."],
        ["Ottimismo e fortuna; viaggi e documenti vanno bene.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Troppo ottimismo o piani che cambiano: ricontrolla documenti e orari."],
        ["Occasioni per brillare nel lavoro.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Molta pressione o ostacoli: spezza i problemi e chiedi aiuto."],
        ["Amici e gruppi portano nuove occasioni; idee creative.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Molta instabilità: tieni un piano B."],
        ["Intuizione e coincidenze forti; bene per riflettere e creare.", "L'energia di quest'area è forte e amplificata: intensa, né buona né cattiva; dipende da come la usi.", "Confusione, fuga o pessimismo: non lasciarti trascinare."],
    ]

    /// 有完整判讀時用這個：中文照「本宮 × 果宮好壞 × 因宮」講，不再只看本宮好壞（5宮壞12因7 是沒緣分，不是用力過猛）
    public static func text(_ p: Int, _ r: NTReading, _ L: Lang) -> String {
        L == .zh ? FlowReading.plain(palace: p, reading: r) : text(p, r.verdict, L)
    }

    public static func text(_ p: Int, _ v: NTVerdict, _ L: Lang) -> String {
        let i = NT.r12(p) - 1
        return (L == .zh ? zh : (L == .es ? es : (L == .it ? it : en)))[i][v.rawValue]
    }
}
