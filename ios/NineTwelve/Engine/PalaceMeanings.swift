import Foundation

/// 十二宮含義。
///
/// 中文為作者提供的定本；英文譯法在有既定命理術語處採用該術語
/// （桃花 Peach Blossom、正財 Direct Wealth、偏財 Indirect Wealth、
/// 緣分 Karmic affinity、業力 Karma、輪迴 Reincarnation 等），
/// 其餘依語意翻譯。
public struct Palace {

    /// 每宮的簡稱，用於表格與標題。
    public static func shortName(_ palace: Int, lang: Lang = .zh) -> String {
        let names: [String]
        switch lang {
        case .zh: names = shortZh
        case .en: names = shortEn
        case .es: names = shortEs
        case .it: names = shortIt
        }
        return names[Num.r12(palace) - 1]
    }

    private static let shortZh = ["自我", "物質", "交流", "家庭", "桃花", "勞碌",
                                  "他人", "偏財", "愉悅", "事業", "朋友", "沉迷"]
    private static let shortEn = ["Self", "Direct Wealth", "Communication", "Home",
                                  "Peach Blossom", "Toil", "Others", "Indirect Wealth",
                                  "Fortune", "Career", "Friends", "Hidden"]
    private static let shortEs = ["Yo", "Riqueza directa", "Comunicación", "Hogar",
                                  "Flor de Durazno", "Afán", "Los demás", "Riqueza indirecta",
                                  "Fortuna", "Carrera", "Amigos", "Oculto"]
    private static let shortIt = ["Io", "Ricchezza diretta", "Comunicazione", "Casa",
                                  "Fiore di Pesco", "Fatica", "Gli altri", "Ricchezza indiretta",
                                  "Fortuna", "Carriera", "Amici", "Nascosto"]

    /// 該宮的關鍵字。
    public static func keywords(_ palace: Int, lang: Lang = .zh) -> [String] {
        let table: [[String]]
        switch lang {
        case .zh: table = Palace.zh
        case .en: table = Palace.en
        case .es: table = Palace.es
        case .it: table = Palace.it
        }
        return table[Num.r12(palace) - 1]
    }

    /// 完整含義（以頓號／逗號串接）。
    public static func text(_ palace: Int, lang: Lang = .zh) -> String {
        keywords(palace, lang: lang).joined(separator: lang == .zh ? "、" : ", ")
    }

    /// 精簡摘要（取前幾個關鍵字），用於列表。
    public static func brief(_ palace: Int, lang: Lang = .zh) -> String {
        // 摘要都是接在宮位簡稱底下顯示的，跳過和簡稱一樣的那一個，
        // 不然標題與第一個關鍵字會重複；跳過後往後遞補，仍取四個。
        let name = shortName(palace, lang: lang)
        return keywords(palace, lang: lang)
            .filter { $0 != name }
            .prefix(4)
            .joined(separator: lang == .zh ? "、" : ", ")
    }

    // MARK: - 中文定本

