package com.ninetwelve.fortune.engine

/**
 * 十二宮含義。
 *
 * 中文為作者提供的定本；英文譯法在有既定命理術語處採用該術語
 * （桃花 Peach Blossom、正財 Direct Wealth、偏財 Indirect Wealth、
 * 緣分 Karmic affinity、業力 Karma、輪迴 Reincarnation 等），
 * 其餘依語意翻譯。
 *
 * 這份表由 iOS 版 `Engine/PalaceMeanings.swift` 逐字轉出，內容完全相同。
 */
object Palace {

    /** 每宮的簡稱，用於表格與標題。 */
    fun shortName(palace: Int, lang: Lang = Lang.ZH): String {
        val names = when (lang) {
            Lang.ZH -> shortZh
            Lang.EN -> shortEn
            Lang.ES -> shortEs
            Lang.IT -> shortIt
        }
        return names[Num.r12(palace) - 1]
    }

    /** 該宮的關鍵字。 */
    fun keywords(palace: Int, lang: Lang = Lang.ZH): List<String> {
        val table = when (lang) {
            Lang.ZH -> zh
            Lang.EN -> en
            Lang.ES -> es
            Lang.IT -> ita
        }
        return table[Num.r12(palace) - 1]
    }

    /** 完整含義（以頓號／逗號串接）。 */
    fun text(palace: Int, lang: Lang = Lang.ZH): String =
        keywords(palace, lang).joinToString(if (lang == Lang.ZH) "、" else ", ")

    /** 精簡摘要（取前幾個關鍵字），用於列表。 */
    // 摘要都是接在宮位簡稱底下顯示的，跳過和簡稱一樣的那一個，
    // 不然標題與第一個關鍵字會重複；跳過後往後遞補，仍取四個。
    fun brief(palace: Int, lang: Lang = Lang.ZH): String {
        val name = shortName(palace, lang)
        return keywords(palace, lang)
            .filter { it != name }
            .take(4)
            .joinToString(if (lang == Lang.ZH) "、" else ", ")
    }

    private val shortZh = listOf(
        "自我", "物質", "交流", "家庭", "桃花", "勞碌", "他人", "偏財", "愉悅", "事業", "朋友", "沉迷"
    )

    private val shortEn = listOf(
        "Self", "Direct Wealth", "Communication", "Home", "Peach Blossom", "Toil", "Others",
        "Indirect Wealth", "Fortune", "Career", "Friends", "Hidden"
    )

    private val shortEs = listOf(
        "Yo", "Riqueza directa", "Comunicación", "Hogar", "Flor de Durazno", "Afán", "Los demás",
        "Riqueza indirecta", "Fortuna", "Carrera", "Amigos", "Oculto"
    )

    private val shortIt = listOf(
        "Io", "Ricchezza diretta", "Comunicazione", "Casa", "Fiore di Pesco", "Fatica",
        "Gli altri", "Ricchezza indiretta", "Fortuna", "Carriera", "Amici", "Nascosto"
    )

    // ── 中文定本 ──

