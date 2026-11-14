// 由 ai/idioms/gen_swift.py 產生，不要手改。資料在 ai/idioms/idioms.py

enum IdiomData {
    /// 成語|意思|English|Español|Italiano|語氣
    static let table = """
鍥而不捨|堅持到底、不放棄|persevere to the end/never give up|perseverar hasta el final/no rendirse nunca|perseverare fino in fondo/non mollare mai|鼓勵,努力
持之以恆|長久堅持下去|keep at it/stick with it|ser constante|essere costante|鼓勵,努力
堅持不懈|一直堅持、不鬆懈|keep going without letup|perseverar sin descanso|perseverare senza sosta|鼓勵,努力
滴水穿石|小小的力量持續下去也能成功|constant dripping wears away the stone|la gota de agua horada la piedra|la goccia scava la pietra|鼓勵,努力,道理
鐵杵磨成針|有恆心，再難的事也能做成|little strokes fell great oaks|poco a poco se va lejos|piano piano si va lontano|鼓勵,努力
有志者事竟成|有決心就一定能成功|where there's a will there's a way|querer es poder|volere è potere|鼓勵,道理
三天打魚兩天曬網|做事沒有恆心，時做時停|blow hot and cold|hacer las cosas a ratos|fare le cose a singhiozzo|提醒,批評
一曝十寒|努力一下就停很久|work by fits and starts|trabajar a trompicones|lavorare a sprazzi|提醒,批評
半途而廢|做到一半就放棄|give up halfway|abandonar a medio camino|lasciare a metà|提醒,批評
虎頭蛇尾|開頭很好，結尾很差|start strong and fizzle out|empezar con fuerza y acabar en nada|partire in quarta e finire in niente|提醒,批評
有始有終|做事有開頭也有結尾|see it through|terminar lo que se empieza|portare a termine ciò che si inizia|稱讚,努力
全力以赴|用盡全力去做|go all out/give it your all|darlo todo|dare il massimo|鼓勵,努力
奮發圖強|振作起來，努力求進步|strive to improve oneself|esforzarse por superarse|impegnarsi per migliorarsi|鼓勵,努力
自強不息|不斷努力向上|strive ceaselessly|superarse sin cesar|migliorarsi senza sosta|鼓勵,努力
一鼓作氣|趁著士氣旺盛，一口氣完成|in one go/at one stroke|de un tirón|tutto d'un fiato|鼓勵
再接再厲|繼續努力，更進一步|keep up the good work|sigue así|continua così|鼓勵,稱讚
精益求精|已經很好了還要更好|strive for perfection|buscar siempre la perfección|cercare sempre la perfezione|稱讚,努力
勤能補拙|勤奮可以彌補天分不足|hard work makes up for lack of talent|el trabajo suple la falta de talento|l'impegno compensa il talento|鼓勵,道理
臨陣磨槍|事到臨頭才準備|sharpen the spear before battle|prepararse a última hora|prepararsi all'ultimo minuto|幽默,提醒
臨時抱佛腳|平時不準備，臨時才急著想辦法|cram at the last minute|estudiar a última hora|studiare all'ultimo momento|幽默,提醒
不勞而獲|不努力就想得到|get something for nothing|obtener algo sin esfuerzo|ottenere qualcosa senza fatica|批評,提醒
好吃懶做|貪吃又懶惰|lazy and gluttonous|vago y comilón|pigro e goloso|批評
功虧一簣|只差最後一點而失敗|fail at the last hurdle|fracasar en el último paso|fallire all'ultimo passo|難過,提醒
前功盡棄|以前的努力全白費了|all previous efforts wasted|echar a perder todo el esfuerzo|mandare in fumo tutto il lavoro|難過
水到渠成|條件成熟，事情自然成功|things fall into place naturally|las cosas llegan a su debido tiempo|le cose arrivano a tempo debito|安慰,道理
熟能生巧|熟練了就有技巧|practice makes perfect|la práctica hace al maestro|la pratica rende perfetti|鼓勵,道理
心花怒放|心裡非常高興|be over the moon|estar en el séptimo cielo|essere al settimo cielo|開心
喜出望外|遇到意外的喜事特別高興|overjoyed by a pleasant surprise|llevarse una alegría inesperada|felice per una sorpresa inattesa|開心,驚訝
歡天喜地|非常歡喜|jump for joy|saltar de alegría|saltare di gioia|開心
興高采烈|興致很高、情緒熱烈|in high spirits|muy animado|di ottimo umore|開心
眉開眼笑|高興得笑容滿面|beam with joy|sonreír de oreja a oreja|sorridere da un orecchio all'altro|開心
笑逐顏開|高興得滿臉笑容|break into a smile|dibujarse una sonrisa|aprirsi in un sorriso|開心
樂不可支|快樂到了極點|tickled pink|loco de contento|pazzo di gioia|開心,幽默
欣喜若狂|高興得像發狂一樣|wild with joy|loco de alegría|fuori di sé dalla gioia|開心
無憂無慮|沒有任何憂慮|carefree|despreocupado|spensierato|開心
心滿意足|心裡非常滿足|perfectly content|plenamente satisfecho|pienamente soddisfatto|開心
悶悶不樂|心情煩悶、不快樂|down in the dumps|estar de bajón|essere giù di morale|難過
心灰意冷|灰心失望、意志消沉|lose heart|desanimarse|perdersi d'animo|難過
傷心欲絕|傷心到了極點|heartbroken|con el corazón roto|con il cuore spezzato|難過
痛哭流涕|哭得非常傷心|cry one's eyes out|llorar a mares|piangere a dirotto|難過
垂頭喪氣|失意、沮喪的樣子|crestfallen|cabizbajo|abbattuto|難過
愁眉苦臉|憂愁苦惱的樣子|wear a long face|poner cara larga|avere il muso lungo|難過
心如刀割|內心痛苦得像被刀割|feel a stab in the heart|tener el corazón partido|sentirsi trafiggere il cuore|難過
怒髮衝冠|憤怒到了極點|hit the roof|subirse por las paredes|andare su tutte le furie|生氣
火冒三丈|非常生氣|fly off the handle|echar chispas|vedere rosso|生氣
暴跳如雷|大發脾氣|blow one's top|ponerse hecho una fiera|arrabbiarsi come una bestia|生氣
怒不可遏|憤怒得無法抑制|beside oneself with rage|fuera de sí de rabia|fuori di sé dalla rabbia|生氣
氣急敗壞|又急又氣、慌了手腳|flustered and furious|furioso y alterado|furioso e agitato|生氣
心平氣和|心情平靜、態度溫和|calm and collected|con calma y serenidad|con calma e serenità|冷靜
平心靜氣|心情平和、不急躁|keep a cool head|mantener la cabeza fría|mantenere la testa fredda|冷靜
從容不迫|不慌不忙|unhurried and composed|sin prisa y sereno|senza fretta e sereno|冷靜
泰然自若|遇事鎮定、不慌張|cool as a cucumber|más fresco que una lechuga|calmo e tranquillo|冷靜
處變不驚|遇到變故也不驚慌|keep calm in a crisis|no perder la calma ante los cambios|non perdere la calma nelle difficoltà|冷靜
臨危不亂|遇到危險也不慌亂|keep one's head under pressure|no perder los nervios|non perdere i nervi|冷靜
驚慌失措|驚慌得不知道怎麼辦|panic-stricken|presa del pánico|in preda al panico|擔心
手忙腳亂|做事慌亂、沒有條理|in a flurry|ir de cabeza|nel caos più totale|擔心,幽默
坐立不安|心情緊張、坐也不是站也不是|on pins and needles|estar como en ascuas|stare sulle spine|擔心
忐忑不安|心神不定、很不安|have butterflies in one's stomach|tener mariposas en el estómago|avere le farfalle nello stomaco|擔心
提心吊膽|非常擔心害怕|on edge|con el alma en vilo|col fiato sospeso|擔心
膽戰心驚|非常害怕|scared stiff|muerto de miedo|morto di paura|擔心
毛骨悚然|恐怖得汗毛都豎起來|make one's hair stand on end|ponerse los pelos de punta|far rizzare i capelli|擔心
憂心忡忡|憂愁不安|worried sick|preocupado a muerte|preoccupato da morire|擔心
杞人憂天|不必要的擔憂|worry about the sky falling|preocuparse por nada|fasciarsi la testa prima di rompersela|安慰,幽默
如釋重負|好像放下重擔一樣輕鬆|a weight off one's shoulders|quitarse un peso de encima|togliersi un peso|開心,安慰
感激涕零|感激得流下眼淚|moved to tears with gratitude|llorar de agradecimiento|piangere di gratitudine|感謝
感恩戴德|非常感激別人的恩德|deeply grateful|eternamente agradecido|eternamente grato|感謝
銘感五內|內心深深地感激|grateful from the bottom of one's heart|agradecido de corazón|grato dal profondo del cuore|感謝
受寵若驚|受到意外的重視而又驚又喜|flattered beyond words|halagado de más|lusingato oltre ogni dire|謙虛,驚訝
大吃一驚|非常驚訝|be taken aback|quedarse de piedra|restare di stucco|驚訝
目瞪口呆|吃驚得說不出話來|dumbfounded|boquiabierto|a bocca aperta|驚訝
瞠目結舌|驚訝得說不出話|speechless|sin palabras|senza parole|驚訝
匪夷所思|事情離奇，不是常理能想像的|mind-boggling|inconcebible|inconcepibile|驚訝
不可思議|無法想像、難以理解|unbelievable|increíble|incredibile|驚訝
嘆為觀止|讚美看到的事物好到極點|breathtaking|impresionante|mozzafiato|稱讚,驚訝
孤苦伶仃|孤單、沒有依靠|all alone in the world|solo en el mundo|solo al mondo|難過
形單影隻|孤單一個人|all by oneself|más solo que la una|solo come un cane|難過
百無聊賴|精神空虛、沒事可做|bored to death|aburrido como una ostra|annoiarsi a morte|幽默
精疲力盡|精神和體力都用完了|worn out|agotado|esausto|安慰
筋疲力竭|累得一點力氣都沒有|dead tired|hecho polvo|stanco morto|安慰
身心俱疲|身體和心理都很疲累|burned out|quemado|esaurito|安慰
後悔莫及|後悔也來不及了|too late for regrets|ya no sirve de nada arrepentirse|è inutile piangere sul latte versato|難過,提醒
亡羊補牢|出了問題趕快補救，還不算晚|better late than never|más vale tarde que nunca|meglio tardi che mai|安慰,鼓勵,道理
塞翁失馬|壞事也可能變成好事|a blessing in disguise|no hay mal que por bien no venga|non tutto il male vien per nuocere|安慰,道理
因禍得福|因為禍事反而得到好處|every cloud has a silver lining|de un mal sale un bien|da un male nasce un bene|安慰
否極泰來|壞運到了盡頭，好運就來了|after the storm comes the calm|después de la tormenta llega la calma|dopo la tempesta torna il sereno|安慰,祝福
苦盡甘來|苦日子過去，好日子就來了|good times come after hard times|tras el esfuerzo llega la recompensa|dopo la fatica arriva la ricompensa|安慰,鼓勵
雨過天晴|困難過去，情況好轉|the sun comes out after the rain|tras la lluvia sale el sol|dopo la pioggia viene il sole|安慰
柳暗花明|困境中出現轉機|light at the end of the tunnel|luz al final del túnel|la luce in fondo al tunnel|安慰,鼓勵
東山再起|失敗後重新振作起來|make a comeback|resurgir de sus cenizas|risorgere dalle ceneri|鼓勵
捲土重來|失敗後重新再來|come back stronger|volver a la carga|tornare alla carica|鼓勵
一蹶不振|一次失敗就再也振作不起來|never recover from a setback|no levantar cabeza|non risollevarsi più|難過,提醒
自暴自棄|自己放棄自己|give up on oneself|abandonarse|lasciarsi andare|提醒
破釜沉舟|下定決心，不留退路|burn one's boats|quemar las naves|bruciarsi i ponti alle spalle|鼓勵
背水一戰|沒有退路，拚盡全力|fight with one's back to the wall|luchar con la espalda contra la pared|combattere con le spalle al muro|鼓勵
才華洋溢|很有才華|brimming with talent|rebosante de talento|pieno di talento|稱讚
出類拔萃|才能超出一般人|head and shoulders above the rest|destacar sobre los demás|una spanna sopra gli altri|稱讚
名列前茅|名次排在最前面|at the top of the class|entre los primeros|tra i primi|稱讚
首屈一指|第一流、最好的|second to none|sin igual|senza pari|稱讚
獨一無二|只有一個，沒有相同的|one of a kind|único en su especie|unico nel suo genere|稱讚
無與倫比|沒有能比得上的|unparalleled|incomparable|incomparabile|稱讚
爐火純青|技藝純熟到了完美的地步|reach perfection in one's craft|dominar a la perfección|padroneggiare alla perfezione|稱讚
聰明伶俐|聰明又機靈|bright and quick-witted|listo y avispado|sveglio e intelligente|稱讚
足智多謀|很有智慧和計謀|resourceful|lleno de recursos|pieno di risorse|稱讚
料事如神|預料事情非常準|have uncanny foresight|tener un olfato infalible|avere un fiuto infallibile|稱讚
一針見血|說話直接說中要害|hit the nail on the head|dar en el clavo|colpire nel segno|稱讚
畫龍點睛|在關鍵處加一筆，讓整體更生動|the finishing touch|el toque final|il tocco finale|稱讚
妙筆生花|文筆非常好|a gifted pen|una pluma brillante|una penna brillante|稱讚
美不勝收|美好的東西太多，看都看不完|a feast for the eyes|un regalo para la vista|una gioia per gli occhi|稱讚
栩栩如生|形象生動逼真，像活的一樣|lifelike|como si estuviera vivo|vivo e realistico|稱讚
十全十美|非常完美，沒有缺點|absolutely perfect|perfecto en todos los sentidos|perfetto sotto ogni aspetto|稱讚
盡善盡美|完美到了極點|flawless|impecable|impeccabile|稱讚
青出於藍|學生超越老師|the student surpasses the master|el alumno supera al maestro|l'allievo supera il maestro|稱讚
後生可畏|年輕人很有潛力，令人敬畏|the young are to be reckoned with|los jóvenes prometen mucho|i giovani promettono bene|稱讚
大器晚成|有才能的人比較晚成功|late bloomer|florecer tarde|sbocciare tardi|安慰,鼓勵
金玉良言|非常寶貴的話|words of wisdom|palabras sabias|parole sagge|感謝,稱讚
古道熱腸|待人真誠熱心|warm-hearted|de buen corazón|di buon cuore|稱讚
樂於助人|喜歡幫助別人|always ready to help|siempre dispuesto a ayudar|sempre pronto ad aiutare|稱讚,感謝
雪中送炭|在別人急需的時候給予幫助|a friend in need is a friend indeed|ayudar en el momento justo|aiutare nel momento del bisogno|感謝
錦上添花|好上加好|icing on the cake|la guinda del pastel|la ciliegina sulla torta|開心,稱讚
落井下石|趁別人危難時打擊他|kick someone when they're down|hacer leña del árbol caído|infierire su chi è a terra|批評
雪上加霜|災禍接連發生，更加困難|add insult to injury|llover sobre mojado|piove sul bagnato|難過
禍不單行|不幸的事接連發生|when it rains it pours|las desgracias nunca vienen solas|le disgrazie non vengono mai sole|難過,安慰
雙喜臨門|兩件喜事同時來到|double happiness|doble alegría|doppia gioia|開心,祝福
一石二鳥|做一件事得到兩種好處|kill two birds with one stone|matar dos pájaros de un tiro|prendere due piccioni con una fava|稱讚,幽默
一舉兩得|做一件事得到兩個好處|two benefits in one go|doble beneficio|doppio vantaggio|稱讚
事半功倍|花一半的力氣得到加倍的效果|work smarter, not harder|lograr más con menos|ottenere di più con meno|稱讚,道理
事倍功半|花加倍的力氣只得到一半成效|much effort, little result|mucho esfuerzo y poco resultado|tanta fatica per poco risultato|提醒
徒勞無功|白費力氣、沒有成效|all for nothing|en vano|tutto inutile|難過
竹籃打水一場空|白費力氣，什麼都沒得到|carry water in a sieve|echar agua en un cesto|portare acqua con un cesto|難過,幽默
對牛彈琴|對不懂的人講道理，白費口舌|cast pearls before swine|predicar en el desierto|parlare al muro|幽默,批評
井底之蛙|見識狹小的人|a frog in a well|una rana en el pozo|una rana nel pozzo|批評,提醒
坐井觀天|眼界狹小、見識有限|see the sky from the bottom of a well|ver el cielo desde un pozo|guardare il cielo dal fondo di un pozzo|批評
見多識廣|經歷多、知識豐富|well-traveled and knowledgeable|con mucho mundo|che ha visto il mondo|稱讚
博學多聞|學問廣博、見聞很多|well-read|erudito|erudito|稱讚
學富五車|讀的書多、學問大|a walking encyclopedia|una enciclopedia andante|un'enciclopedia ambulante|稱讚,幽默
才疏學淺|才能低、學問淺（謙虛的說法）|my knowledge is limited|mis conocimientos son limitados|le mie conoscenze sono limitate|謙虛
不學無術|沒有學問也沒有本事|ignorant and incompetent|ignorante e incapaz|ignorante e incapace|批評
一知半解|知道得不完全、理解不透徹|half-baked understanding|saber a medias|sapere a metà|提醒
融會貫通|把各方面的知識融合，理解透徹|have a thorough grasp|dominar a fondo|padroneggiare a fondo|稱讚
舉一反三|從一件事推知其他的事|learn by analogy|deducir mucho de poco|imparare per analogia|稱讚
溫故知新|複習舊的而得到新的體會|review the old to learn the new|repasar lo viejo para aprender lo nuevo|ripassare il vecchio per imparare il nuovo|道理
學無止境|學問沒有盡頭|learning never ends|nunca se deja de aprender|non si finisce mai di imparare|道理,鼓勵
活到老學到老|一輩子都要學習|you're never too old to learn|nunca es tarde para aprender|non è mai troppo tardi per imparare|道理,鼓勵
欲速則不達|太急反而做不成|haste makes waste|vísteme despacio que tengo prisa|chi va piano va sano e va lontano|冷靜,道理
拔苗助長|違反規律、急於求成，反而壞事|forcing things only spoils them|forzar las cosas lo estropea todo|forzare le cose rovina tutto|提醒,道理
循序漸進|按照順序一步一步前進|step by step|paso a paso|passo dopo passo|冷靜,道理
按部就班|照著步驟一步一步做|by the book|siguiendo el orden establecido|procedere con ordine|道理
三思而後行|仔細考慮之後再行動|look before you leap|piensa antes de actuar|pensaci due volte|提醒,冷靜
謹言慎行|說話做事都很小心|mind one's words and deeds|ser prudente en palabras y actos|essere prudente in parole e azioni|提醒
未雨綢繆|事先做好準備|prepare for a rainy day|más vale prevenir que curar|prevenire è meglio che curare|提醒,道理
防患未然|在禍患發生前就預防|nip it in the bud|cortar de raíz|stroncare sul nascere|提醒
居安思危|安定的時候想到可能的危險|be prepared for danger in times of peace|pensar en el peligro en tiempos de calma|pensare al pericolo nei momenti tranquilli|提醒
知足常樂|知道滿足就常常快樂|happy is he who is content|quien se conforma es feliz|chi si accontenta gode|道理,安慰
得寸進尺|貪心，得到了還要更多|give an inch and they'll take a mile|dar la mano y tomar el codo|dai un dito e si prendono il braccio|批評
貪得無厭|貪心，永遠不滿足|insatiably greedy|codicioso sin límite|avido insaziabile|批評
自作自受|自己做錯事，自己承擔後果|you reap what you sow|quien siembra vientos recoge tempestades|chi semina vento raccoglie tempesta|批評,道理
種瓜得瓜|做什麼事就得到什麼結果|as you sow, so shall you reap|cosecharás lo que siembres|si raccoglie ciò che si semina|道理
入鄉隨俗|到一個地方就順從當地的習俗|when in Rome, do as the Romans do|allá donde fueres, haz lo que vieres|paese che vai, usanza che trovi|道理
物以類聚|同類的聚在一起|birds of a feather flock together|Dios los cría y ellos se juntan|chi si somiglia si piglia|道理,幽默
近朱者赤|接近好人就會變好|you are the company you keep|dime con quién andas y te diré quién eres|dimmi con chi vai e ti dirò chi sei|道理
眼見為憑|親眼看到的才可信|seeing is believing|ver para creer|vedere per credere|道理
百聞不如一見|聽很多次不如親眼看一次|seeing once beats hearing a hundred times|más vale ver una vez que oír cien|meglio vedere una volta che sentire cento volte|道理
言多必失|話說多了一定有失誤|the less said the better|en boca cerrada no entran moscas|il silenzio è d'oro|提醒
禍從口出|災禍從說話不小心而來|loose lips sink ships|por la boca muere el pez|una parola di troppo può costare cara|提醒
知己知彼|了解自己也了解對方|know yourself and know your enemy|conoce a tu enemigo y conócete a ti mismo|conosci il nemico e conosci te stesso|道理
失敗為成功之母|失敗是成功的開始|failure is the mother of success|el fracaso es la madre del éxito|il fallimento è la madre del successo|安慰,鼓勵
光陰似箭|時間過得很快|time flies|el tiempo vuela|il tempo vola|道理
一寸光陰一寸金|時間非常寶貴|time is money|el tiempo es oro|il tempo è denaro|道理,提醒
日新月異|進步、變化非常快|change by leaps and bounds|avanzar a pasos agigantados|progredire a passi da gigante|稱讚
一日千里|進展非常快|make rapid progress|progresar rapidísimo|fare progressi rapidissimi|稱讚
一成不變|固定不變|set in stone|inamovible|immutabile|批評
墨守成規|死守舊規矩，不肯改變|stuck in one's ways|aferrarse a la tradición|restare fermo alle vecchie abitudini|批評
刻舟求劍|拘泥固執、不知變通|cling to outdated methods|aferrarse a métodos obsoletos|aggrapparsi a metodi superati|批評
推陳出新|去掉舊的，創造新的|out with the old, in with the new|renovarse o morir|rinnovarsi o morire|稱讚
與時俱進|跟著時代一起進步|keep up with the times|adaptarse a los tiempos|stare al passo con i tempi|稱讚,道理
守株待兔|不努力，只想等待好運|wait for things to fall into one's lap|esperar que las cosas caigan del cielo|aspettare la manna dal cielo|批評,幽默
緣木求魚|方法錯了，不可能達到目的|barking up the wrong tree|pedirle peras al olmo|cercare nel posto sbagliato|提醒
畫蛇添足|多此一舉，反而把事情弄壞|gild the lily|rizar el rizo|strafare|幽默,提醒
多此一舉|做不必要的事|an unnecessary move|un paso innecesario|una mossa inutile|提醒
自相矛盾|自己說的話前後抵觸|contradict oneself|contradecirse|contraddirsi|批評
掩耳盜鈴|自己騙自己|bury one's head in the sand|esconder la cabeza como el avestruz|fare come lo struzzo|批評,幽默
自欺欺人|欺騙自己也欺騙別人|fool oneself and others|engañarse a sí mismo y a los demás|ingannare se stessi e gli altri|批評
指鹿為馬|故意顛倒是非|call black white|llamar blanco a lo negro|chiamare bianco il nero|批評
顛倒是非|把對的說成錯的、錯的說成對的|twist the truth|tergiversar la verdad|stravolgere la verità|批評
實事求是|根據事實，求得真相|stick to the facts|atenerse a los hechos|attenersi ai fatti|稱讚,道理
腳踏實地|做事踏實認真|down-to-earth|con los pies en la tierra|con i piedi per terra|稱讚,鼓勵
好高騖遠|不切實際，追求太高太遠的目標|bite off more than one can chew|querer abarcar demasiado|fare il passo più lungo della gamba|提醒,批評
眼高手低|要求很高，能力卻很低|big ideas, little ability|mucho ruido y pocas nueces|tanto fumo e poco arrosto|批評
紙上談兵|只會空談，不能解決實際問題|all talk and no action|mucho hablar y poco hacer|tante parole e pochi fatti|批評
言而有信|說話算話|true to one's word|hombre de palabra|di parola|稱讚
一言九鼎|說話很有份量|one's word is one's bond|su palabra es ley|la sua parola vale oro|稱讚
言而無信|說話不算話|go back on one's word|faltar a su palabra|venir meno alla parola|批評
出爾反爾|反覆無常、說話不算數|flip-flop|decir una cosa y hacer otra|dire una cosa e farne un'altra|批評
表裡如一|外在跟內心一致|what you see is what you get|ser auténtico|essere autentico|稱讚
口是心非|嘴上說的跟心裡想的不一樣|two-faced|tener dos caras|avere due facce|批評
陽奉陰違|表面遵從，暗中違背|pay lip service|obedecer de boquilla|obbedire solo a parole|批評
光明磊落|心地光明坦白|open and aboveboard|honrado y transparente|onesto e trasparente|稱讚
正大光明|正當、不偏私|fair and square|limpio y justo|leale e giusto|稱讚
鬼鬼祟祟|行為偷偷摸摸、不光明|sneaky|a hurtadillas|di nascosto|批評
偷偷摸摸|瞞著別人暗中做事|on the sly|a escondidas|furtivamente|批評
同舟共濟|同心協力，一起度過困難|all in the same boat|estar en el mismo barco|essere sulla stessa barca|鼓勵
同心協力|大家一條心，一起努力|join forces|unir fuerzas|unire le forze|鼓勵
齊心協力|大家一起出力|pull together|remar en la misma dirección|remare nella stessa direzione|鼓勵
眾志成城|大家同心就能成功|united we stand|la unión hace la fuerza|l'unione fa la forza|鼓勵
各自為政|各做各的、不合作|every man for himself|cada uno a lo suyo|ognuno per conto suo|批評
一盤散沙|散漫、沒有團結|a disorganized bunch|un grupo desunido|un gruppo allo sbando|批評
患難與共|一起承擔困難|through thick and thin|en las buenas y en las malas|nella buona e nella cattiva sorte|安慰
肝膽相照|真心相待|be true to each other|ser leales de corazón|essere leali col cuore|稱讚
情同手足|感情好得像兄弟一樣|like brothers|como hermanos|come fratelli|開心
青梅竹馬|從小一起長大的男女|childhood sweethearts|novios de la infancia|fidanzatini d'infanzia|開心
一見鍾情|第一次見面就喜歡上|love at first sight|amor a primera vista|amore a prima vista|開心
天作之合|上天安排的美好姻緣|a match made in heaven|una pareja hecha en el cielo|una coppia fatta in paradiso|祝福
白頭偕老|夫妻相愛到老|grow old together|envejecer juntos|invecchiare insieme|祝福
百年好合|祝新人永遠和好|a lifetime of happiness together|felicidad para toda la vida|felicità per tutta la vita|祝福
永結同心|永遠同心相愛|united in heart forever|unidos para siempre|uniti per sempre|祝福
形影不離|關係非常親密，常在一起|inseparable|inseparables|inseparabili|開心
相敬如賓|夫妻互相尊敬|treat each other with respect|tratarse con respeto|trattarsi con rispetto|稱讚
同床異夢|在一起，想法卻不同|together but dreaming different dreams|juntos pero con sueños distintos|insieme ma con sogni diversi|批評
貌合神離|表面親密，心裡疏遠|close on the surface, apart at heart|unidos solo en apariencia|uniti solo in apparenza|批評
勢不兩立|敵對的雙方不能並存|at daggers drawn|a matar|ai ferri corti|生氣
水火不容|彼此對立，不能相容|like cats and dogs|como el perro y el gato|come cane e gatto|生氣
一見如故|第一次見面就像老朋友|hit it off right away|congeniar desde el principio|andare subito d'accordo|開心
相見恨晚|只恨認識得太晚|wish we'd met sooner|ojalá nos hubiéramos conocido antes|peccato non esserci conosciuti prima|開心
素不相識|從來不認識|complete strangers|completos desconocidos|perfetti sconosciuti|道理
知恩圖報|知道感恩並想回報|repay a kindness|devolver el favor|ricambiare il favore|感謝,稱讚
恩將仇報|用仇恨回報恩惠|bite the hand that feeds you|morder la mano que te da de comer|mordere la mano che ti nutre|批評
忘恩負義|忘記別人的恩惠、背棄道義|ungrateful|desagradecido|ingrato|批評
飲水思源|不忘記根本、不忘記恩情|remember where you came from|es de bien nacido ser agradecido|non dimenticare le proprie radici|感謝,道理
過河拆橋|達到目的後就拋棄幫過自己的人|kick away the ladder|dar la espalda a quien te ayudó|voltare le spalle a chi ti ha aiutato|批評
投桃報李|互相贈答、有來有往|one good turn deserves another|favor con favor se paga|una mano lava l'altra|感謝
禮尚往來|禮節講究有來有往|courtesy demands reciprocity|cortesía con cortesía se paga|cortesia chiama cortesia|感謝,道理
哭笑不得|又好氣又好笑|not know whether to laugh or cry|no saber si reír o llorar|non sapere se ridere o piangere|幽默
啼笑皆非|讓人哭也不是、笑也不是|both funny and annoying|entre risas y lágrimas|tra il riso e il pianto|幽默
捧腹大笑|笑得抱著肚子|laugh one's head off|morirse de risa|morire dal ridere|幽默,開心
忍俊不禁|忍不住笑出來|can't help laughing|no poder aguantar la risa|non riuscire a trattenere le risate|幽默
胡說八道|沒有根據地亂說|talk nonsense|decir tonterías|dire sciocchezze|批評,生氣
信口開河|隨便亂說|shoot one's mouth off|hablar sin ton ni son|parlare a vanvera|批評
一派胡言|全部都是胡說|a load of rubbish|puras patrañas|tutte frottole|批評
答非所問|回答的不是問的問題|beside the point|contestar otra cosa|dare una risposta che non c'entra|批評
文不對題|內容跟題目不相干|off-topic|fuera de tema|fuori tema|批評
亂七八糟|非常雜亂|a complete mess|patas arriba|un gran casino|批評
雜亂無章|雜亂、沒有條理|chaotic and disorganized|caótico|caotico|批評
一塌糊塗|糟糕到了極點|a total disaster|un completo desastre|un disastro totale|批評
井井有條|整齊有條理|in apple-pie order|ordenado y limpio|in perfetto ordine|稱讚
有條不紊|有條理、一點也不亂|orderly and methodical|metódico|metodico|稱讚
萬事如意|祝一切都順心如意|may all go well|que todo te vaya bien|che tutto vada bene|祝福
心想事成|想要的都能實現|may all your wishes come true|que se cumplan todos tus deseos|che si avverino tutti i tuoi desideri|祝福
一帆風順|非常順利|smooth sailing|viento en popa|col vento in poppa|祝福
步步高昇|職位不斷升高|may you keep climbing higher|que sigas ascendiendo|che tu possa fare carriera|祝福
福如東海|福氣像東海一樣大|may your blessings be as vast as the sea|que tu dicha sea inmensa como el mar|che la tua fortuna sia vasta come il mare|祝福
壽比南山|祝人長壽|may you live a long life|que vivas muchos años|cento di questi giorni|祝福
前程似錦|前途非常美好|a bright future ahead|un futuro brillante|un futuro radioso|祝福
鵬程萬里|前途遠大|may you soar to great heights|que llegues muy lejos|che tu possa volare alto|祝福
金榜題名|考試考取|pass the exam with flying colors|aprobar con nota|superare l'esame a pieni voti|祝福
馬到成功|一開始就成功|success right from the start|éxito inmediato|successo immediato|祝福,鼓勵
旗開得勝|一開始就獲得勝利|win from the outset|ganar desde el principio|vincere fin dall'inizio|祝福,鼓勵
大功告成|事情圓滿完成|mission accomplished|misión cumplida|missione compiuta|開心,稱讚
功成名就|事業成功、名聲顯揚|achieve fame and success|alcanzar fama y éxito|raggiungere fama e successo|稱讚
一敗塗地|徹底失敗|a crushing defeat|una derrota aplastante|una sconfitta schiacciante|難過
名落孫山|考試沒有考上|fail an exam|suspender el examen|essere bocciato|難過,安慰
人山人海|人非常多|a sea of people|un mar de gente|un mare di gente|驚訝
門可羅雀|非常冷清，沒有人來|deserted|desierto|deserto|幽默
熙熙攘攘|人來人往，很熱鬧|bustling|bullicioso|brulicante|開心
鴉雀無聲|非常安靜|you could hear a pin drop|no se oye ni una mosca|non volava una mosca|驚訝
萬籟俱寂|四周一點聲音都沒有|dead silent|silencio absoluto|silenzio assoluto|冷靜
春暖花開|春天溫暖、百花盛開|spring in full bloom|primavera en flor|primavera in fiore|開心
風和日麗|天氣晴朗溫和|fine and sunny|un día espléndido|una giornata splendida|開心
狂風暴雨|又大又急的風雨|a raging storm|una tormenta furiosa|una tempesta furiosa|擔心
傾盆大雨|雨下得非常大|raining cats and dogs|llover a cántaros|piovere a catinelle|驚訝,幽默
天寒地凍|天氣非常寒冷|bitter freezing weather|un frío que pela|un freddo cane|擔心
汗流浹背|流了很多汗|drenched in sweat|sudar la gota gorda|sudare sette camicie|幽默
力不從心|心裡想做，能力卻不夠|the spirit is willing but the flesh is weak|querer y no poder|lo spirito è forte ma la carne è debole|難過,安慰
得心應手|做起來非常順手|be in one's element|como pez en el agua|come un pesce nell'acqua|稱讚
遊刃有餘|做事輕鬆熟練、綽綽有餘|do it with ease|con soltura|con disinvoltura|稱讚
輕而易舉|很容易就做到|a piece of cake|pan comido|un gioco da ragazzi|鼓勵,幽默
易如反掌|像翻手掌一樣容易|as easy as pie|facilísimo|facilissimo|鼓勵
難如登天|像登天一樣困難|next to impossible|casi imposible|quasi impossibile|擔心
千辛萬苦|各種艱難困苦|after countless hardships|con mil penurias|con mille fatiche|努力
歷盡艱辛|經歷了許多艱難|go through great hardships|pasar muchas penurias|passare tante difficoltà|努力
一波三折|事情進行中遇到很多波折|full of twists and turns|lleno de altibajos|pieno di alti e bassi|擔心
無能為力|沒有能力去做|powerless to help|no poder hacer nada|non poterci fare nulla|難過
束手無策|一點辦法都沒有|at one's wit's end|no saber qué hacer|non sapere che pesci pigliare|難過,擔心
一籌莫展|一點辦法也想不出來|stuck with no way out|sin salida|senza via d'uscita|難過,擔心
迎刃而解|問題順利解決|easily solved|resolverse fácilmente|risolversi facilmente|鼓勵
寬宏大量|度量寬大，能容人|big-hearted|magnánimo|magnanimo|稱讚
斤斤計較|過分計較小事|count every penny|mirar el céntimo|guardare il centesimo|批評
小肚雞腸|氣量狹小|petty|mezquino|meschino|批評
大公無私|公正，沒有私心|selfless and fair|justo y desinteresado|giusto e disinteressato|稱讚
自私自利|只顧自己的利益|selfish|egoísta|egoista|批評
捨己為人|犧牲自己幫助別人|sacrifice oneself for others|sacrificarse por los demás|sacrificarsi per gli altri|稱讚
虛懷若谷|非常謙虛|humble and open-minded|humilde|umile|稱讚,謙虛
驕傲自滿|自以為了不起|full of oneself|creído|pieno di sé|批評
目中無人|看不起別人|look down on everyone|mirar a todos por encima del hombro|guardare tutti dall'alto in basso|批評
自命不凡|自以為很了不起|think one is special|creerse especial|credersi speciale|批評
妄自菲薄|過分看輕自己|sell oneself short|subestimarse|sottovalutarsi|安慰,鼓勵
膽小如鼠|膽子非常小|chicken-hearted|cobarde como una gallina|fifone|幽默
畏首畏尾|做事膽小、顧慮太多|overly timid|demasiado temeroso|troppo timoroso|提醒
勇往直前|勇敢地一直向前|forge ahead bravely|seguir adelante con valentía|andare avanti con coraggio|鼓勵
猶豫不決|拿不定主意|sit on the fence|estar entre dos aguas|essere indeciso|提醒
舉棋不定|拿不定主意，猶豫不決|dither|titubear|tentennare|提醒
優柔寡斷|做事猶豫、不果斷|indecisive|indeciso|irresoluto|提醒
當機立斷|抓住時機，果斷決定|make a snap decision|decidir sin vacilar|decidere su due piedi|鼓勵
三心二意|意志不堅定、不專心|of two minds|no saber lo que se quiere|non sapere cosa si vuole|提醒
一心一意|心思專一|wholeheartedly|de todo corazón|con tutto il cuore|稱讚,鼓勵
全神貫注|精神完全集中|fully focused|totalmente concentrado|totalmente concentrato|稱讚
聚精會神|集中精神|concentrate intently|con toda la atención|con la massima attenzione|稱讚
心不在焉|心思不在這裡|absent-minded|en las nubes|con la testa tra le nuvole|幽默,提醒
漫不經心|隨隨便便、不放在心上|careless|descuidado|distratto|提醒
粗心大意|做事不細心|sloppy|despistado|sbadato|提醒
小心翼翼|非常謹慎小心|walk on eggshells|andar con pies de plomo|camminare sulle uova|提醒
一絲不苟|認真細心，一點都不馬虎|meticulous|meticuloso|meticoloso|稱讚
馬馬虎虎|隨便、不認真；普普通通|so-so|así así|così così|批評
口若懸河|說話滔滔不絕、很會說|have the gift of the gab|tener un pico de oro|avere la parlantina|稱讚
能言善道|很會說話|silver-tongued|elocuente|eloquente|稱讚
沉默寡言|不愛說話|a person of few words|de pocas palabras|di poche parole|道理
守口如瓶|嚴守秘密|keep one's lips sealed|ser una tumba|essere una tomba|稱讚
一五一十|從頭到尾詳細地說|tell everything in detail|con pelos y señales|per filo e per segno|道理
開門見山|說話直接切入主題|get straight to the point|ir al grano|andare dritto al punto|道理
直截了當|說話做事直接爽快|straightforward|directo|diretto|道理
拐彎抹角|說話不直接|beat around the bush|andarse por las ramas|girare intorno al discorso|批評
言簡意賅|話很簡短，意思卻很完整|short and sweet|breve y conciso|breve e conciso|稱讚
長篇大論|很長的言論|long-winded|un rollo largo|una lunga tirata|批評,幽默
一擲千金|花錢毫不吝惜|spend money like water|gastar a manos llenas|spendere e spandere|批評
揮金如土|花錢像撒土一樣|throw money around|tirar el dinero|buttare i soldi|批評
省吃儉用|生活節儉|pinch pennies|ahorrar hasta el último céntimo|risparmiare fino all'ultimo centesimo|稱讚
家財萬貫|非常富有|rolling in money|nadar en la abundancia|nuotare nell'oro|驚訝
一貧如洗|窮得什麼都沒有|as poor as a church mouse|más pobre que las ratas|povero in canna|難過
安居樂業|安定地生活、愉快地工作|live and work in peace|vivir en paz y prosperidad|vivere in pace e prosperità|祝福
顛沛流離|生活艱難、到處流浪|drift from place to place in hardship|vagar en la miseria|vagare nella miseria|難過
迫在眉睫|事情非常緊急|imminent|inminente|imminente|擔心,提醒
刻不容緩|緊急得一刻也不能拖延|no time to lose|no hay tiempo que perder|non c'è tempo da perdere|提醒
當務之急|目前最急著要辦的事|top priority|la máxima prioridad|la priorità assoluta|提醒
慢條斯理|動作緩慢、不慌不忙|slow and unhurried|con toda la parsimonia|con tutta calma|冷靜
爭分奪秒|搶時間|race against the clock|contra reloj|contro il tempo|努力
夜以繼日|日夜不停地工作|day and night|día y noche|giorno e notte|努力
廢寢忘食|專心到忘了睡覺吃飯|so absorbed one forgets to eat and sleep|olvidarse de comer y dormir|dimenticarsi di mangiare e dormire|努力,稱讚
遊手好閒|遊蕩懶散、不做正事|idle about|holgazanear|bighellonare|批評
一勞永逸|辛苦一次，以後就不用再做|once and for all|de una vez por todas|una volta per tutte|道理
千載難逢|很難遇到的好機會|once-in-a-lifetime|una oportunidad única|un'occasione unica|開心
機不可失|機會不可以錯過|seize the day|aprovechar la ocasión|cogliere l'attimo|鼓勵
坐失良機|白白錯過好機會|miss the boat|perder el tren|perdere il treno|難過,提醒
司空見慣|常常見到，不覺得奇怪|nothing out of the ordinary|lo más normal del mundo|roba di tutti i giorni|道理
層出不窮|接連出現，沒有窮盡|keep cropping up|surgir sin parar|spuntare di continuo|驚訝
寥寥無幾|非常少|few and far between|contados con los dedos|pochissimi|道理
不計其數|多得數不清|countless|incontables|innumerevoli|驚訝
微不足道|很小，不值得一提|a drop in the ocean|una gota en el océano|una goccia nel mare|謙虛
舉足輕重|地位重要、影響很大|carry great weight|tener mucho peso|avere molto peso|稱讚
隨遇而安|在任何環境都能安然自得|take life as it comes|tomarse la vida como viene|prendere la vita come viene|安慰,冷靜
順其自然|順著事情自然發展|let nature take its course|dejar que las cosas sigan su curso|lasciare che le cose facciano il loro corso|安慰,冷靜
船到橋頭自然直|事情到最後自然會有辦法|cross that bridge when we come to it|ya se verá|si vedrà|安慰
天無絕人之路|總會有出路|there's always a way out|siempre hay una salida|c'è sempre una soluzione|安慰,鼓勵
吉人天相|好人自有上天保佑|fortune favors the good|a los buenos les va bien|la fortuna aiuta i buoni|安慰,祝福
逢凶化吉|遇到危險轉為吉祥|turn bad luck into good|convertir la mala suerte en buena|trasformare la sfortuna in fortuna|祝福,安慰
化險為夷|把危險變成平安|turn danger into safety|salir del peligro|uscire dal pericolo|安慰
平安無事|平平安安、沒有意外|safe and sound|sano y salvo|sano e salvo|安慰,祝福
安然無恙|平安、沒有受到損害|unharmed|ileso|illeso|安慰
自不量力|不衡量自己的能力|overestimate oneself|sobreestimarse|sopravvalutarsi|批評
以卵擊石|拿蛋去碰石頭，自取滅亡|fight a losing battle|luchar contra un gigante|lottare contro un gigante|提醒
量力而為|按照自己的能力去做|cut your coat according to your cloth|no dar el paso más largo que la pierna|fare il passo secondo la gamba|道理
杯弓蛇影|疑神疑鬼，自己嚇自己|jump at shadows|asustarse de su propia sombra|avere paura della propria ombra|安慰,幽默
疑神疑鬼|無端地起疑心|paranoid|paranoico|sospettoso di tutto|提醒
草木皆兵|驚慌時把一切都當成敵人|see enemies everywhere|ver enemigos por todas partes|vedere nemici ovunque|擔心
大驚小怪|對小事過分驚訝|make a fuss over nothing|hacer una montaña de un grano de arena|fare una montagna di un granello di sabbia|冷靜,幽默
小題大作|把小事當大事來做|make a mountain out of a molehill|ahogarse en un vaso de agua|affogare in un bicchier d'acqua|冷靜,幽默
雞毛蒜皮|微小、不重要的事|small potatoes|minucias|quisquilie|冷靜
無中生有|憑空捏造|fabricate out of thin air|inventarse las cosas|inventarsi le cose|批評
捕風捉影|沒有根據地亂猜|chase shadows|hablar sin fundamento|parlare senza fondamento|批評
道聽塗說|聽來的、沒有根據的話|hearsay|rumores|dicerie|批評
千真萬確|非常確實|absolutely true|absolutamente cierto|assolutamente vero|道理
有憑有據|有根據、有證據|backed by evidence|con pruebas|con prove|道理
對症下藥|針對問題採取方法|find the right remedy|dar con el remedio adecuado|trovare il rimedio giusto|道理
半斤八兩|彼此差不多|six of one, half a dozen of the other|tanto monta, monta tanto|se non è zuppa è pan bagnato|幽默
不相上下|分不出高低|neck and neck|muy parejos|testa a testa|道理
大同小異|大致相同，只有小差異|pretty much the same|más o menos lo mismo|più o meno uguale|道理
一模一樣|完全一樣|like two peas in a pod|como dos gotas de agua|come due gocce d'acqua|驚訝
天壤之別|差別非常大|as different as night and day|como la noche y el día|come il giorno e la notte|驚訝
截然不同|完全不一樣|completely different|completamente distinto|completamente diverso|道理
喜新厭舊|喜歡新的、厭棄舊的|fickle|veleidoso|volubile|批評
念念不忘|時時刻刻記著不忘|can't stop thinking about it|no poder olvidarlo|non riuscire a dimenticarlo|難過
刻骨銘心|印象深刻，永遠不忘|etched in one's memory|grabado a fuego|impresso nella memoria|難過
過眼雲煙|很快就消失的事物|here today, gone tomorrow|flor de un día|fuoco di paglia|安慰,道理
一臂之力|一部分的力量（幫忙）|lend a hand|echar una mano|dare una mano|感謝
舉手之勞|很輕易就能做到的事|it was nothing|no fue nada|non è stato niente|謙虛
拔刀相助|見到不平的事挺身幫忙|come to the rescue|acudir al rescate|correre in aiuto|稱讚
見義勇為|看到正義的事勇敢去做|do the right thing bravely|actuar con valor por lo justo|agire con coraggio per ciò che è giusto|稱讚
袖手旁觀|在一旁看著，不幫忙|stand idly by|quedarse de brazos cruzados|stare a guardare|批評
置之不理|放在一邊不理會|turn a blind eye|hacer la vista gorda|chiudere un occhio|批評
"""

