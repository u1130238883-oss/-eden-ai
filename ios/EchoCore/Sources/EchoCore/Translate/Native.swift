import Foundation

/// 母語人士真正會說的講法：機器翻譯常常逐字直譯（「加油」→ "Add oil"、「辛苦了」→ "You have worked hard"），
/// 這些常用說法直接用道地的版本。只收直譯會怪的口語，一般句子還是交給翻譯引擎。
/// 每行「中文說法（/分開）|English|Español|Italiano」；中文那格之外的第一個是翻出來用的，其他的是「也可以說」。
public enum Native {
    struct Entry { let zh: [String]; let en: [String]; let es: [String]; let it: [String] }

    static let entries: [Entry] = table.split(separator: "\n").compactMap { line in
        let c = line.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        guard c.count == 4 else { return nil }
        return Entry(zh: c[0], en: c[1], es: c[2], it: c[3])
    }

    static func key(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .filter { $0.isLetter || $0.isNumber || $0 == "'" || $0 == " " }
            .split(separator: " ").joined(separator: " ")
    }

    private static let index: [String: [String: Int]] = {
        var ix: [String: [String: Int]] = [:]
        for (i, e) in entries.enumerated() {
            for (l, forms) in [("zh", e.zh), ("en", e.en), ("es", e.es), ("it", e.it)] {
                for f in forms where ix[l]?[key(f)] == nil { ix[l, default: [:]][key(f)] = i }
            }
        }
        return ix
    }()

    /// 有道地講法就直接給（譯文＋其他說法）；沒有回 nil
    public static func lookup(_ r: Translate.Request) -> Translate.Result? {
        guard let tl = r.target.lex, ["zh", "en", "es", "it"].contains(tl) else { return nil }
        let k = key(r.text)
        guard !k.isEmpty else { return nil }
        // 中文句尾的語氣詞不影響意思（「我好累啊」＝「我好累」）
        let k2 = key(r.text.replacingOccurrences(of: "[啊呀喔哦啦耶欸嘛吧～~！!。？?]+$", with: "", options: .regularExpression))
        let order = ((r.source?.lex).map { [$0] } ?? []) + ["zh", "en", "es", "it"]
        // 外文的單字一字多義（ojo 是眼睛也是「小心」、tranquilo 是安靜也是「沒事」）：單字不查這張表，交給翻譯
        let single = !k.contains(" ") && r.text.unicodeScalars.allSatisfy { !(0x4E00...0x9FFF).contains($0.value) }
        for l in order where l != tl && !(single && l != "zh") {
            guard let i = index[l]?[k] ?? index[l]?[k2] else { continue }
            let e = entries[i]
            let out: [String]
            switch tl {
            case "zh": out = e.zh
            case "en": out = e.en
            case "es": out = e.es
            default: out = e.it
            }
            guard let first = out.first else { return nil }
            let src: Translate.Code = l == "zh" ? .zh : Translate.Code(rawValue: l) ?? .en
            return Translate.Result(text: first, alternatives: Array(out.dropFirst().prefix(2)), source: src, via: "道地說法")
        }
        return nil
    }