    private val zh: List<List<String>> = listOf(
        // 宮 1
        listOf(
            "自己", "煩躁", "躁動", "情緒化", "沖動", "生氣", "上火", "激動", "傷害"
        ),
        // 宮 2
        listOf(
            "食物", "物質", "我的錢", "清秀的人", "開銷", "正財", "價值觀", "認知", "動力", "口腔"
        ),
        // 宮 3
        listOf(
            "交流", "交談", "思考", "思想", "思維活躍", "學習", "語言", "年齡比本人小的人", "同輩", "同事", "同學", "同胞",
            "鄰居", "兄弟姐妹", "出門", "學業", "靈活", "好動", "離開", "分離", "走了", "活力", "新鮮感", "精神", "甲狀腺"
        ),
        // 宮 4
        listOf(
            "家庭", "安全感", "敏感", "焦慮", "脆弱", "空落", "擔心", "擔憂", "內省", "內耗", "居住環境", "原生家庭",
            "出生環境", "出生國家", "女性", "母親"
        ),
        // 宮 5
        listOf(
            "受人關注", "娛樂", "享樂", "快樂", "桃花", "吸引力", "性", "引人矚目", "戀愛", "男性", "被看見", "父親"
        ),
        // 宮 6
        listOf(
            "勞碌", "忙碌", "思緒混亂無序", "心累", "勞累", "緊張", "議論", "日常的事物", "勞動", "想得多", "社交", "交際",
            "想法", "聚焦", "執念", "重複的事情", "注意力", "反覆"
        ),
        // 宮 7
        listOf(
            "在意別人", "心思在別人身上", "他人", "遇見的人", "羈絆", "一對一關係", "伴侶", "情侶", "對象", "戀人", "身邊的人",
            "婚姻"
        ),
        // 宮 8
        listOf(
            "偏財", "孤獨", "無聊", "煎熬", "焦灼", "無助", "黑暗", "痛苦", "折磨", "感覺時間漫長", "身體", "他人的錢",
            "別人的隱私和隱秘", "別人的私生活", "隱耗", "生存", "體力", "精力", "健康情況"
        ),
        // 宮 9
        listOf(
            "樂觀", "正向", "愉快", "愉悅", "幸運", "運氣", "宗教", "信仰", "遷移", "文件", "文書", "文憑", "國外",
            "出遠門", "文化", "豁達", "開朗", "積極", "理想", "善良", "品德", "盲目", "自大", "意義", "機遇", "機會"
        ),
        // 宮 10
        listOf(
            "事業", "鬱悶", "壓抑", "消極", "沮喪", "麻煩", "困難", "磨難", "失落", "挑戰", "排擠", "煩人的事", "厄運",
            "比自己年長的人", "工作", "長輩", "職業", "名聲", "權威", "權勢", "才能", "社會地位", "成就", "政府"
        ),
        // 宮 11
        listOf(
            "朋友", "群體", "變動", "變化", "特別", "差異", "理智", "理性", "精神困擾", "網絡", "不穩定", "波折", "奔波",
            "折騰", "奔波輾轉"
        ),
        // 宮 12
        listOf(
            "沉迷", "迷茫", "幻想", "緣分", "脾氣", "性格", "品行", "道德", "幕後", "悲觀", "逃避", "悲傷", "多愁善感",
            "嚮往", "缺愛", "暗戀", "隱沒", "隱藏", "消耗", "隔離", "自我瓦解", "業力", "循環", "投胎", "輪迴", "玄秘",
            "玄學", "隔絕", "隱匿", "欺騙"
        ),
    )

    // ── 英文 ──