    /// 近義：每行一組
    static let near = """
鍥而不捨 持之以恆 堅持不懈 滴水穿石 鐵杵磨成針 自強不息
三天打魚兩天曬網 一曝十寒 半途而廢
半途而廢 虎頭蛇尾
全力以赴 奮發圖強 背水一戰 破釜沉舟
臨陣磨槍 臨時抱佛腳
功虧一簣 前功盡棄
心花怒放 喜出望外 歡天喜地 興高采烈 眉開眼笑 笑逐顏開 樂不可支 欣喜若狂
悶悶不樂 心灰意冷 垂頭喪氣 愁眉苦臉
傷心欲絕 痛哭流涕 心如刀割
怒髮衝冠 火冒三丈 暴跳如雷 怒不可遏
心平氣和 平心靜氣
從容不迫 泰然自若 處變不驚 臨危不亂
驚慌失措 手忙腳亂
坐立不安 忐忑不安 提心吊膽 憂心忡忡
膽戰心驚 毛骨悚然
感激涕零 感恩戴德 銘感五內
大吃一驚 目瞪口呆 瞠目結舌
匪夷所思 不可思議
孤苦伶仃 形單影隻
精疲力盡 筋疲力竭 身心俱疲
塞翁失馬 因禍得福
否極泰來 苦盡甘來 雨過天晴 柳暗花明
東山再起 捲土重來
一蹶不振 自暴自棄
出類拔萃 首屈一指 名列前茅
獨一無二 無與倫比
聰明伶俐 足智多謀
料事如神 一針見血
十全十美 盡善盡美
雪上加霜 禍不單行
一石二鳥 一舉兩得 事半功倍
徒勞無功 竹籃打水一場空 事倍功半
井底之蛙 坐井觀天
見多識廣 博學多聞 學富五車
融會貫通 舉一反三
學無止境 活到老學到老
欲速則不達 拔苗助長
循序漸進 按部就班
三思而後行 謹言慎行
未雨綢繆 防患未然 居安思危
得寸進尺 貪得無厭
自作自受 種瓜得瓜
眼見為憑 百聞不如一見
言多必失 禍從口出
日新月異 一日千里
一成不變 墨守成規 刻舟求劍
推陳出新 與時俱進
畫蛇添足 多此一舉
掩耳盜鈴 自欺欺人
指鹿為馬 顛倒是非
好高騖遠 眼高手低
眼高手低 紙上談兵
言而有信 一言九鼎
言而無信 出爾反爾
口是心非 陽奉陰違
光明磊落 正大光明
鬼鬼祟祟 偷偷摸摸
同舟共濟 同心協力 齊心協力 眾志成城
各自為政 一盤散沙
同床異夢 貌合神離
勢不兩立 水火不容
一見如故 相見恨晚
恩將仇報 忘恩負義 過河拆橋
投桃報李 禮尚往來 知恩圖報
哭笑不得 啼笑皆非
捧腹大笑 忍俊不禁
胡說八道 信口開河 一派胡言
答非所問 文不對題
亂七八糟 雜亂無章 一塌糊塗
井井有條 有條不紊
萬事如意 心想事成
前程似錦 鵬程萬里
馬到成功 旗開得勝
天作之合 白頭偕老 百年好合 永結同心
一敗塗地 名落孫山
鴉雀無聲 萬籟俱寂
春暖花開 風和日麗
得心應手 遊刃有餘
輕而易舉 易如反掌
千辛萬苦 歷盡艱辛
無能為力 束手無策 一籌莫展
斤斤計較 小肚雞腸
驕傲自滿 目中無人 自命不凡
猶豫不決 舉棋不定 優柔寡斷
一心一意 全神貫注 聚精會神
心不在焉 漫不經心 粗心大意
口若懸河 能言善道
開門見山 直截了當
一擲千金 揮金如土
迫在眉睫 刻不容緩 當務之急
夜以繼日 廢寢忘食 爭分奪秒
隨遇而安 順其自然
船到橋頭自然直 天無絕人之路
逢凶化吉 化險為夷 吉人天相
平安無事 安然無恙
自不量力 以卵擊石
杯弓蛇影 疑神疑鬼 草木皆兵
大驚小怪 小題大作
無中生有 捕風捉影 道聽塗說
千真萬確 有憑有據
半斤八兩 不相上下 大同小異
天壤之別 截然不同
念念不忘 刻骨銘心
一臂之力 拔刀相助
袖手旁觀 置之不理
"""

