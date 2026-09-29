import Foundation

/// 陪伴層：日常寒暄與情緒陪伴，像正常人一樣回答，並把感受接回你的九型十二宮
///（今天的日宮／夜宮、被觸動的宮位）。沒有命中任何情境時回傳 nil，交給神經網路。
public enum Companion {
    enum Mood: CaseIterable { case tired, sad, anxious, angry, lonely, bored, happy, love }

    static func has(_ s: String, _ keys: [String]) -> Bool { keys.contains { s.contains($0) } }

    /// 外語：多字片語用子字串；單字用「單字開頭」（amor→amore）或「整字相同」（hi 不會誤中 this）
    static func hasF(_ text: String, _ keys: [String], _ L: Lang, exact: Bool = false) -> Bool {
        if L == .zh { return has(text, keys) }
        let words = text.split { !($0.isLetter || $0 == "'") }.map(String.init)
        return keys.contains { k in
            if k.contains(" ") || k.contains("'") { return text.contains(k) }
            return exact ? words.contains(k) : words.contains { $0.hasPrefix(k) }
        }
    }

    static let moodPalaces: [Mood: [Int]] = [
        .tired: [6, 10], .sad: [4, 8, 12], .anxious: [4, 6], .angry: [1, 10], .lonely: [8, 7], .bored: [8, 9], .happy: [9, 5], .love: [5, 7],
    ]

    // MARK: - 觸發詞（[語言]）