    static let zh: [[String]] = [
        // 1宮
        ["自己", "煩躁", "躁動", "情緒化", "沖動", "生氣", "上火", "激動", "傷害"],
        // 2宮
        ["食物", "物質", "我的錢", "清秀的人", "開銷", "正財", "價值觀", "認知", "動力", "口腔"],
        // 3宮
        ["交流", "交談", "思考", "思想", "思維活躍", "學習", "語言", "年齡比本人小的人", "同輩", "同事", "同學", "同胞", "鄰居",
         "兄弟姐妹", "出門", "學業", "靈活", "好動", "離開", "分離", "走了", "活力", "新鮮感", "精神", "甲狀腺"],
        // 4宮
        ["家庭", "安全感", "敏感", "焦慮", "脆弱", "空落", "擔心", "擔憂", "內省", "內耗", "居住環境", "原生家庭", "出生環境",
         "出生國家", "女性", "母親"],
        // 5宮
        ["受人關注", "娛樂", "享樂", "快樂", "桃花", "吸引力", "性", "引人矚目", "戀愛", "男性", "被看見", "父親"],
        // 6宮
        ["勞碌", "忙碌", "思緒混亂無序", "心累", "勞累", "緊張", "議論", "日常的事物", "勞動", "想得多", "社交", "交際", "想法",
         "聚焦", "執念", "重複的事情", "注意力", "反覆"],
        // 7宮
        ["在意別人", "心思在別人身上", "他人", "遇見的人", "羈絆", "一對一關係", "伴侶", "情侶", "對象", "戀人", "身邊的人", "婚姻"],
        // 8宮
        ["偏財", "孤獨", "無聊", "煎熬", "焦灼", "無助", "黑暗", "痛苦", "折磨", "感覺時間漫長", "身體", "他人的錢",
         "別人的隱私和隱秘", "別人的私生活", "隱耗", "生存", "體力", "精力", "健康情況"],
        // 9宮
        ["樂觀", "正向", "愉快", "愉悅", "幸運", "運氣", "宗教", "信仰", "遷移", "文件", "文書", "文憑", "國外", "出遠門",
         "文化", "豁達", "開朗", "積極", "理想", "善良", "品德", "盲目", "自大", "意義", "機遇", "機會"],
        // 10宮
        ["事業", "鬱悶", "壓抑", "消極", "沮喪", "麻煩", "困難", "磨難", "失落", "挑戰", "排擠", "煩人的事", "厄運",
         "比自己年長的人", "工作", "長輩", "職業", "名聲", "權威", "權勢", "才能", "社會地位", "成就", "政府"],
        // 11宮
        ["朋友", "群體", "變動", "變化", "特別", "差異", "理智", "理性", "精神困擾", "網絡", "不穩定", "波折", "奔波", "折騰",
         "奔波輾轉", "貴人"],
        // 12宮
        ["沉迷", "迷茫", "幻想", "緣分", "脾氣", "性格", "品行", "道德", "幕後", "悲觀", "逃避", "悲傷", "多愁善感", "嚮往",
         "缺愛", "暗戀", "隱沒", "隱藏", "消耗", "隔離", "自我瓦解", "業力", "循環", "投胎", "輪迴", "玄秘", "玄學", "隔絕",
         "隱匿", "欺騙"],
    ]

    // MARK: - 英文