    // 中文|English|Español|Italiano
    static let table = """
加油/加油喔/你可以的|You've got this!/You can do it!/Go for it!|¡Ánimo!/¡Tú puedes!/¡Dale!|Forza!/Dai, ce la puoi fare!/In bocca al lupo!
辛苦了/辛苦你了|Thanks for all your hard work./Thanks, I appreciate it.|Gracias por tu esfuerzo./Buen trabajo.|Grazie per tutto il lavoro./Ottimo lavoro.
吃飯了嗎/你吃飯了嗎/吃飽了嗎/吃了嗎|Have you eaten yet?/How's it going?|¿Ya comiste?/¿Qué tal?|Hai già mangiato?/Come va?
你有沒有吃飯/你有吃飯嗎|Have you eaten yet?|¿Ya comiste?|Hai già mangiato?
不好意思|Excuse me./Sorry about that.|Perdona./Disculpa.|Scusa./Scusami.
不好意思打擾了/打擾了/打擾一下|Sorry to bother you.|Perdona que te moleste.|Scusa il disturbo.
麻煩你了/麻煩了|Thanks so much, I owe you one./Thanks for your help.|Te lo agradezco mucho./Gracias por la molestia.|Grazie mille, sei gentilissimo./Ti ringrazio.
隨便/都可以/都好|Whatever works for you./Either is fine./I'm easy.|Lo que tú quieras./Me da igual.|Come vuoi tu./Per me è uguale.
隨便你|Suit yourself./It's up to you.|Como quieras.|Fai come vuoi.
沒關係/不要緊|No worries./It's okay./Don't worry about it.|No pasa nada./No te preocupes.|Non fa niente./Non ti preoccupare.
沒事/沒事啦|It's fine./No worries./I'm okay.|No pasa nada./Tranquilo.|Niente./Tranquillo./Tutto a posto.
算了/算了吧|Forget it./Never mind.|Olvídalo./Déjalo.|Lascia stare./Lascia perdere.
好久不見|Long time no see!/It's been ages!|¡Cuánto tiempo!/¡Tanto tiempo sin verte!|Da quanto tempo!/Quanto tempo!
請多指教/請多多指教|Nice to meet you, I look forward to working with you.|Encantado de conocerte./Un placer.|Piacere di conoscerti.
慢走/路上小心|Take care!/Get home safe!|¡Cuídate!/¡Ve con cuidado!|Stammi bene!/Fai attenzione per strada!
一路順風/一路平安|Have a safe trip!|¡Buen viaje!|Buon viaggio!
慢慢吃|Enjoy your meal!/Take your time.|¡Buen provecho!/¡Que aproveche!|Buon appetito!
我開動了/開動了|Let's eat!|¡A comer!/¡Buen provecho!|Buon appetito!
多喝熱水|Stay warm and drink plenty of fluids.|Bebe mucho líquido y abrígate.|Bevi tanto e stai al caldo.
你先忙/你先忙吧|I'll let you get back to it./I'll let you go.|Te dejo, que estás ocupado.|Ti lascio lavorare.
改天再聊/下次再聊|Let's catch up another time./Talk soon!|Hablamos otro día./¡Hablamos!|Ci sentiamo un'altra volta./Ci sentiamo!
再說吧/到時候再說|Let's see./We'll see when we get there.|Ya veremos.|Vedremo./Si vedrà.
看情況|It depends./We'll see.|Depende.|Dipende.
真的假的/真的嗎|No way!/Seriously?/Really?|¿En serio?/¿De verdad?|Davvero?/Ma dai!/Sul serio?
太扯了/太誇張了|That's ridiculous!/No way!|¡Qué fuerte!/¡Qué exagerado!|Assurdo!/Ma dai, esagerato!
傻眼/我傻眼了|I was speechless./I couldn't believe it.|Me quedé sin palabras./Me quedé de piedra.|Sono rimasto senza parole.
好可惜/太可惜了/可惜|What a shame!/That's too bad.|¡Qué pena!/¡Qué lástima!|Che peccato!
好吧|Fine./Okay then./Alright.|Bueno./Vale./Está bien.|Va bene./D'accordo.
沒問題|No problem!/Sure thing!|¡No hay problema!/¡Claro!|Nessun problema!/Certo!
拜託/拜託啦|Please!/Come on, please!|¡Porfa!/¡Por favor!|Ti prego!/Dai, per favore!
哪裡哪裡/過獎了|Oh, you're too kind!|¡Qué va!/Me halagas.|Ma figurati!/Sei troppo gentile.
不客氣/不用謝|You're welcome!/No problem!/Anytime!|¡De nada!/¡No hay de qué!|Prego!/Figurati!/Di niente!
非常感謝/多謝/太感謝了|Thank you so much!/Many thanks!|¡Muchas gracias!|Grazie mille!
謝謝你/謝啦/感謝|Thank you!/Thanks!/Thanks a lot!|¡Gracias!/¡Muchas gracias!|Grazie!/Grazie mille!
早安|Good morning!/Morning!|¡Buenos días!|Buongiorno!
晚安|Good night!/Sleep well!|¡Buenas noches!/¡Que descanses!|Buonanotte!/Dormi bene!
你好/您好/哈囉|Hi!/Hello!|¡Hola!|Ciao!/Salve!
你好嗎/最近好嗎/最近怎麼樣|How are you?/How's it going?|¿Qué tal?/¿Cómo estás?|Come stai?/Come va?
我很好/還不錯|I'm good, thanks!/Not bad!|¡Bien, gracias!/¡Todo bien!|Bene, grazie!/Tutto bene!
你在幹嘛/你在做什麼/在幹嘛|What are you up to?/What are you doing?|¿Qué haces?/¿Qué estás haciendo?|Che fai?/Cosa stai facendo?
我很想你/好想你/我想你|I miss you so much./I miss you.|Te echo mucho de menos./Te extraño.|Mi manchi tanto./Mi manchi.
我愛你|I love you.|Te quiero./Te amo.|Ti amo./Ti voglio bene.
我喜歡你|I like you./I have a crush on you.|Me gustas.|Mi piaci.
你很漂亮/妳很漂亮/你好漂亮/妳好漂亮|You look beautiful./You're gorgeous.|Estás guapísima./Eres preciosa.|Sei bellissima./Sei proprio bella.
你很帥/你好帥|You look great./You're so handsome.|Estás guapísimo./Qué guapo eres.|Sei bellissimo./Che bello che sei.
生日快樂|Happy birthday!|¡Feliz cumpleaños!|Buon compleanno!/Tanti auguri!
新年快樂|Happy New Year!|¡Feliz Año Nuevo!|Buon anno!/Felice anno nuovo!
恭喜發財|Wishing you a prosperous New Year!|¡Próspero Año Nuevo!|Buon anno, e che sia prospero!
恭喜/恭喜你|Congrats!/Congratulations!|¡Felicidades!/¡Enhorabuena!|Congratulazioni!/Complimenti!
祝你好運|Good luck!/Fingers crossed!|¡Mucha suerte!|In bocca al lupo!/Buona fortuna!
保重/保重身體|Take care of yourself.|Cuídate mucho.|Abbi cura di te./Riguardati.
早點睡/早點休息|Get some rest./Don't stay up too late.|Descansa./No te acuestes tarde.|Riposati./Non fare tardi.
小心/注意|Watch out!/Be careful!|¡Cuidado!/¡Ojo!|Attento!/Occhio!
等一下/等等/稍等|Hang on a sec./Just a moment.|Un momento./Espera un segundo.|Un attimo./Aspetta un secondo.
怎麼了/怎麼啦|What's wrong?/What's up?|¿Qué pasa?/¿Qué te pasa?|Che c'è?/Cosa succede?
我不知道/不知道耶|I don't know./No idea.|No sé./Ni idea.|Non lo so./Boh.
我懂/我懂你/我明白|I get it./I know what you mean.|Te entiendo./Ya veo.|Ti capisco./Capisco.
我累死了/累死了/好累/我好累/我很累|I'm exhausted./I'm wiped out.|Estoy muerto./Estoy agotado.|Sono distrutto./Sono stanchissimo.
我餓死了/餓死了|I'm starving!|¡Me muero de hambre!|Muoio di fame!
我想去吃飯/想去吃飯/我要去吃飯/去吃飯|I want to go eat./I'm going to grab something to eat.|Quiero ir a comer.|Voglio andare a mangiare./Vado a mangiare.
我們去吃飯吧/一起去吃飯/一起吃飯吧/去吃飯吧|Let's go get something to eat!|¡Vamos a comer!|Andiamo a mangiare!
吃飯|eat/have a meal|comer|mangiare
你想吃什麼/想吃什麼|What do you feel like eating?|¿Qué te apetece comer?|Cosa ti va di mangiare?
我吃飽了/吃飽了|I'm full.|Estoy lleno./Ya comí suficiente.|Sono pieno./Sono sazio.
吃早餐/吃早飯|have breakfast|desayunar|fare colazione
吃午餐/吃午飯|have lunch|comer/almorzar|pranzare
吃晚餐/吃晚飯|have dinner|cenar|cenare
好吃/很好吃/超好吃|This is delicious!/So good!|¡Qué rico!/¡Está buenísimo!|Buonissimo!/Che buono!
買單/結帳|Check, please./Can I get the bill?|La cuenta, por favor.|Il conto, per favore.
多少錢/這個多少錢|How much is this?|¿Cuánto cuesta?/¿Cuánto es?|Quanto costa?/Quant'è?
廁所在哪裡/洗手間在哪裡/請問廁所在哪|Where's the restroom?/Where's the bathroom?|¿Dónde está el baño?|Dov'è il bagno?
好麻煩/很麻煩/好煩|What a pain./That's so annoying.|¡Qué rollo!/¡Qué lata!|Che seccatura!/Che palle!
好無聊|I'm so bored./This is boring.|¡Qué aburrido!/Me aburro.|Che noia!/Mi annoio.
我也是|Me too!/Same here.|Yo también.|Anch'io.
當然/當然啊|Of course!/Sure!|¡Claro!/¡Por supuesto!|Certo!/Ovvio!
不會吧|No way!/You're kidding!|¡No me digas!/¡No puede ser!|Non ci credo!/Ma no!
好啊/好呀/好喔|Sure!/Sounds good!|¡Vale!/¡Dale!/¡Claro!|Va bene!/Volentieri!/Certo!
走吧/我們走吧|Let's go!|¡Vamos!/¡Vámonos!|Andiamo!
等你喔/等你|I'll be waiting for you.|Te espero.|Ti aspetto.
晚點聊/待會聊|Talk to you later!|Hablamos luego.|Ci sentiamo dopo.
明天見|See you tomorrow!|¡Hasta mañana!|A domani!
再見/掰掰/拜拜|Bye!/See you!|¡Adiós!/¡Chao!/¡Hasta luego!|Ciao!/Arrivederci!
"""
}