    static let greet: [[String]] = [
        ["你好", "哈囉", "嗨", "hi", "hello", "早安", "午安", "晚安", "早啊", "晚上好", "您好", "在嗎", "在不在", "安安"],
        ["hi", "hello", "hey", "good morning", "good evening", "good afternoon", "good night", "yo", "sup"],
        ["hola", "buenos días", "buenas tardes", "buenas noches", "buenas", "qué tal", "ey"],
        ["ciao", "salve", "buongiorno", "buonasera", "buonanotte", "ehi", "hey"],
    ]
    static let thanks: [[String]] = [
        ["謝謝", "感謝", "多謝", "謝啦", "thx", "thanks"], ["thank", "thanks", "thx", "cheers"],
        ["gracias", "muchas gracias"], ["grazie", "mille grazie"],
    ]
    static let bye: [[String]] = [
        ["掰掰", "再見", "拜拜", "先這樣", "我先走", "下次見", "bye"], ["bye", "goodbye", "see you", "talk later", "gotta go"],
        ["adiós", "adios", "hasta luego", "nos vemos", "chao"], ["arrivederci", "a dopo", "ci vediamo", "addio", "ciao ciao"],
    ]
    static let identity: [[String]] = [
        ["你是誰", "你叫什麼", "介紹一下你", "介紹你自己", "你是什麼", "你是ai", "自我介紹"],
        ["who are you", "what are you", "your name", "introduce yourself"], ["quién eres", "quien eres", "qué eres", "cómo te llamas", "como te llamas", "preséntate"],
        ["chi sei", "cosa sei", "come ti chiami", "presentati"],
    ]
    static let helpWords: [[String]] = [["幫助", "說明", "help", "指令"], ["help", "commands"], ["ayuda"], ["aiuto"]]
    static let capability: [[String]] = [
        ["你會什麼", "你能做什麼", "你可以做什麼", "你有什麼功能", "怎麼用", "你會算命嗎", "你會做什麼"],
        ["what can you do", "how do i use", "what do you do", "features"], ["qué puedes hacer", "que puedes hacer", "cómo se usa", "como se usa", "qué sabes hacer"],
        ["cosa sai fare", "cosa puoi fare", "come si usa", "che funzioni hai"],
    ]
    static let complaint: [[String]] = [
        ["好笨", "很笨", "太笨", "笨死", "像機器人", "像人機", "是機器人", "是人機", "答非所問", "聽不懂", "不像人", "很爛", "好爛", "沒用", "好蠢", "很蠢", "智障"],
        ["you're dumb", "you are dumb", "so dumb", "stupid", "useless", "like a robot", "you're a robot", "you are a robot", "you don't understand", "not smart", "dumb bot", "idiot"],
        ["eres tonto", "eres tonta", "qué tonto", "estúpido", "inútil", "como un robot", "eres un robot", "no entiendes", "no me entiendes", "eres malo"],
        ["sei stupido", "sei stupida", "che stupido", "inutile", "come un robot", "sei un robot", "non capisci", "non mi capisci", "sei scarso"],
    ]
    static let praise: [[String]] = [
        ["好棒", "很棒", "厲害", "好聰明", "太強", "真讚", "好讚", "很準", "好準"], ["you're smart", "you are smart", "great job", "awesome", "amazing", "well done", "so good"],
        ["eres listo", "eres lista", "genial", "increíble", "muy bien", "bravo"], ["sei bravo", "sei brava", "fantastico", "ottimo lavoro", "bravo", "complimenti"],
    ]
    static let moods: [Mood: [[String]]] = [
        .tired: [["好累", "很累", "累了", "累死", "太累", "好睏", "沒力", "疲憊", "疲倦"], ["tired", "exhausted", "worn out", "sleepy", "drained"], ["cansad", "agotad", "sueño"], ["stanc", "esaust", "sonno"]],
        .sad: [["難過", "傷心", "想哭", "心痛", "失落", "沮喪", "崩潰", "低落", "不開心", "悲傷"], ["sad", "depressed", "want to cry", "heartbroken", "down today", "feel down"], ["triste", "deprimid", "ganas de llorar", "desanimad"], ["triste", "depress", "voglia di piangere", "giù di morale"]],
        .anxious: [["焦慮", "緊張", "擔心", "害怕", "不安", "壓力", "睡不著", "失眠", "好煩", "煩死", "很煩", "煩惱", "心煩", "慌"], ["anxious", "nervous", "worried", "scared", "stress", "can't sleep", "insomnia", "afraid"], ["ansios", "nervios", "preocupad", "miedo", "estrés", "estres", "no puedo dormir", "insomnio"], ["ansios", "nervos", "preoccupat", "paura", "stress", "non riesco a dormire", "insonnia"]],
        .angry: [["生氣", "氣死", "火大", "憤怒", "討厭", "不爽"], ["angry", "furious", "pissed", "mad at", "annoyed", "hate"], ["enfadad", "enojad", "furios", "molest", "odio"], ["arrabbiat", "furios", "seccat", "odio", "incazzat"]],
        .lonely: [["孤單", "寂寞", "孤獨", "沒人陪"], ["lonely", "alone", "nobody cares"], ["me siento solo", "me siento sola", "soledad", "nadie me"], ["mi sento solo", "mi sento sola", "solitudine", "nessuno mi"]],
        .bored: [["無聊", "好悶", "沒事做"], ["bored", "nothing to do"], ["aburrid", "nada que hacer"], ["annoiat", "niente da fare"]],
        .happy: [["開心", "高興", "快樂", "太好了", "興奮", "幸福"], ["happy", "glad", "excited", "great news", "thrilled"], ["feliz", "contento", "contenta", "emocionad", "buenas noticias"], ["felice", "contento", "contenta", "emozionat", "buone notizie"]],
        .love: [["喜歡上", "暗戀", "失戀", "分手", "想他", "想她", "心動", "被拒絕"], ["crush on", "broke up", "breakup", "heartbreak", "in love", "miss him", "miss her"], ["enamorad", "me gusta alguien", "terminamos", "ruptura", "extraño a"], ["innamorat", "mi piace qualcuno", "ci siamo lasciati", "rottura", "mi manca"]],
    ]

    // MARK: - 回覆