    private val en: List<List<String>> = listOf(
        // 宮 1
        listOf(
            "The self", "Irritability", "Restlessness", "Emotional volatility",
            "Impulsiveness", "Anger", "Flaring temper", "Agitation", "Harm"
        ),
        // 宮 2
        listOf(
            "Food", "Material things", "My own money", "Fair, refined-looking people",
            "Spending", "Direct Wealth (steady, earned income)", "Values", "Cognition",
            "Motivation", "The mouth"
        ),
        // 宮 3
        listOf(
            "Communication", "Conversation", "Thinking", "Mindset", "An active mind",
            "Learning", "Language", "People younger than oneself", "Peers", "Colleagues",
            "Classmates", "Compatriots", "Neighbours", "Siblings", "Going out", "Studies",
            "Nimbleness", "Being on the move", "Leaving", "Separation", "Having gone away",
            "Liveliness", "A sense of novelty", "Spirit", "The thyroid"
        ),
        // 宮 4
        listOf(
            "Home", "Sense of security", "Sensitivity", "Anxiety", "Fragility", "Hollowness",
            "Worry", "Apprehension", "Introspection", "Inner depletion", "Living environment",
            "Family of origin", "The environment one was born into", "Country of birth",
            "Women", "Mother"
        ),
        // 宮 5
        listOf(
            "Being noticed", "Entertainment", "Enjoyment", "Happiness",
            "Peach Blossom (romantic attraction, people drawn to you)", "Allure", "Sex",
            "Standing out", "Romance", "Men", "Being seen", "Father"
        ),
        // 宮 6
        listOf(
            "Drudgery", "Busyness", "Scattered, disordered thoughts", "Mental exhaustion",
            "Weariness", "Tension", "Being talked about", "Everyday matters", "Labour",
            "Overthinking", "Socialising", "Social dealings", "Ideas", "Focus", "Fixation",
            "Repetitive matters", "Attention", "Going back and forth"
        ),
        // 宮 7
        listOf(
            "Minding what others think", "Thoughts fixed on someone else", "Other people",
            "People one meets", "Binding ties", "One-to-one relationships", "Partner",
            "Couple", "The person one is seeing", "Lover", "People close at hand", "Marriage"
        ),
        // 宮 8
        listOf(
            "Indirect Wealth (windfalls, money that is not earned)", "Solitude", "Boredom",
            "Torment", "Burning anxiety", "Helplessness", "Darkness", "Pain", "Suffering",
            "Time feeling long", "The body", "Other people's money",
            "Other people's privacy and secrets", "Other people's private lives",
            "Unseen drain", "Survival", "Physical strength", "Vitality", "State of health"
        ),
        // 宮 9
        listOf(
            "Optimism", "Positivity", "Cheer", "Delight", "Good fortune", "Luck", "Religion",
            "Faith", "Relocation", "Documents", "Paperwork", "Diplomas", "Abroad",
            "Long journeys", "Culture", "Broad-mindedness", "Sunny temperament", "Drive",
            "Ideals", "Kindness", "Moral character", "Blindness", "Arrogance", "Meaning",
            "Opportunity", "Chance"
        ),
        // 宮 10
        listOf(
            "Career", "Gloom", "Suppression", "Discouragement", "Dejection", "Trouble",
            "Difficulty", "Ordeals", "Loss", "Challenge", "Being pushed out", "Vexing matters",
            "Misfortune", "People older than oneself", "Work", "Elders", "Profession",
            "Reputation", "Authority", "Power", "Ability", "Social standing", "Achievement",
            "Government"
        ),
        // 宮 11
        listOf(
            "Friends", "Groups", "Shifts", "Change", "Being set apart", "Difference",
            "Level-headedness", "Reason", "Mental disturbance", "Networks", "Instability",
            "Setbacks", "Running about", "Upheaval", "Being tossed from place to place"
        ),
        // 宮 12
        listOf(
            "Obsession", "Confusion", "Fantasy", "Karmic affinity", "Temper", "Disposition",
            "Conduct", "Morality", "Behind the scenes", "Pessimism", "Escapism", "Sorrow",
            "Sentimentality", "Longing", "Starved of love", "Unspoken love",
            "Fading from view", "Concealment", "Depletion", "Isolation", "Self-dissolution",
            "Karma", "Cycles", "Rebirth", "Reincarnation", "The esoteric", "Metaphysics",
            "Being cut off", "Hiding away", "Deception"
        ),
    )

    // ── 西班牙文 ──