    static let en: [[String]] = [
        // 1宮
        ["The self", "Irritability", "Restlessness", "Emotional volatility", "Impulsiveness",
         "Anger", "Flaring temper", "Agitation", "Harm"],
        // 2宮
        ["Food", "Material things", "My own money", "Fair, refined-looking people", "Spending",
         "Direct Wealth (steady, earned income)", "Values", "Cognition", "Motivation",
         "The mouth"],
        // 3宮
        ["Communication", "Conversation", "Thinking", "Mindset", "An active mind", "Learning",
         "Language", "People younger than oneself", "Peers", "Colleagues", "Classmates",
         "Compatriots", "Neighbours", "Siblings", "Going out", "Studies", "Nimbleness",
         "Being on the move", "Leaving", "Separation", "Having gone away", "Liveliness",
         "A sense of novelty", "Spirit", "The thyroid"],
        // 4宮
        ["Home", "Sense of security", "Sensitivity", "Anxiety", "Fragility", "Hollowness",
         "Worry", "Apprehension", "Introspection", "Inner depletion", "Living environment",
         "Family of origin", "The environment one was born into", "Country of birth", "Women",
         "Mother"],
        // 5宮
        ["Being noticed", "Entertainment", "Enjoyment", "Happiness",
         "Peach Blossom (romantic attraction, people drawn to you)", "Allure", "Sex",
         "Standing out", "Romance", "Men", "Being seen", "Father"],
        // 6宮
        ["Drudgery", "Busyness", "Scattered, disordered thoughts", "Mental exhaustion",
         "Weariness", "Tension", "Being talked about", "Everyday matters", "Labour",
         "Overthinking", "Socialising", "Social dealings", "Ideas", "Focus", "Fixation",
         "Repetitive matters", "Attention", "Going back and forth"],
        // 7宮
        ["Minding what others think", "Thoughts fixed on someone else", "Other people",
         "People one meets", "Binding ties", "One-to-one relationships", "Partner", "Couple",
         "The person one is seeing", "Lover", "People close at hand", "Marriage"],
        // 8宮
        ["Indirect Wealth (windfalls, money that is not earned)", "Solitude", "Boredom",
         "Torment", "Burning anxiety", "Helplessness", "Darkness", "Pain", "Suffering",
         "Time feeling long", "The body", "Other people's money",
         "Other people's privacy and secrets", "Other people's private lives", "Unseen drain",
         "Survival", "Physical strength", "Vitality", "State of health"],
        // 9宮
        ["Optimism", "Positivity", "Cheer", "Delight", "Good fortune", "Luck", "Religion",
         "Faith", "Relocation", "Documents", "Paperwork", "Diplomas", "Abroad",
         "Long journeys", "Culture", "Broad-mindedness", "Sunny temperament", "Drive",
         "Ideals", "Kindness", "Moral character", "Blindness", "Arrogance", "Meaning",
         "Opportunity", "Chance"],
        // 10宮
        ["Career", "Gloom", "Suppression", "Discouragement", "Dejection", "Trouble",
         "Difficulty", "Ordeals", "Loss", "Challenge", "Being pushed out", "Vexing matters",
         "Misfortune", "People older than oneself", "Work", "Elders", "Profession",
         "Reputation", "Authority", "Power", "Ability", "Social standing", "Achievement",
         "Government"],
        // 11宮
        ["Friends", "Groups", "Shifts", "Change", "Being set apart", "Difference",
         "Level-headedness", "Reason", "Mental disturbance", "Networks", "Instability",
         "Setbacks", "Running about", "Upheaval", "Being tossed from place to place",
         "Benefactors"],
        // 12宮
        ["Obsession", "Confusion", "Fantasy", "Karmic affinity", "Temper", "Disposition",
         "Conduct", "Morality", "Behind the scenes", "Pessimism", "Escapism", "Sorrow",
         "Sentimentality", "Longing", "Starved of love", "Unspoken love", "Fading from view",
         "Concealment", "Depletion", "Isolation", "Self-dissolution", "Karma", "Cycles",
         "Rebirth", "Reincarnation", "The esoteric", "Metaphysics", "Being cut off",
         "Hiding away", "Deception"],
    ]

    // MARK: - 西班牙文