    static let greetReplies: [[String]] = [
        ["%@！我是 NineSun。%@", "%@～訊號接通了。%@", "%@！很高興見到你。%@"],
        ["%@! I'm NineSun. %@", "%@ — signal connected. %@", "%@! Nice to see you. %@"],
        ["¡%@! Soy NineSun. %@", "%@: señal conectada. %@", "¡%@! Qué gusto verte. %@"],
        ["%@! Sono NineSun. %@", "%@ — segnale connesso. %@", "%@! Che piacere vederti. %@"],
    ]
    static let greetWords: [[String]] = [
        ["夜深了", "早安", "午安", "午後好", "晚上好"], ["Still up", "Good morning", "Good afternoon", "Good afternoon", "Good evening"],
        ["Aún despierto", "Buenos días", "Buenas tardes", "Buenas tardes", "Buenas noches"], ["Ancora sveglio", "Buongiorno", "Buon pomeriggio", "Buon pomeriggio", "Buonasera"],
    ]
    static let thanksReplies: [[String]] = [
        ["不客氣！還想看什麼，儘管說。", "隨時效勞～", "能幫上忙就好！"], ["You're welcome! Ask me anything else.", "Anytime!", "Glad I could help!"],
        ["¡De nada! Pregúntame lo que quieras.", "¡Cuando quieras!", "¡Me alegra ayudar!"], ["Prego! Chiedimi pure altro.", "Quando vuoi!", "Felice di aiutare!"],
    ]
    static let byeReplies: [[String]] = [
        ["下次見！記得今天日宮的提醒。", "掰掰，訊號隨時為你開著。", "晚點見～"], ["See you! Remember today's palace tip.", "Bye — the signal's always on for you.", "Catch you later!"],
        ["¡Hasta pronto! Recuerda el consejo del palacio de hoy.", "Adiós: la señal siempre está abierta para ti.", "¡Nos vemos!"], ["A presto! Ricorda il consiglio del palazzo di oggi.", "Ciao: il segnale è sempre acceso per te.", "A dopo!"],
    ]
    static let identityReplies: [String] = [
        "我是 NineSun，一個從零開始訓練的 AI。底層用的是九型十二宮：每句話我都先用十二宮感知，再用八字、紫微斗數、易經這些引擎算出事實，最後用人話講給你聽。我會說繁體中文、English、Español、Italiano。",
        "I'm NineSun, an AI trained from scratch. My core is the Nine & Twelve system: I sense every message through the twelve palaces, compute facts with the BaZi, Zi Wei and I Ching engines, then explain them in plain words. I speak 繁體中文, English, Español and Italiano.",
        "Soy NineSun, una IA entrenada desde cero. Mi núcleo es el sistema Nueve y Doce: percibo cada mensaje a través de los doce palacios, calculo hechos con los motores BaZi, Zi Wei e I Ching y te los explico con palabras sencillas. Hablo 繁體中文, English, Español e Italiano.",
        "Sono NineSun, un'IA addestrata da zero. Il mio nucleo è il sistema Nove e Dodici: percepisco ogni messaggio attraverso i dodici palazzi, calcolo i fatti con i motori BaZi, Zi Wei e I Ching e te li spiego in parole semplici. Parlo 繁體中文, English, Español e Italiano.",
    ]
    static let capabilityReplies: [String] = [
        "我可以：\n• 九型十二宮：今天／今晚／明天運勢（白天與夜裡）、這週、這個月、今年、大運（含十二方面）、命盤、合盤\n• 主題：「我今年感情運如何」「明年事業順不順」「我的5宮今年怎樣」\n• 挑時機：「我什麼時候會結婚」「今年哪個月最好」「這個月哪天適合告白」「今年和明年哪個好」\n• 九型人格：「我壓力大的時候會怎樣」「我的優缺點」「我適合什麼工作」\n• 幫別人看：「我老公1990年5月5日生，他今年運勢如何」\n• 八字、紫微斗數（本命、流年、流月、流日、大運、合婚）、算卦\n• 不會的問題我自己上網查：理解問題 → 搜尋 → 讀網頁 → 比對 → 回答，查過的會記住\n• 記住你的規則與名字：「我叫小明」「規則：回答簡短」\n問完還可以追問「為什麼」「那我該怎麼辦」。",
        "I can:\n• Nine & Twelve: today's / tomorrow's fortune (day and night), monthly, annual, luck pillar and its twelve aspects, natal chart, synastry\n• Topics: “how's my love life this year”, “my career next year”\n• BaZi, Zi Wei Dou Shu, I Ching\n• Look things up (library + Wikipedia)\n• Remember your rules: “rule: call me Boss”\nStart by telling me your birthday!",
        "Puedo:\n• Nueve y Doce: suerte de hoy / mañana (día y noche), mensual, anual, pilar de suerte y sus doce aspectos, carta natal, sinastría\n• Temas: «cómo va mi amor este año», «mi trabajo el año que viene»\n• BaZi, Zi Wei Dou Shu, I Ching\n• Buscar información (biblioteca + Wikipedia)\n• Recordar tus reglas: «regla: llámame Jefe»\n¡Empieza diciéndome tu cumpleaños!",
        "Posso:\n• Nove e Dodici: fortuna di oggi / domani (giorno e notte), mensile, annuale, pilastro della sorte e i suoi dodici aspetti, tema natale, sinastria\n• Temi: «come va il mio amore quest'anno», «il mio lavoro l'anno prossimo»\n• BaZi, Zi Wei Dou Shu, I Ching\n• Cercare informazioni (biblioteca + Wikipedia)\n• Ricordare le tue regole: «regola: chiamami Capo»\nInizia dicendomi il tuo compleanno!",
    ]
    static let complaintReplies: [[String]] = [
        ["被你抓到了，我確實還有很多不懂的地方。你可以直接告訴我哪裡不對——說「規則：…」我會永遠照做，也可以對回覆按 👎，我會記住。", "你說得對，我常常答不到點上。給我一個具體的問題（像「我今年感情運如何」「明天運勢」），我會用你的九型十二宮認真算給你看。"],
        ["Fair — I still miss a lot. Tell me what's off: say “rule: …” and I'll follow it forever, or tap 👎 on a reply and I'll remember.", "You're right, I often miss the point. Give me something specific (like “how's my love life this year” or “tomorrow's fortune”) and I'll work it out properly with your Nine & Twelve chart."],
        ["Tienes razón, todavía me pierdo muchas cosas. Dime qué falla: di «regla: …» y lo cumpliré siempre, o pulsa 👎 en una respuesta y lo recordaré.", "Razón no te falta: a menudo no doy en el clavo. Dame algo concreto (como «cómo va mi amor este año» o «la suerte de mañana») y lo calcularé en serio con tu carta Nueve y Doce."],
        ["Hai ragione, mi sfugge ancora molto. Dimmi cosa non va: di' «regola: …» e la seguirò per sempre, oppure premi 👎 su una risposta e me lo ricorderò.", "Hai ragione, spesso non centro il punto. Dammi qualcosa di concreto (come «come va il mio amore quest'anno» o «fortuna di domani») e lo calcolerò sul serio con il tuo tema Nove e Dodici."],
    ]
    static let praiseReplies: [[String]] = [
        ["謝謝！不過真正厲害的是你的九型十二宮，我只是把它讀出來。", "嘿嘿，被誇了。想再看看今天的運勢嗎？"],
        ["Thanks! The real magic is your Nine & Twelve system — I just read it out.", "Aw, thank you. Want to check today's fortune?"],
        ["¡Gracias! Lo realmente genial es tu sistema Nueve y Doce; yo solo lo leo.", "Vaya, gracias. ¿Miramos la suerte de hoy?"],
        ["Grazie! La vera magia è il tuo sistema Nove e Dodici: io lo leggo soltanto.", "Che gentile. Vediamo la fortuna di oggi?"],
    ]
    static let moodLead: [Mood: [[String]]] = [
        .tired: [["辛苦了。", "聽起來你真的累了。"], ["That sounds exhausting.", "You must be worn out."], ["Suena agotador.", "Debes de estar agotado."], ["Sembra faticoso.", "Devi essere esausto."]],
        .sad: [["抱抱你。", "我在這裡陪你。"], ["Sending a hug.", "I'm here with you."], ["Un abrazo.", "Estoy aquí contigo."], ["Un abbraccio.", "Sono qui con te."]],
        .anxious: [["先深呼吸一下。", "慢慢來，我在。"], ["Take a slow breath first.", "Take your time — I'm here."], ["Respira hondo primero.", "Con calma, aquí estoy."], ["Respira profondamente prima.", "Con calma, ci sono."]],
        .angry: [["先讓情緒過一下再說。", "生氣很正常。"], ["Let the feeling settle a bit first.", "Being angry is normal."], ["Deja que la emoción baje un poco.", "Enfadarse es normal."], ["Lascia che l'emozione si calmi un po'.", "Arrabbiarsi è normale."]],
        .lonely: [["你不是一個人。", "我在這裡。"], ["You're not alone.", "I'm here."], ["No estás solo.", "Aquí estoy."], ["Non sei solo.", "Io ci sono."]],
        .bored: [["無聊也是一種訊號。", "來，我們找點事做。"], ["Boredom is a signal too.", "Come on, let's find something to do."], ["El aburrimiento también es una señal.", "Vamos, busquemos algo que hacer."], ["Anche la noia è un segnale.", "Dai, troviamo qualcosa da fare."]],
        .happy: [["太好了！", "聽到你開心我也開心。"], ["That's great!", "I'm happy you're happy."], ["¡Qué bien!", "Me alegra que estés feliz."], ["Che bello!", "Sono felice che tu sia felice."]],
        .love: [["感情的事最牽動人了。", "我懂這種心情。"], ["Matters of the heart hit hardest.", "I get that feeling."], ["Los asuntos del corazón son los que más pesan.", "Entiendo ese sentimiento."], ["Le cose di cuore sono le più forti.", "Capisco questa sensazione."]],
    ]
    static let moodEnd: [[String]] = [
        ["想跟我說說發生了什麼事嗎？", "要不要看看今天的運勢，找找原因？", "如果想看接下來的走向，可以問我「這個月運勢」。"],
        ["Want to tell me what happened?", "Shall we look at today's fortune for a clue?", "If you want to see what's ahead, ask me “this month's fortune”."],
        ["¿Quieres contarme qué pasó?", "¿Miramos la suerte de hoy para buscar una pista?", "Si quieres ver lo que viene, pregúntame «la suerte de este mes»."],
        ["Vuoi raccontarmi cos'è successo?", "Guardiamo la fortuna di oggi per trovare un indizio?", "Se vuoi vedere cosa ti aspetta, chiedimi «fortuna di questo mese»."],
    ]