    private val es: List<List<String>> = listOf(
        // 宮 1
        listOf(
            "El yo", "Irritabilidad", "Inquietud", "Volatilidad emocional", "Impulsividad",
            "Ira", "Arrebato de temperamento", "Agitación", "Daño"
        ),
        // 宮 2
        listOf(
            "Comida", "Bienes materiales", "Mi propio dinero",
            "Personas de aspecto fino y agraciado", "Gastos",
            "Riqueza directa (ingresos estables y ganados)", "Valores", "Cognición",
            "Motivación", "La boca"
        ),
        // 宮 3
        listOf(
            "Comunicación", "Conversación", "Pensamiento", "Mentalidad", "Mente ágil",
            "Aprendizaje", "Lenguaje", "Personas más jóvenes que uno", "Iguales", "Colegas",
            "Compañeros de clase", "Compatriotas", "Vecinos", "Hermanos", "Salir", "Estudios",
            "Agilidad", "Estar en movimiento", "Marcharse", "Separación", "Haberse ido",
            "Vivacidad", "Sensación de novedad", "Ánimo", "La tiroides"
        ),
        // 宮 4
        listOf(
            "Hogar", "Sensación de seguridad", "Sensibilidad", "Ansiedad", "Fragilidad",
            "Vacío interior", "Preocupación", "Inquietud", "Introspección",
            "Desgaste interior", "Entorno donde se vive", "Familia de origen",
            "El entorno en que se nació", "País de nacimiento", "Mujeres", "Madre"
        ),
        // 宮 5
        listOf(
            "Ser notado", "Entretenimiento", "Disfrute", "Alegría",
            "Flor de Durazno (atracción amorosa, quienes se sienten atraídos por ti)",
            "Encanto", "Sexo", "Destacar", "Romance", "Hombres", "Ser visto", "Padre"
        ),
        // 宮 6
        listOf(
            "Trabajo penoso", "Ajetreo", "Pensamientos dispersos y desordenados",
            "Agotamiento mental", "Cansancio", "Tensión", "Ser objeto de comentarios",
            "Asuntos cotidianos", "Labor", "Darle demasiadas vueltas", "Socializar",
            "Trato social", "Ideas", "Concentración", "Obsesión", "Asuntos repetitivos",
            "Atención", "Idas y vueltas"
        ),
        // 宮 7
        listOf(
            "Preocuparse por lo que piensan los demás", "Pensamiento fijo en otra persona",
            "Los demás", "Personas que uno conoce", "Lazos que atan",
            "Relaciones de uno a uno", "Compañero de vida", "Pareja",
            "La persona con quien se sale", "Amante", "Personas cercanas", "Matrimonio"
        ),
        // 宮 8
        listOf(
            "Riqueza indirecta (dinero inesperado, no ganado con trabajo)", "Soledad",
            "Aburrimiento", "Tormento", "Ansiedad abrasadora", "Desamparo", "Oscuridad",
            "Dolor", "Sufrimiento", "Sentir que el tiempo se alarga", "El cuerpo",
            "El dinero ajeno", "La privacidad y los secretos de los demás",
            "La vida privada de los demás", "Desgaste oculto", "Supervivencia",
            "Fuerza física", "Energía vital", "Estado de salud"
        ),
        // 宮 9
        listOf(
            "Optimismo", "Actitud positiva", "Alegría", "Deleite", "Buena fortuna", "Suerte",
            "Religión", "Fe", "Traslado", "Documentos", "Papeleo", "Títulos", "El extranjero",
            "Viajes largos", "Cultura", "Amplitud de miras", "Temperamento alegre", "Empuje",
            "Ideales", "Bondad", "Carácter moral", "Ceguera", "Arrogancia", "Significado",
            "Oportunidad", "Ocasión"
        ),
        // 宮 10
        listOf(
            "Carrera", "Melancolía", "Represión", "Desánimo", "Abatimiento", "Problemas",
            "Dificultad", "Pruebas duras", "Pérdida", "Desafío", "Ser apartado",
            "Asuntos molestos", "Infortunio", "Personas mayores que uno", "Trabajo", "Mayores",
            "Profesión", "Reputación", "Autoridad", "Poder", "Capacidad", "Posición social",
            "Logro", "Gobierno"
        ),
        // 宮 11
        listOf(
            "Amigos", "Grupos", "Cambios de rumbo", "Cambio", "Ser distinto", "Diferencia",
            "Serenidad de juicio", "Razón", "Perturbación mental", "Redes", "Inestabilidad",
            "Contratiempos", "Ir de un lado a otro", "Trastorno",
            "Verse llevado de un lugar a otro"
        ),
        // 宮 12
        listOf(
            "Obsesión", "Confusión", "Fantasía", "Afinidad kármica", "Genio", "Carácter",
            "Conducta", "Moralidad", "Entre bastidores", "Pesimismo", "Evasión", "Pena",
            "Sentimentalismo", "Anhelo", "Falta de amor", "Amor callado",
            "Desvanecerse de la vista", "Ocultamiento", "Desgaste", "Aislamiento",
            "Disolución de uno mismo", "Karma", "Ciclos", "Renacimiento", "Reencarnación",
            "Lo esotérico", "Metafísica", "Estar aislado del mundo", "Ocultarse", "Engaño"
        ),
    )

    // ── 義大利文 ──