    /// 反義：左邊每個跟右邊每個相反
    static let anti = """
鍥而不捨 持之以恆 堅持不懈 自強不息 有始有終 | 半途而廢 三天打魚兩天曬網 一曝十寒 虎頭蛇尾
全力以赴 | 漫不經心
勤能補拙 腳踏實地 | 好吃懶做 不勞而獲 好高騖遠
心花怒放 歡天喜地 興高采烈 眉開眼笑 喜出望外 欣喜若狂 | 悶悶不樂 心灰意冷 垂頭喪氣 愁眉苦臉 傷心欲絕
無憂無慮 | 憂心忡忡 坐立不安 忐忑不安 提心吊膽
心平氣和 平心靜氣 | 怒髮衝冠 火冒三丈 暴跳如雷 怒不可遏 氣急敗壞
從容不迫 泰然自若 處變不驚 臨危不亂 | 驚慌失措 手忙腳亂
東山再起 捲土重來 奮發圖強 | 一蹶不振 自暴自棄
否極泰來 苦盡甘來 | 雪上加霜 禍不單行
錦上添花 | 雪上加霜
雪中送炭 拔刀相助 | 落井下石 袖手旁觀
事半功倍 一舉兩得 | 事倍功半 徒勞無功
見多識廣 博學多聞 學富五車 | 井底之蛙 坐井觀天 不學無術
融會貫通 | 一知半解
循序漸進 按部就班 | 拔苗助長 欲速則不達
知足常樂 | 得寸進尺 貪得無厭
推陳出新 與時俱進 | 墨守成規 一成不變 刻舟求劍
實事求是 有憑有據 千真萬確 | 無中生有 捕風捉影 道聽塗說 胡說八道
言而有信 一言九鼎 | 言而無信 出爾反爾
表裡如一 | 口是心非 陽奉陰違
光明磊落 正大光明 | 鬼鬼祟祟 偷偷摸摸
同舟共濟 同心協力 齊心協力 眾志成城 | 各自為政 一盤散沙
知恩圖報 飲水思源 | 恩將仇報 忘恩負義 過河拆橋
一見如故 | 素不相識
井井有條 有條不紊 | 亂七八糟 雜亂無章
大功告成 功成名就 馬到成功 旗開得勝 | 一敗塗地 功虧一簣 前功盡棄
金榜題名 | 名落孫山
人山人海 熙熙攘攘 | 門可羅雀
得心應手 遊刃有餘 | 力不從心
輕而易舉 易如反掌 迎刃而解 | 難如登天
一帆風順 | 一波三折 千辛萬苦
寬宏大量 | 斤斤計較 小肚雞腸
大公無私 捨己為人 | 自私自利
虛懷若谷 | 驕傲自滿 目中無人 自命不凡
妄自菲薄 | 自命不凡
勇往直前 | 畏首畏尾 膽小如鼠
當機立斷 | 猶豫不決 舉棋不定 優柔寡斷
一心一意 全神貫注 聚精會神 | 三心二意 心不在焉
一絲不苟 小心翼翼 | 粗心大意 馬馬虎虎 漫不經心
口若懸河 能言善道 | 沉默寡言
開門見山 直截了當 | 拐彎抹角
言簡意賅 | 長篇大論
省吃儉用 | 一擲千金 揮金如土
家財萬貫 | 一貧如洗
安居樂業 | 顛沛流離
慢條斯理 | 爭分奪秒
夜以繼日 廢寢忘食 | 遊手好閒
千載難逢 | 司空見慣
機不可失 | 坐失良機
寥寥無幾 | 不計其數 層出不窮
微不足道 | 舉足輕重
量力而為 | 自不量力
大驚小怪 小題大作 | 泰然自若
半斤八兩 不相上下 大同小異 一模一樣 | 天壤之別 截然不同
念念不忘 刻骨銘心 | 過眼雲煙
鴉雀無聲 萬籟俱寂 | 人山人海
春暖花開 風和日麗 | 狂風暴雨 天寒地凍
平安無事 安然無恙 | 雪上加霜
見義勇為 | 袖手旁觀 置之不理
畏首畏尾 | 破釜沉舟 背水一戰
"""