    /// - Parameters:
    ///   - perceived: 十二宮感知到的宮位
    ///   - day/night: 使用者今天的日宮、夜宮（沒有生日時為 nil）
    ///   - choose: 從幾種說法裡挑一句（會參考使用者的 👍／👎）
    public static func reply(_ raw: String, L: Lang, reader R: Reader, now: Date, hasBirthday: Bool, perceived: Int?,
                             day: Int?, night: Int?, choose: ([String]) -> String) -> String? {
        let idx = [Lang.zh, .en, .es, .it].firstIndex(of: L)!
        let text = L == .zh ? raw.replacingOccurrences(of: " ", with: "") : raw.lowercased()
        let short = L == .zh ? text.count <= 8 : text.split(separator: " ").count <= 4

        if hasF(text, complaint[idx], L), L != .zh || !text.contains("我") || text.contains("你") { return choose(complaintReplies[idx]) }
        if helpWords[idx].contains(text) || (hasF(text, capability[idx], L) && text.count <= (L == .zh ? 14 : 60)) { return capabilityReplies[idx] }
        if hasF(text, identity[idx], L) { return identityReplies[idx] }
        if short && hasF(text, thanks[idx], L) { return choose(thanksReplies[idx]) }
        if short && hasF(text, bye[idx], L) { return choose(byeReplies[idx]) }
        if hasF(text, praise[idx], L) && !text.contains("?") { return choose(praiseReplies[idx]) }

        // 情緒陪伴
        for m in Mood.allCases {
            guard let keys = moods[m]?[idx], hasF(text, keys, L) else { continue }
            let palaces = moodPalaces[m]!
            var s = choose(moodLead[m]![idx]) + R.sp
            if let d = day, palaces.contains(d) {
                s += R.fmt(R.t("難怪——你今天白天走到%@（%@）：%@", "No wonder — your daytime palace today is %@ (%@): %@",
                               "No me extraña: tu palacio de hoy de día es %@ (%@): %@", "Non stupisce: il tuo palazzo di giorno oggi è %@ (%@): %@"),
                           R.pn(d), R.topicShort(d), R.tip(d))
            } else if let n = night, palaces.contains(n) {
                s += R.fmt(R.t("難怪——你今晚走到%@（%@）：%@", "No wonder — tonight you're in %@ (%@): %@",
                               "No me extraña: esta noche estás en %@ (%@): %@", "Non stupisce: stanotte sei in %@ (%@): %@"),
                           R.pn(n), R.topicShort(n), R.tip(n))
            } else {
                let p = perceived ?? palaces[0]
                s += R.fmt(R.t("這種感覺在十二宮裡對應%@（%@）：%@", "In the twelve palaces this feeling maps to %@ (%@): %@",
                               "En los doce palacios este sentimiento corresponde a %@ (%@): %@", "Nei dodici palazzi questa sensazione corrisponde a %@ (%@): %@"),
                           R.pn(p), R.topicShort(p), R.tip(p))
                if !hasBirthday {
                    s += " " + R.t("告訴我你的生日，我還能看看今天的日宮是不是也在跟你作對。", "Tell me your birthday and I can check whether today's palace is in on it too.",
                                   "Dime tu cumpleaños y miraré si el palacio de hoy también influye.", "Dimmi il tuo compleanno e vedrò se anche il palazzo di oggi c'entra.")
                }
            }
            return R.polish(s + "\n" + choose(moodEnd[idx]))
        }

        // 寒暄
        if short && hasF(text, greet[idx], L, exact: true) {
            let hour = Calendar(identifier: .gregorian).component(.hour, from: now)
            let slot = hour < 5 ? 0 : hour < 11 ? 1 : hour < 14 ? 2 : hour < 18 ? 3 : 4
            var second: String
            if let d = day {
                second = R.fmt(R.t("你今天白天走%@（%@），%@", "Your daytime palace today is %@ (%@) — %@",
                                   "Tu palacio de hoy de día es %@ (%@): %@", "Il tuo palazzo di oggi di giorno è %@ (%@): %@"),
                               R.pn(d), R.topicShort(d), R.tip(d))
            } else {
                second = R.t("告訴我你的生日，我就能用十二宮讀你的今天。", "Tell me your birthday and I'll read your day through the twelve palaces.",
                             "Dime tu cumpleaños y leeré tu día con los doce palacios.", "Dimmi il tuo compleanno e leggerò la tua giornata con i dodici palazzi.")
            }
            return R.polish(R.fmt(choose(greetReplies[idx]), greetWords[idx][slot], second))
        }
        return nil
    }