    static let es: [[String]] = [
        // 1宮
        ["El yo", "Irritabilidad", "Inquietud", "Volatilidad emocional", "Impulsividad", "Ira",
         "Arrebato de temperamento", "Agitación", "Daño"],
        // 2宮
        ["Comida", "Bienes materiales", "Mi propio dinero",
         "Personas de aspecto fino y agraciado", "Gastos",
         "Riqueza directa (ingresos estables y ganados)", "Valores", "Cognición", "Motivación",
         "La boca"],
        // 3宮
        ["Comunicación", "Conversación", "Pensamiento", "Mentalidad", "Mente ágil",
         "Aprendizaje", "Lenguaje", "Personas más jóvenes que uno", "Iguales", "Colegas",
         "Compañeros de clase", "Compatriotas", "Vecinos", "Hermanos", "Salir", "Estudios",
         "Agilidad", "Estar en movimiento", "Marcharse", "Separación", "Haberse ido",
         "Vivacidad", "Sensación de novedad", "Ánimo", "La tiroides"],
        // 4宮
        ["Hogar", "Sensación de seguridad", "Sensibilidad", "Ansiedad", "Fragilidad",
         "Vacío interior", "Preocupación", "Inquietud", "Introspección", "Desgaste interior",
         "Entorno donde se vive", "Familia de origen", "El entorno en que se nació",
         "País de nacimiento", "Mujeres", "Madre"],
        // 5宮
        ["Ser notado", "Entretenimiento", "Disfrute", "Alegría",
         "Flor de Durazno (atracción amorosa, quienes se sienten atraídos por ti)", "Encanto",
         "Sexo", "Destacar", "Romance", "Hombres", "Ser visto", "Padre"],
        // 6宮
        ["Trabajo penoso", "Ajetreo", "Pensamientos dispersos y desordenados",
         "Agotamiento mental", "Cansancio", "Tensión", "Ser objeto de comentarios",
         "Asuntos cotidianos", "Labor", "Darle demasiadas vueltas", "Socializar",
         "Trato social", "Ideas", "Concentración", "Obsesión", "Asuntos repetitivos",
         "Atención", "Idas y vueltas"],
        // 7宮
        ["Preocuparse por lo que piensan los demás", "Pensamiento fijo en otra persona",
         "Los demás", "Personas que uno conoce", "Lazos que atan", "Relaciones de uno a uno",
         "Compañero de vida", "Pareja", "La persona con quien se sale", "Amante",
         "Personas cercanas", "Matrimonio"],
        // 8宮
        ["Riqueza indirecta (dinero inesperado, no ganado con trabajo)", "Soledad",
         "Aburrimiento", "Tormento", "Ansiedad abrasadora", "Desamparo", "Oscuridad", "Dolor",
         "Sufrimiento", "Sentir que el tiempo se alarga", "El cuerpo", "El dinero ajeno",
         "La privacidad y los secretos de los demás", "La vida privada de los demás",
         "Desgaste oculto", "Supervivencia", "Fuerza física", "Energía vital",
         "Estado de salud"],
        // 9宮
        ["Optimismo", "Actitud positiva", "Alegría", "Deleite", "Buena fortuna", "Suerte",
         "Religión", "Fe", "Traslado", "Documentos", "Papeleo", "Títulos", "El extranjero",
         "Viajes largos", "Cultura", "Amplitud de miras", "Temperamento alegre", "Empuje",
         "Ideales", "Bondad", "Carácter moral", "Ceguera", "Arrogancia", "Significado",
         "Oportunidad", "Ocasión"],
        // 10宮
        ["Carrera", "Melancolía", "Represión", "Desánimo", "Abatimiento", "Problemas",
         "Dificultad", "Pruebas duras", "Pérdida", "Desafío", "Ser apartado",
         "Asuntos molestos", "Infortunio", "Personas mayores que uno", "Trabajo", "Mayores",
         "Profesión", "Reputación", "Autoridad", "Poder", "Capacidad", "Posición social",
         "Logro", "Gobierno"],
        // 11宮
        ["Amigos", "Grupos", "Cambios de rumbo", "Cambio", "Ser distinto", "Diferencia",
         "Serenidad de juicio", "Razón", "Perturbación mental", "Redes", "Inestabilidad",
         "Contratiempos", "Ir de un lado a otro", "Trastorno",
         "Verse llevado de un lugar a otro", "Benefactores"],
        // 12宮
        ["Obsesión", "Confusión", "Fantasía", "Afinidad kármica", "Genio", "Carácter",
         "Conducta", "Moralidad", "Entre bastidores", "Pesimismo", "Evasión", "Pena",
         "Sentimentalismo", "Anhelo", "Falta de amor", "Amor callado",
         "Desvanecerse de la vista", "Ocultamiento", "Desgaste", "Aislamiento",
         "Disolución de uno mismo", "Karma", "Ciclos", "Renacimiento", "Reencarnación",
         "Lo esotérico", "Metafísica", "Estar aislado del mundo", "Ocultarse", "Engaño"],
    ]

    // MARK: - 義大利文