    /// 說自己的心情時，成語代表的心情（Affect.Mood）
    static let selfMood: [String: String] = [
        "心花怒放": "happy",
        "喜出望外": "happy",
        "歡天喜地": "happy",
        "興高采烈": "happy",
        "眉開眼笑": "happy",
        "笑逐顏開": "happy",
        "樂不可支": "happy",
        "欣喜若狂": "happy",
        "如釋重負": "happy",
        "悶悶不樂": "sad",
        "心灰意冷": "sad",
        "垂頭喪氣": "sad",
        "愁眉苦臉": "sad",
        "傷心欲絕": "sad",
        "痛哭流涕": "sad",
        "心如刀割": "sad",
        "怒髮衝冠": "angry",
        "火冒三丈": "angry",
        "暴跳如雷": "angry",
        "怒不可遏": "angry",
        "氣急敗壞": "angry",
        "驚慌失措": "anxious",
        "坐立不安": "anxious",
        "忐忑不安": "anxious",
        "提心吊膽": "anxious",
        "憂心忡忡": "anxious",
        "膽戰心驚": "scared",
        "毛骨悚然": "scared",
        "孤苦伶仃": "lonely",
        "形單影隻": "lonely",
        "精疲力盡": "tired",
        "筋疲力竭": "tired",
        "身心俱疲": "tired",
        "百無聊賴": "bored",
        "後悔莫及": "regret",
        "力不從心": "frustrated",
        "束手無策": "frustrated",
        "一籌莫展": "frustrated",
        "功虧一簣": "frustrated",
        "一敗塗地": "frustrated",
        "名落孫山": "frustrated",
        "前功盡棄": "frustrated",
    ]

    /// 說自己的毛病（要找改善的方法）
    static let problem: Set<String> = [
        "三天打魚兩天曬網", "一曝十寒", "半途而廢", "虎頭蛇尾", "臨時抱佛腳", "好吃懶做", "好高騖遠", "眼高手低", "紙上談兵", "言而無信",
        "出爾反爾", "三心二意", "心不在焉", "漫不經心", "粗心大意", "馬馬虎虎", "猶豫不決", "舉棋不定", "優柔寡斷", "拐彎抹角",
        "長篇大論", "一擲千金", "揮金如土", "遊手好閒", "斤斤計較", "小肚雞腸", "驕傲自滿", "妄自菲薄", "畏首畏尾", "膽小如鼠",
        "大驚小怪", "小題大作", "杞人憂天", "疑神疑鬼", "自暴自棄", "墨守成規", "信口開河", "手忙腳亂", "臨陣磨槍",
    ]
}