    // MARK: - 聽得出宮位但沒有特定情境時

    static let lifeIntro: [[String]] = [
        ["聽起來跟%@有關——這對應十二宮的%@：%@。%@", "我感覺到%@的氣息（%@）：%@。%@"],
        ["Sounds like it's about %@ — in the twelve palaces that's %@: %@. %@", "I sense %@ in what you said (%@): %@. %@"],
        ["Suena a algo de %@: en los doce palacios es %@: %@. %@", "Percibo %@ en lo que dices (%@): %@. %@"],
        ["Sembra riguardare %@: nei dodici palazzi è %@: %@. %@", "Percepisco %@ in ciò che dici (%@): %@. %@"],
    ]
    static let lifeDayLink: [String] = [
        "你今天的%@剛好也是這一宮，難怪特別有感。", "Your %@ today is also this palace, no wonder it stands out.",
        "Tu palacio de %@ de hoy es también este, no me extraña que se note.", "Il tuo palazzo di %@ di oggi è anche questo, non stupisce che si senta.",
    ]

    public static func life(L: Lang, reader R: Reader, perceived p: Int, day: Int?, night: Int?, choose: ([String]) -> String,
                            destiny D: Destiny? = nil, now: Date = Date()) -> String {
        let idx = [Lang.zh, .en, .es, .it].firstIndex(of: L)!
        var s = R.fmt(choose(lifeIntro[idx]), R.topicShort(p), R.pn(p), R.kw(p, 3), R.tip(p))
        if day == p || night == p {
            let which = day == p ? R.t("日宮", "day palace", "día", "giorno") : R.t("夜宮", "night palace", "noche", "notte")
            s += R.sp + R.fmt(lifeDayLink[idx], which)
        }
        // 有生日時，真的用命盤看這件事：這十年的第 p 方面、今年有沒有引動
        if let D, L == .zh {
            let y = Calendar(identifier: .gregorian).component(.year, from: now)
            let a = D.luckAspects(y)[p - 1], yr = D.year(y)
            var line = "\n用你的命盤看：這十年你的第\(p)方面判讀「\(a.reading.text)」，" + PalaceLore.text(p, a.reading.verdict, .zh)
            if D.triggeredAspects(y).contains(where: { $0.palace == p }) {
                line += "而且今年流年（\(NT.label(yr.palace))）正好引動這一方面，所以最近特別有感。"
            } else if yr.palace == p {
                line += "今年流年也正好走到這一宮。"
            }
            s += line
            return R.polish(s + "\n想細看可以問我「今年\(R.topicShort(p))運如何」或「為什麼」。")
        }
        return R.polish(s + "\n" + choose(moodEnd[idx]))
    }