    static let it: [[String]] = [
        // 1宮
        ["L'io", "Irritabilità", "Irrequietezza", "Instabilità emotiva", "Impulsività",
         "Rabbia", "Scatto d'ira", "Agitazione", "Danno"],
        // 2宮
        ["Cibo", "Beni materiali", "Il mio denaro", "Persone dall'aspetto fine e grazioso",
         "Spese", "Ricchezza diretta (reddito stabile e guadagnato)", "Valori", "Cognizione",
         "Motivazione", "La bocca"],
        // 3宮
        ["Comunicazione", "Conversazione", "Pensiero", "Mentalità", "Mente vivace",
         "Apprendimento", "Linguaggio", "Persone più giovani di sé", "Coetanei", "Colleghi",
         "Compagni di classe", "Connazionali", "Vicini", "Fratelli e sorelle", "Uscire",
         "Studi", "Agilità", "Essere in movimento", "Andarsene", "Separazione",
         "Essere andato via", "Vivacità", "Senso di novità", "Spirito", "La tiroide"],
        // 4宮
        ["Casa", "Senso di sicurezza", "Sensibilità", "Ansia", "Fragilità", "Vuoto interiore",
         "Preoccupazione", "Apprensione", "Introspezione", "Logoramento interiore",
         "Ambiente in cui si vive", "Famiglia d'origine", "L'ambiente in cui si è nati",
         "Paese di nascita", "Donne", "Madre"],
        // 5宮
        ["Essere notati", "Divertimento", "Piacere", "Gioia",
         "Fiore di Pesco (attrazione amorosa, chi si sente attratto da te)", "Fascino",
         "Sesso", "Distinguersi", "Amore", "Uomini", "Essere visti", "Padre"],
        // 6宮
        ["Lavoro gravoso", "Affaccendamento", "Pensieri sparsi e disordinati",
         "Esaurimento mentale", "Stanchezza", "Tensione", "Essere oggetto di chiacchiere",
         "Faccende quotidiane", "Fatica", "Rimuginare", "Socializzare", "Rapporti sociali",
         "Idee", "Concentrazione", "Fissazione", "Cose ripetitive", "Attenzione",
         "Andirivieni"],
        // 7宮
        ["Curarsi di ciò che pensano gli altri", "Pensiero fisso su un'altra persona",
         "Gli altri", "Persone che si incontrano", "Legami che vincolano", "Relazioni a due",
         "Compagno", "Coppia", "La persona che si frequenta", "Amante", "Persone vicine",
         "Matrimonio"],
        // 8宮
        ["Ricchezza indiretta (denaro inatteso, non guadagnato)", "Solitudine", "Noia",
         "Tormento", "Ansia bruciante", "Impotenza", "Oscurità", "Dolore", "Sofferenza",
         "Sentire il tempo lungo", "Il corpo", "Il denaro altrui",
         "La privacy e i segreti altrui", "La vita privata altrui", "Logorio nascosto",
         "Sopravvivenza", "Forza fisica", "Energia vitale", "Stato di salute"],
        // 9宮
        ["Ottimismo", "Positività", "Allegria", "Gioia", "Buona sorte", "Fortuna", "Religione",
         "Fede", "Trasferimento", "Documenti", "Pratiche burocratiche", "Diplomi", "L'estero",
         "Viaggi lunghi", "Cultura", "Apertura mentale", "Temperamento solare", "Slancio",
         "Ideali", "Bontà", "Carattere morale", "Cecità", "Arroganza", "Significato",
         "Opportunità", "Occasione"],
        // 10宮
        ["Carriera", "Malinconia", "Repressione", "Scoraggiamento", "Abbattimento", "Guai",
         "Difficoltà", "Prove dure", "Perdita", "Sfida", "Essere messo da parte",
         "Faccende fastidiose", "Sfortuna", "Persone più grandi di sé", "Lavoro", "Anziani",
         "Professione", "Reputazione", "Autorità", "Potere", "Capacità", "Posizione sociale",
         "Successo", "Governo"],
        // 11宮
        ["Amici", "Gruppi", "Mutamenti", "Cambiamento", "Essere diversi", "Differenza",
         "Lucidità", "Ragione", "Turbamento mentale", "Reti", "Instabilità", "Contrattempi",
         "Correre di qua e di là", "Sconvolgimento",
         "Essere sballottati da un posto all'altro", "Benefattori"],
        // 12宮
        ["Ossessione", "Confusione", "Fantasia", "Affinità karmica", "Temperamento", "Indole",
         "Condotta", "Moralità", "Dietro le quinte", "Pessimismo", "Evasione", "Tristezza",
         "Sentimentalismo", "Struggimento", "Mancanza d'amore", "Amore taciuto",
         "Svanire dalla vista", "Occultamento", "Consumo", "Isolamento", "Dissoluzione di sé",
         "Karma", "Cicli", "Rinascita", "Reincarnazione", "L'esoterico", "Metafisica",
         "Essere tagliati fuori", "Nascondersi", "Inganno"],
    ]
}