    private val ita: List<List<String>> = listOf(
        // 宮 1
        listOf(
            "L'io", "Irritabilità", "Irrequietezza", "Instabilità emotiva", "Impulsività",
            "Rabbia", "Scatto d'ira", "Agitazione", "Danno"
        ),
        // 宮 2
        listOf(
            "Cibo", "Beni materiali", "Il mio denaro", "Persone dall'aspetto fine e grazioso",
            "Spese", "Ricchezza diretta (reddito stabile e guadagnato)", "Valori",
            "Cognizione", "Motivazione", "La bocca"
        ),
        // 宮 3
        listOf(
            "Comunicazione", "Conversazione", "Pensiero", "Mentalità", "Mente vivace",
            "Apprendimento", "Linguaggio", "Persone più giovani di sé", "Coetanei", "Colleghi",
            "Compagni di classe", "Connazionali", "Vicini", "Fratelli e sorelle", "Uscire",
            "Studi", "Agilità", "Essere in movimento", "Andarsene", "Separazione",
            "Essere andato via", "Vivacità", "Senso di novità", "Spirito", "La tiroide"
        ),
        // 宮 4
        listOf(
            "Casa", "Senso di sicurezza", "Sensibilità", "Ansia", "Fragilità",
            "Vuoto interiore", "Preoccupazione", "Apprensione", "Introspezione",
            "Logoramento interiore", "Ambiente in cui si vive", "Famiglia d'origine",
            "L'ambiente in cui si è nati", "Paese di nascita", "Donne", "Madre"
        ),
        // 宮 5
        listOf(
            "Essere notati", "Divertimento", "Piacere", "Gioia",
            "Fiore di Pesco (attrazione amorosa, chi si sente attratto da te)", "Fascino",
            "Sesso", "Distinguersi", "Amore", "Uomini", "Essere visti", "Padre"
        ),
        // 宮 6
        listOf(
            "Lavoro gravoso", "Affaccendamento", "Pensieri sparsi e disordinati",
            "Esaurimento mentale", "Stanchezza", "Tensione", "Essere oggetto di chiacchiere",
            "Faccende quotidiane", "Fatica", "Rimuginare", "Socializzare", "Rapporti sociali",
            "Idee", "Concentrazione", "Fissazione", "Cose ripetitive", "Attenzione",
            "Andirivieni"
        ),
        // 宮 7
        listOf(
            "Curarsi di ciò che pensano gli altri", "Pensiero fisso su un'altra persona",
            "Gli altri", "Persone che si incontrano", "Legami che vincolano",
            "Relazioni a due", "Compagno", "Coppia", "La persona che si frequenta", "Amante",
            "Persone vicine", "Matrimonio"
        ),
        // 宮 8
        listOf(
            "Ricchezza indiretta (denaro inatteso, non guadagnato)", "Solitudine", "Noia",
            "Tormento", "Ansia bruciante", "Impotenza", "Oscurità", "Dolore", "Sofferenza",
            "Sentire il tempo lungo", "Il corpo", "Il denaro altrui",
            "La privacy e i segreti altrui", "La vita privata altrui", "Logorio nascosto",
            "Sopravvivenza", "Forza fisica", "Energia vitale", "Stato di salute"
        ),
        // 宮 9
        listOf(
            "Ottimismo", "Positività", "Allegria", "Gioia", "Buona sorte", "Fortuna",
            "Religione", "Fede", "Trasferimento", "Documenti", "Pratiche burocratiche",
            "Diplomi", "L'estero", "Viaggi lunghi", "Cultura", "Apertura mentale",
            "Temperamento solare", "Slancio", "Ideali", "Bontà", "Carattere morale", "Cecità",
            "Arroganza", "Significato", "Opportunità", "Occasione"
        ),
        // 宮 10
        listOf(
            "Carriera", "Malinconia", "Repressione", "Scoraggiamento", "Abbattimento", "Guai",
            "Difficoltà", "Prove dure", "Perdita", "Sfida", "Essere messo da parte",
            "Faccende fastidiose", "Sfortuna", "Persone più grandi di sé", "Lavoro", "Anziani",
            "Professione", "Reputazione", "Autorità", "Potere", "Capacità",
            "Posizione sociale", "Successo", "Governo"
        ),
        // 宮 11
        listOf(
            "Amici", "Gruppi", "Mutamenti", "Cambiamento", "Essere diversi", "Differenza",
            "Lucidità", "Ragione", "Turbamento mentale", "Reti", "Instabilità", "Contrattempi",
            "Correre di qua e di là", "Sconvolgimento",
            "Essere sballottati da un posto all'altro"
        ),
        // 宮 12
        listOf(
            "Ossessione", "Confusione", "Fantasia", "Affinità karmica", "Temperamento",
            "Indole", "Condotta", "Moralità", "Dietro le quinte", "Pessimismo", "Evasione",
            "Tristezza", "Sentimentalismo", "Struggimento", "Mancanza d'amore",
            "Amore taciuto", "Svanire dalla vista", "Occultamento", "Consumo", "Isolamento",
            "Dissoluzione di sé", "Karma", "Cicli", "Rinascita", "Reincarnazione",
            "L'esoterico", "Metafisica", "Essere tagliati fuori", "Nascondersi", "Inganno"
        ),
    )

}