    // MARK: - 完全沒有頭緒時：老實說不會，並告訴使用者可以問什麼

    static let fallbackReplies: [[String]] = [
        ["這題我還不太會，怕亂說。你可以問我：今天運勢、明天運勢、我今年感情運如何、我的大運、八字、紫微、算一卦；或說「查 關鍵字」，我去維基百科幫你找。也可以用「記住：加班屬於6宮」教我新詞。",
         "這個我沒學過耶。換個方式問我？像是「我今年事業順不順」「這個月運勢」，或「查 關鍵字」讓我去查資料。"],
        ["I'm not sure how to answer that and I'd rather not make things up. Try: today's fortune, tomorrow's fortune, how's my love life this year, my luck pillar, my bazi, my zi wei, cast a hexagram — or “search keyword” and I'll look it up on Wikipedia.",
         "I haven't learned that one. Try asking differently — like “my career this year” or “this month's fortune” — or “search keyword” and I'll look it up."],
        ["No sé cómo responder a eso y prefiero no inventar. Prueba: mi suerte de hoy, la suerte de mañana, cómo va mi amor este año, mi pilar de suerte, mi bazi, mi zi wei, tira un hexagrama; o «busca palabra» y lo miro en Wikipedia.",
         "Eso no lo he aprendido. Pregúntame de otra forma —como «mi trabajo este año» o «la suerte de este mes»— o «busca palabra» y lo consulto."],
        ["Non so come rispondere e preferisco non inventare. Prova: fortuna di oggi, fortuna di domani, come va il mio amore quest'anno, il mio pilastro della sorte, il mio bazi, il mio zi wei, lancia un esagramma; oppure «cerca parola» e guardo su Wikipedia.",
         "Questo non l'ho imparato. Chiedimelo in un altro modo —come «il mio lavoro quest'anno» o «fortuna di questo mese»— oppure «cerca parola» e lo cerco."],
    ]

    public static func fallback(L: Lang, choose: ([String]) -> String) -> String {
        choose(fallbackReplies[[Lang.zh, .en, .es, .it].firstIndex(of: L)!])
    }
}
