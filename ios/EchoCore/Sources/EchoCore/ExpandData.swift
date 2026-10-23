// 由 ai/writing/gen_swift.py 產生，不要手改。資料在 ai/writing/expand.py

enum ExpandData {
    /// 種類|鍵|語言|內容（欄位用 ¦ 分開）
    static let table = """
SUBJ|plant|-|樹¦the tree¦el árbol¦l'albero
SUBJ|plant|-|小草¦the grass¦el césped¦il prato
SUBJ|plant|-|向日葵¦the sunflower¦el girasol¦il girasole
SUBJ|plant|-|竹子¦the bamboo¦el bambú¦il bambù
SUBJ|plant|-|種子¦the seed¦el brote¦il germoglio
SUBJ|plant|-|老榕樹¦the old banyan¦el viejo roble¦il vecchio olmo
SUBJ|plant|-|玫瑰¦the rose¦el rosal¦il roseto
SUBJ|plant|-|森林¦the forest¦el bosque¦il bosco
SUBJ|animal|-|小鳥¦the little bird¦el pajarito¦l'uccellino
SUBJ|animal|-|小貓¦the kitten¦el gatito¦il gattino
SUBJ|animal|-|小狗¦the puppy¦el perrito¦il cagnolino
SUBJ|animal|-|蝴蝶¦the butterfly¦el colibrí¦il passero
SUBJ|animal|-|老鷹¦the eagle¦el águila real¦il falco
SUBJ|animal|-|魚兒¦the fish¦el pez¦il pesce
SUBJ|animal|-|小馬¦the pony¦el potro¦il puledro
SUBJ|water|-|河水¦the river¦el río¦il fiume
SUBJ|water|-|小溪¦the stream¦el arroyo¦il ruscello
SUBJ|water|-|大海¦the sea¦el mar¦il mare
SUBJ|water|-|湖水¦the lake¦el lago¦il lago
SUBJ|water|-|瀑布¦the waterfall¦el torrente¦il torrente
SUBJ|sky|-|太陽¦the sun¦el sol¦il sole
SUBJ|sky|-|月亮¦the moon¦el lucero¦il chiaro di luna
SUBJ|sky|-|風¦the wind¦el viento¦il vento
SUBJ|sky|-|雲朵¦the cloud¦el cielo¦il cielo
SUBJ|sky|-|彩虹¦the rainbow¦el arcoíris¦l'arcobaleno
SUBJ|sky|-|星空¦the starry sky¦el firmamento¦il firmamento
SUBJ|person|-|小明¦Tom¦Pablo¦Marco
SUBJ|person|-|孩子¦the child¦el niño¦il bambino
SUBJ|person|-|爺爺¦Grandpa¦el abuelo¦il nonno
SUBJ|person|-|爸爸¦Dad¦papá¦papà
SUBJ|person|-|老人¦the old man¦el anciano¦l'anziano
SUBJ|person|-|少年¦the boy¦el muchacho¦il ragazzo
SUBJ|person|-|小華¦Jack¦Diego¦Luca
SUBJ|thing|-|時鐘¦the clock¦el reloj¦l'orologio
SUBJ|thing|-|蠟燭¦the candle¦el farol¦il lume
SUBJ|thing|-|老房子¦the old house¦el viejo caserón¦il vecchio casolare
SUBJ|thing|-|火車¦the train¦el tren¦il treno
SUBJ|thing|-|風鈴¦the wind chime¦el carillón¦il carillon
SUBJ|thing|-|小船¦the little boat¦el barquito¦il battello
SUBJ|thing|-|鋼琴¦the piano¦el piano¦il pianoforte
SUBJ|abstract|-|時間¦time¦el tiempo¦il tempo
SUBJ|abstract|-|夢想¦the dream¦el sueño¦il sogno
SUBJ|abstract|-|回憶¦the memory¦el recuerdo¦il ricordo
SUBJ|abstract|-|季節¦the season¦el otoño¦l'autunno
SUBJ|abstract|-|希望¦hope¦el deseo¦il desiderio
SUBJ|abstract|-|友情¦friendship¦el cariño¦l'affetto
PRED|grow|-|在成長¦is growing¦está creciendo¦sta crescendo¦
PRED|grow|-|慢慢長大¦is slowly getting bigger¦crece poco a poco¦cresce piano piano¦
PRED|grow|-|發芽了¦is sprouting¦está brotando¦sta germogliando¦plant
PRED|grow|-|開花了¦is blooming¦está floreciendo¦sta fiorendo¦plant
PRED|grow|-|一天天長高¦grows taller every day¦crece cada día¦cresce ogni giorno¦animal,person,plant
PRED|flow|-|在流動¦is flowing¦fluye sin parar¦scorre senza fermarsi¦abstract,sky,water
PRED|flow|-|靜靜地流淌¦flows quietly¦fluye en silencio¦scorre in silenzio¦abstract,water
PRED|flow|-|緩緩流逝¦slips slowly away¦se escapa despacio¦scivola via lentamente¦abstract
PRED|flow|-|輕輕吹過¦drifts gently by¦pasa suavemente¦passa leggero¦sky
PRED|fly|-|在飛翔¦is flying¦está volando¦sta volando¦animal
PRED|fly|-|在奔跑¦is running¦está corriendo¦sta correndo¦animal,person
PRED|fly|-|在跳舞¦is dancing¦está bailando¦sta ballando¦person,plant,sky
PRED|fly|-|在風中搖曳¦is swaying in the wind¦se mece con el viento¦ondeggia nel vento¦plant
PRED|fly|-|向前奔馳¦is rushing forward¦avanza a toda prisa¦corre in avanti¦thing,water
PRED|shine|-|在發光¦is shining¦está brillando¦sta brillando¦sky,thing,water
PRED|shine|-|升起來了¦is rising¦está saliendo¦sta sorgendo¦sky
PRED|shine|-|閃閃發亮¦is sparkling¦resplandece¦risplende¦abstract,sky,thing,water
PRED|fade|-|凋謝了¦is withering¦se está marchitando¦sta appassendo¦plant
PRED|fade|-|熄滅了¦has gone out¦se ha apagado¦si è spento¦thing
PRED|fade|-|漸漸消失¦is slowly fading¦se va desvaneciendo¦sta svanendo¦abstract,sky
PRED|fade|-|落下了¦is setting¦se está poniendo¦sta tramontando¦sky
PRED|fade|-|慢慢變淡¦is growing faint¦se va borrando¦si sta sbiadendo¦abstract
PRED|sing|-|在唱歌¦is singing¦está cantando¦sta cantando¦animal,person,water
PRED|sing|-|在響¦is ringing¦está sonando¦sta suonando¦thing
PRED|sing|-|嘩嘩作響¦is roaring¦ruge con fuerza¦ruggisce forte¦sky,water
PRED|rest|-|在睡覺¦is sleeping¦está durmiendo¦sta dormendo¦animal,person
PRED|rest|-|靜靜地等待¦is waiting quietly¦espera en silencio¦aspetta in silenzio¦
PRED|rest|-|安靜下來了¦has gone still¦se ha quedado quieto¦si è fermato¦animal,sky,thing,water
PRED|change|-|在變老¦is getting old¦se está haciendo viejo¦sta invecchiando¦person,plant,thing
PRED|change|-|變了¦has changed¦ha cambiado¦è cambiato¦
PRED|change|-|換上了新的樣子¦has taken on a new look¦luce un aspecto nuevo¦ha un aspetto nuovo¦abstract,plant,sky,thing
COMBO|plant|-|grow,fly,fade,rest,change
COMBO|animal|-|grow,fly,sing,rest
COMBO|water|-|flow,fly,shine,sing,rest
COMBO|sky|-|flow,fly,shine,fade,sing,rest,change
COMBO|person|-|grow,fly,sing,rest,change
COMBO|thing|-|fly,shine,fade,sing,rest,change
COMBO|abstract|-|grow,flow,shine,fade,rest,change
SCENE|plant|zh|清晨的陽光穿過薄霧，溫柔地灑在院子裡，泥土散發著淡淡的芬芳。
SCENE|plant|zh|微風拂過山坡，草葉沙沙作響，四周靜謐而安詳。
SCENE|plant|zh|雨後的空氣格外清新，每一片葉子上都掛著晶瑩的水珠。
SCENE|plant|en|Morning light slips through the thin mist and settles softly on the garden, and the earth gives off a faint, sweet smell.
SCENE|plant|en|A gentle breeze moves across the hillside, the leaves whisper to one another, and everything feels calm and unhurried.
SCENE|plant|en|After the rain the air is fresh and clean, and tiny drops of water glitter on every leaf.
SCENE|plant|es|La luz de la mañana atraviesa la niebla y se posa suavemente sobre el jardín, mientras la tierra desprende un aroma dulce.
SCENE|plant|es|Una brisa ligera recorre la colina, las hojas susurran entre sí y todo parece tranquilo.
SCENE|plant|es|Después de la lluvia el aire está limpio y fresco, y pequeñas gotas brillan sobre cada hoja.
SCENE|plant|it|La luce del mattino filtra attraverso la nebbia e si posa dolcemente sul giardino, mentre la terra sprigiona un profumo dolce.
SCENE|plant|it|Una brezza leggera attraversa la collina, le foglie sussurrano tra loro e tutto sembra tranquillo.
SCENE|plant|it|Dopo la pioggia l'aria è fresca e pulita, e piccole gocce brillano su ogni foglia.
SCENE|animal|zh|午後的陽光暖洋洋的，草地上開滿了不知名的小花。
SCENE|animal|zh|清晨的林子裡還帶著涼意，露水在草尖上閃閃發亮。
SCENE|animal|zh|遠處傳來幾聲清脆的鳥鳴，整個世界彷彿剛剛醒來。
SCENE|animal|en|The afternoon sun is warm and lazy, and the meadow is dotted with tiny flowers whose names nobody knows.
SCENE|animal|en|The woods are still cool in the early morning, and dew sparkles on the tips of the grass.
SCENE|animal|en|A few clear birdcalls ring out in the distance, as if the whole world has only just woken up.
SCENE|animal|es|El sol de la tarde es cálido y perezoso, y el prado está lleno de florecillas sin nombre.
SCENE|animal|es|El bosque todavía está fresco a primera hora, y el rocío brilla en las puntas de la hierba.
SCENE|animal|es|A lo lejos suenan unos trinos claros, como si el mundo entero acabara de despertar.
SCENE|animal|it|Il sole del pomeriggio è caldo e pigro, e il prato è punteggiato di fiorellini senza nome.
SCENE|animal|it|Il bosco è ancora fresco al mattino presto, e la rugiada brilla sulle punte dell'erba.
SCENE|animal|it|In lontananza risuonano alcuni canti limpidi, come se il mondo intero si fosse appena svegliato.
SCENE|water|zh|兩岸的楊柳低垂，倒影在水面上輕輕晃動。
SCENE|water|zh|陽光灑在水面上，碎成一片片閃爍的金光。
SCENE|water|zh|遠山如黛，水氣氤氳，空氣裡帶著濕潤的清涼。
SCENE|water|en|Willows lean over both banks, and their reflections tremble softly on the surface of the water.
SCENE|water|en|Sunlight falls on the water and breaks into a thousand flickering pieces of gold.
SCENE|water|en|The far hills are a soft blue, a light mist hangs in the air, and everything smells cool and damp.
SCENE|water|es|Los sauces se inclinan sobre las orillas, y sus reflejos tiemblan suavemente en el agua.
SCENE|water|es|La luz del sol cae sobre el agua y se rompe en mil destellos de oro.
SCENE|water|es|Las montañas lejanas se ven azuladas, una neblina flota en el aire y todo huele a frescor.
SCENE|water|it|I salici si chinano sulle sponde, e i loro riflessi tremano dolcemente sull'acqua.
SCENE|water|it|La luce del sole cade sull'acqua e si frantuma in mille bagliori d'oro.
SCENE|water|it|Le colline lontane sembrano azzurre, una foschia leggera sospesa nell'aria e tutto profuma di fresco.
SCENE|sky|zh|天邊的雲被染成了淡淡的金色，整片天空遼闊而溫柔。
SCENE|sky|zh|夜色漸漸褪去，東方泛起一抹魚肚白。
SCENE|sky|zh|站在山頂往上看，天空藍得透明，彷彿伸手就能碰到。
SCENE|sky|en|The clouds at the edge of the sky are brushed with pale gold, and the whole sky feels wide and gentle.
SCENE|sky|en|The night slowly fades, and a pale glow appears in the east.
SCENE|sky|en|From the top of the hill the sky is so clear and blue that it feels close enough to touch.
SCENE|sky|es|Las nubes del horizonte se tiñen de un dorado pálido, y todo el cielo parece amplio y sereno.
SCENE|sky|es|La noche se retira poco a poco, y en el este aparece un resplandor pálido.
SCENE|sky|es|Desde lo alto de la colina el cielo es tan claro y azul que parece que se podría tocar.
SCENE|sky|it|Le nuvole all'orizzonte si tingono di un oro pallido, e tutto il cielo sembra ampio e sereno.
SCENE|sky|it|La notte si ritira piano piano, e a oriente compare un chiarore pallido.
SCENE|sky|it|Dalla cima della collina il cielo è così limpido e azzurro che sembra di poterlo toccare.
SCENE|person|zh|那是一個再平凡不過的午後，窗外的陽光斜斜地照進屋裡。
SCENE|person|zh|黃昏的街道上，路燈一盞盞亮起，空氣裡飄著晚飯的香味。
SCENE|person|zh|清晨的公園裡，鳥兒在枝頭啁啾，草地上還帶著露水。
SCENE|person|en|It is an ordinary afternoon, and sunlight slants in through the window.
SCENE|person|en|At dusk the streetlights come on one by one, and the smell of dinner drifts through the air.
SCENE|person|en|In the park early in the morning, birds chatter in the branches and the grass is still wet with dew.
SCENE|person|es|Es una tarde de lo más corriente, y la luz del sol entra en diagonal por la ventana.
SCENE|person|es|Al atardecer las farolas se encienden una a una, y el olor de la cena flota en el aire.
SCENE|person|es|En el parque, muy temprano, los pájaros charlan en las ramas y la hierba sigue mojada de rocío.
SCENE|person|it|È un pomeriggio come tanti, e la luce del sole entra di sbieco dalla finestra.
SCENE|person|it|Al tramonto i lampioni si accendono uno dopo l'altro, e nell'aria c'è profumo di cena.
SCENE|person|it|Nel parco, di prima mattina, gli uccelli chiacchierano tra i rami e l'erba è ancora bagnata di rugiada.
SCENE|thing|zh|屋裡安安靜靜的，只有窗簾在風裡輕輕擺動。
SCENE|thing|zh|夜深了，整條街都睡著了，只剩下遠處偶爾傳來的幾聲狗吠。
SCENE|thing|zh|老舊的木地板吱呀作響，空氣裡飄著淡淡的灰塵和時光的味道。
SCENE|thing|en|The room is quiet, and only the curtains stir gently in the breeze.
SCENE|thing|en|It is late at night, the whole street is asleep, and only a dog barks now and then far away.
SCENE|thing|en|The old wooden floor creaks, and the air carries a faint smell of dust and passing years.
SCENE|thing|es|La habitación está en silencio, y solo las cortinas se mueven suavemente con la brisa.
SCENE|thing|es|Es muy tarde, toda la calle duerme, y solo de vez en cuando ladra un perro a lo lejos.
SCENE|thing|es|El viejo suelo de madera cruje, y el aire huele un poco a polvo y a años que pasan.
SCENE|thing|it|La stanza è silenziosa, e solo le tende si muovono piano nella brezza.
SCENE|thing|it|È notte fonda, tutta la strada dorme, e solo ogni tanto un cane abbaia in lontananza.
SCENE|thing|it|Il vecchio pavimento di legno scricchiola, e l'aria sa un po' di polvere e di anni che passano.
SCENE|abstract|zh|窗外的季節悄悄更替，樹葉綠了又黃，黃了又綠。
SCENE|abstract|zh|翻開一本舊相簿，泛黃的照片裡藏著許多熟悉的笑臉。
SCENE|abstract|zh|夜深人靜的時候，最容易聽見心裡的聲音。
SCENE|abstract|en|Outside the window the seasons change without a sound, and the leaves turn green, then gold, then green again.
SCENE|abstract|en|I open an old photo album, and the yellowed pictures are full of familiar smiling faces.
SCENE|abstract|en|Late at night, when everything is still, it is easiest to hear the voice inside your heart.
SCENE|abstract|es|Al otro lado de la ventana las estaciones cambian sin ruido, y las hojas se vuelven verdes, luego doradas, y otra vez verdes.
SCENE|abstract|es|Abro un viejo álbum de fotos, y las imágenes amarillentas están llenas de sonrisas conocidas.
SCENE|abstract|es|A altas horas de la noche, cuando todo está en calma, es más fácil escuchar la voz del corazón.
SCENE|abstract|it|Fuori dalla finestra le stagioni cambiano senza rumore, e le foglie diventano verdi, poi dorate, e poi di nuovo verdi.
SCENE|abstract|it|Apro un vecchio album di fotografie, e le immagini ingiallite sono piene di sorrisi familiari.
SCENE|abstract|it|A notte fonda, quando tutto è immobile, è più facile ascoltare la voce del cuore.
DETAIL|plant|zh|我靜靜地看著{S}，每一道紋路都像在訴說時光的故事。
DETAIL|plant|zh|陽光落在{S}身上，綠意盎然，彷彿連呼吸都帶著生命的氣息。
DETAIL|plant|en|I stand still and look at {s} for a long time; every line on its leaves seems to hold a small story of time.
DETAIL|plant|en|Sunlight touches {s}, and the green is so alive that it almost seems to breathe.
DETAIL|plant|es|Me quedo un buen rato mirando {s}; cada línea de sus hojas parece guardar una pequeña historia del tiempo.
DETAIL|plant|es|La luz del sol acaricia {s}, y su verde está tan vivo que casi parece respirar.
DETAIL|plant|it|Resto a lungo a guardare {s}; ogni venatura delle sue foglie sembra custodire una piccola storia del tempo.
DETAIL|plant|it|La luce del sole accarezza {s}, e quel verde è così vivo che sembra quasi respirare.
DETAIL|animal|zh|我忍不住停下腳步，靜靜地看著{S}，那雙眼睛清澈又靈動。
DETAIL|animal|zh|{S}輕巧的身影在陽光裡閃動，每一個動作都充滿了生命力。
DETAIL|animal|en|I can't help stopping to watch {s}; those eyes are clear and full of life.
DETAIL|animal|en|The light, quick shape of {s} flickers in the sunshine, and every movement is full of energy.
DETAIL|animal|es|No puedo evitar detenerme a mirar {s}; esos ojos son claros y llenos de vida.
DETAIL|animal|es|Contemplo {s} moverse a la luz del sol, y cada movimiento está lleno de energía.
DETAIL|animal|it|Non riesco a non fermarmi a guardare {s}; quegli occhi sono limpidi e pieni di vita.
DETAIL|animal|it|Osservo {s} muoversi nella luce del sole, e ogni movimento è pieno di energia.
DETAIL|water|zh|我蹲在岸邊，看著{S}清澈見底，連水底的小石子都看得一清二楚。
DETAIL|water|zh|{S}在陽光下泛著粼粼的波光，叮叮咚咚地唱著自己的歌。
DETAIL|water|en|I crouch on the bank and watch {s}; it is so clear that I can see every pebble on the bottom.
DETAIL|water|en|In the sunlight {s} glitters with ripples, humming a song of its own.
DETAIL|water|es|Me agacho en la orilla y contemplo {s}; es tan transparente que se ven todas las piedrecitas del fondo.
DETAIL|water|es|Bajo el sol, el agua brilla con mil ondas, como si cantara una canción propia.
DETAIL|water|it|Mi accovaccio sulla riva e osservo {s}; è così limpido che si vedono tutti i sassolini sul fondo.
DETAIL|water|it|Sotto il sole l'acqua luccica di mille increspature, come se cantasse una canzone tutta sua.
DETAIL|sky|zh|我抬起頭，久久地望著{S}，心也跟著變得遼闊起來。
DETAIL|sky|zh|{S}靜靜地掛在那裡，溫柔地注視著人間的一切。
DETAIL|sky|en|I lift my head and gaze at {s} for a long time, and my heart seems to grow wider too.
DETAIL|sky|en|I watch {s} for a while; it seems to look down on the world with quiet tenderness.
DETAIL|sky|es|Levanto la cabeza y contemplo {s} durante mucho tiempo, y siento que mi corazón también se ensancha.
DETAIL|sky|es|Observo {s} un buen rato; parece mirar el mundo con una ternura silenciosa.
DETAIL|sky|it|Alzo la testa e contemplo {s} a lungo, e sento che anche il mio cuore si allarga.
DETAIL|sky|it|Osservo {s} per un po'; sembra guardare il mondo con una tenerezza silenziosa.
DETAIL|person|zh|我靜靜地看著{S}，那專注的神情讓人忍不住多看幾眼。
DETAIL|person|zh|陽光落在{S}的臉上，眼睛裡閃著溫柔的光。
DETAIL|person|en|I quietly watch {s}, and there is something in that focused expression that makes me look twice.
DETAIL|person|en|Sunlight falls across the face of {s}, and those eyes shine with a gentle light.
DETAIL|person|es|Observo en silencio a {s}, y hay algo en esa expresión concentrada que me hace mirar dos veces.
DETAIL|person|es|La luz del sol ilumina la cara de {s}, y sus ojos brillan con una luz suave.
DETAIL|person|it|Osservo in silenzio {s}, e c'è qualcosa in quell'espressione concentrata che mi fa guardare due volte.
DETAIL|person|it|La luce del sole illumina il volto di {s}, e i suoi occhi brillano di una luce dolce.
DETAIL|thing|zh|我輕輕地走近{S}，好像怕驚擾了它沉睡的回憶。
DETAIL|thing|zh|{S}靜靜地待在那裡，身上的每一道痕跡都是歲月留下的印記。
DETAIL|thing|en|I walk slowly toward {s}, as if I were afraid of waking the memories sleeping inside it.
DETAIL|thing|en|I look at {s} for a long while; every mark on it is a trace left behind by the years.
DETAIL|thing|es|Me acerco despacio a {s}, como si temiera despertar los recuerdos que duermen dentro.
DETAIL|thing|es|Miro {s} durante un buen rato; cada marca es una huella que han dejado los años.
DETAIL|thing|it|Mi avvicino piano a {s}, come se avessi paura di svegliare i ricordi che ci dormono dentro.
DETAIL|thing|it|Guardo {s} a lungo; ogni segno è una traccia lasciata dagli anni.
DETAIL|abstract|zh|{S}看不見、摸不著，卻真真切切地存在於每一個人的生命裡。
DETAIL|abstract|zh|我常常想，{S}究竟是什麼樣子？也許它就藏在每一個平凡的日子裡。
DETAIL|abstract|en|We cannot see or touch {s}, and yet it lives inside every single life.
DETAIL|abstract|en|I often wonder what {s} really looks like; maybe it hides inside each ordinary day.
DETAIL|abstract|es|No podemos ver ni tocar {s}, y sin embargo vive dentro de cada vida.
DETAIL|abstract|es|A menudo me pregunto cómo es de verdad {s}; quizás se esconde en cada día corriente.
DETAIL|abstract|it|Non possiamo vedere né toccare {s}, eppure vive dentro ogni vita.
DETAIL|abstract|it|Spesso mi chiedo come sia davvero {s}; forse si nasconde in ogni giorno qualunque.
ACT.vivid|grow|zh|{O}，一點一點，不聲不響，卻從來沒有停下腳步。
ACT.vivid|grow|zh|{O}。每一天都比昨天多了一點點，那是看不見、卻真實存在的努力。
ACT.vivid|grow|en|{O}, little by little, quietly, without ever stopping.
ACT.vivid|grow|en|{O}. Each day adds a little more than the day before, an effort no one sees but that is real all the same.
ACT.vivid|grow|es|{O}, poco a poco, en silencio, sin detenerse nunca.
ACT.vivid|grow|es|{O}. Cada día añade un poco más que el anterior, un esfuerzo que nadie ve pero que es real.
ACT.vivid|grow|it|{O}, piano piano, in silenzio, senza mai fermarsi.
ACT.vivid|grow|it|{O}. Ogni giorno aggiunge un po' più del giorno prima, uno sforzo che nessuno vede ma che è reale.
ACT.simile|grow|zh|那份成長像一首緩慢的歌，每一個音符都是陽光和雨水寫成的。
ACT.simile|grow|zh|那彷彿一個默默努力的孩子，把所有的力氣都藏在看不見的地方。
ACT.simile|grow|en|This growth is like a slow song, every note written by sunlight and rain.
ACT.simile|grow|en|It is as if a quiet child were working hard, hiding all its strength where no one can see.
ACT.simile|grow|es|Este crecimiento es como una canción lenta, cada nota escrita por el sol y la lluvia.
ACT.simile|grow|es|Es como un niño callado que se esfuerza, escondiendo toda su fuerza donde nadie la ve.
ACT.simile|grow|it|Questa crescita è come una canzone lenta, ogni nota scritta dal sole e dalla pioggia.
ACT.simile|grow|it|È come un bambino silenzioso che si impegna, nascondendo tutta la sua forza dove nessuno la vede.
ACT.feel|grow|zh|看著看著，我的心裡湧起一股暖暖的感動。
ACT.feel|grow|zh|一種說不出的欣慰悄悄爬上心頭，讓人忍不住微笑。
ACT.feel|grow|en|The longer I watch, the more a warm, quiet tenderness fills my heart.
ACT.feel|grow|en|A joy I can't quite name rises in my chest, and I can't help smiling.
ACT.feel|grow|es|Cuanto más miro, más se llena mi corazón de una ternura cálida y tranquila.
ACT.feel|grow|es|Una alegría que no sé nombrar me sube al pecho, y no puedo evitar sonreír.
ACT.feel|grow|it|Più guardo, più il mio cuore si riempie di una tenerezza calda e silenziosa.
ACT.feel|grow|it|Una gioia che non so nominare mi sale nel petto, e non riesco a non sorridere.
ACT.view|grow|zh|我想，成長從來不是一瞬間的事，而是日復一日的堅持。
ACT.view|grow|zh|我始終相信，真正的力量往往是安靜的，它不需要被誰看見。
ACT.view|grow|en|I believe that growing is never a single moment; it is the patience of a thousand ordinary days.
ACT.view|grow|en|To me, real strength is often quiet; it does not need anyone to notice it.
ACT.view|grow|es|Creo que crecer nunca es un solo instante, sino la paciencia de mil días corrientes.
ACT.view|grow|es|Para mí, la verdadera fuerza suele ser silenciosa; no necesita que nadie la vea.
ACT.view|grow|it|Credo che crescere non sia mai un solo istante, ma la pazienza di mille giorni qualunque.
ACT.view|grow|it|Per me, la vera forza è spesso silenziosa; non ha bisogno che qualcuno la veda.
ACT.end|grow|zh|總有一天，這份耐心會開出最美的花，而我會一直記得今天這一刻。
ACT.end|grow|zh|風輕輕吹過，帶著希望的味道，向更遠的明天飄去。
ACT.end|grow|en|One day all this patience will turn into something beautiful, and I will remember this moment.
ACT.end|grow|en|The wind drifts by, carrying the scent of hope toward a farther tomorrow.
ACT.end|grow|es|Algún día toda esta paciencia se convertirá en algo hermoso, y yo recordaré este momento.
ACT.end|grow|es|El viento pasa despacio, llevando el olor de la esperanza hacia un mañana más lejano.
ACT.end|grow|it|Un giorno tutta questa pazienza diventerà qualcosa di bellissimo, e io ricorderò questo momento.
ACT.end|grow|it|Il vento passa lento, portando il profumo della speranza verso un domani più lontano.
IDIOM|grow|zh|鍥而不捨,滴水穿石,持之以恆
PROVERB|grow|en|As the old saying goes, great oaks from little acorns grow.
PROVERB|grow|es|Como dice el refrán, poco a poco se va lejos.
PROVERB|grow|it|Come dice il proverbio, piano piano si va lontano.
ACT.vivid|flow|zh|{O}，不急也不停，像在輕聲訴說一個很長很長的故事。
ACT.vivid|flow|zh|{O}。它從遠方來，又往遠方去，從不為誰停留。
ACT.vivid|flow|en|{O}, never hurrying and never stopping, as if softly telling a very long story.
ACT.vivid|flow|en|{O}. It comes from far away and goes far away again, never waiting for anyone.
ACT.vivid|flow|es|{O}, sin prisa y sin pausa, como si contara en voz baja una historia muy larga.
ACT.vivid|flow|es|{O}. Viene de lejos y se va lejos otra vez, sin esperar a nadie.
ACT.vivid|flow|it|{O}, senza fretta e senza sosta, come se raccontasse sottovoce una storia molto lunga.
ACT.vivid|flow|it|{O}. Viene da lontano e va lontano di nuovo, senza aspettare nessuno.
ACT.simile|flow|zh|它像一條柔軟的絲帶，輕輕地繫住了過去和未來。
ACT.simile|flow|zh|那份流動宛如一首沒有結尾的詩，每一行都在悄悄地改變。
ACT.simile|flow|en|It is like a soft ribbon that gently ties the past to the future.
ACT.simile|flow|en|This flowing is like a poem without an ending, each line quietly changing.
ACT.simile|flow|es|Es como una cinta suave que ata con delicadeza el pasado y el futuro.
ACT.simile|flow|es|Este fluir es como un poema sin final, cada verso cambiando en silencio.
ACT.simile|flow|it|È come un nastro morbido che lega con dolcezza il passato e il futuro.
ACT.simile|flow|it|Questo scorrere è come una poesia senza fine, ogni verso che cambia in silenzio.
ACT.feel|flow|zh|我的心也跟著安靜下來，那些煩惱彷彿被輕輕地帶走了。
ACT.feel|flow|zh|一絲淡淡的惆悵湧上心頭，卻又夾雜著說不出的平靜。
ACT.feel|flow|en|My heart grows calm as well, as if my worries were being gently carried away.
ACT.feel|flow|en|A faint wistfulness rises in my heart, mixed with a peace I cannot explain.
ACT.feel|flow|es|Mi corazón también se calma, como si mis preocupaciones se fueran con la corriente.
ACT.feel|flow|es|Una leve nostalgia me llega al corazón, mezclada con una paz que no sé explicar.
ACT.feel|flow|it|Anche il mio cuore si calma, come se le mie preoccupazioni venissero portate via con dolcezza.
ACT.feel|flow|it|Una lieve malinconia mi sale al cuore, mescolata a una pace che non so spiegare.
ACT.view|flow|zh|我想，生命中的許多事就像流水，抓不住，所以更要珍惜當下。
ACT.view|flow|zh|在我看來，懂得放手，也是一種溫柔的勇氣。
ACT.view|flow|en|I think many things in life are like flowing water: we cannot hold them, so we must cherish the present.
ACT.view|flow|en|To me, knowing how to let go is a gentle kind of courage.
ACT.view|flow|es|Pienso que muchas cosas de la vida son como el agua: no se pueden sujetar, por eso hay que valorar el presente.
ACT.view|flow|es|Para mí, saber soltar también es una forma tierna de valentía.
ACT.view|flow|it|Penso che molte cose della vita siano come l'acqua che scorre: non si possono trattenere, per questo bisogna amare il presente.
ACT.view|flow|it|Per me, saper lasciare andare è anche una forma dolce di coraggio.
ACT.end|flow|zh|它還在流著，帶著我的思念，一路流向看不見的遠方。
ACT.end|flow|zh|夕陽西下，水光粼粼，一切都溫柔得剛剛好。
ACT.end|flow|en|It keeps on flowing, carrying my thoughts toward a place I cannot see.
ACT.end|flow|en|As the sun goes down, the light dances on the water, and everything is gentle and just right.
ACT.end|flow|es|Sigue fluyendo, llevándose mis pensamientos hacia un lugar que no puedo ver.
ACT.end|flow|es|Cuando el sol se pone, la luz baila sobre el agua, y todo es suave y justo como debe ser.
ACT.end|flow|it|Continua a scorrere, portando i miei pensieri verso un luogo che non posso vedere.
ACT.end|flow|it|Quando il sole tramonta, la luce danza sull'acqua, e tutto è dolce e giusto così.
IDIOM|flow|zh|光陰似箭,順其自然,隨遇而安
PROVERB|flow|en|As they say, time and tide wait for no man.
PROVERB|flow|es|Como dice el refrán, agua que no has de beber, déjala correr.
PROVERB|flow|it|Come si dice, il tempo vola e non aspetta nessuno.
ACT.vivid|fly|zh|{O}，那樣輕盈，那樣自在，好像整個世界都屬於它。
ACT.vivid|fly|zh|{O}。每一個動作都充滿了活力，讓人看得目不轉睛。
ACT.vivid|fly|en|{O}, so light and so free, as if the whole world belonged to this moment.
ACT.vivid|fly|en|{O}. Every movement is full of life, and I cannot look away.
ACT.vivid|fly|es|{O}, tan ligero y tan libre, como si el mundo entero perteneciera a este momento.
ACT.vivid|fly|es|{O}. Cada movimiento está lleno de vida, y no puedo apartar la vista.
ACT.vivid|fly|it|{O}, così leggero e così libero, come se il mondo intero appartenesse a questo momento.
ACT.vivid|fly|it|{O}. Ogni movimento è pieno di vita, e non riesco a distogliere lo sguardo.
ACT.simile|fly|zh|那身影像一陣自由的風，誰也抓不住。
ACT.simile|fly|zh|它宛如一個跳躍的音符，在空氣裡寫下快樂的旋律。
ACT.simile|fly|en|It moves like a free wind that no one can catch.
ACT.simile|fly|en|It is like a dancing note, writing a happy melody in the air.
ACT.simile|fly|es|Se mueve como un viento libre que nadie puede atrapar.
ACT.simile|fly|es|Es como una nota que baila, escribiendo una melodía alegre en el aire.
ACT.simile|fly|it|Si muove come un vento libero che nessuno può afferrare.
ACT.simile|fly|it|È come una nota che danza, scrivendo una melodia allegra nell'aria.
ACT.feel|fly|zh|我的心也跟著雀躍起來，好像自己也長出了翅膀。
ACT.feel|fly|zh|一股說不出的暢快從心底湧上來，讓人想放聲大笑。
ACT.feel|fly|en|My heart leaps with joy along with it, as if I had grown wings myself.
ACT.feel|fly|en|A wild, happy freedom rises from deep inside me, and I want to laugh out loud.
ACT.feel|fly|es|Mi corazón salta de alegría, como si a mí también me hubieran crecido alas.
ACT.feel|fly|es|Una alegría libre me sube desde lo más hondo, y me dan ganas de reír en voz alta.
ACT.feel|fly|it|Il mio cuore salta di gioia, come se anche a me fossero spuntate le ali.
ACT.feel|fly|it|Una gioia libera mi sale dal profondo, e ho voglia di ridere ad alta voce.
ACT.view|fly|zh|我想，生命最美的樣子，就是勇敢地做自己。
ACT.view|fly|zh|我覺得，自由不是沒有方向，而是心裡有光，就敢往前。
ACT.view|fly|en|I believe life is at its most beautiful when it bravely becomes itself.
ACT.view|fly|en|To me, freedom is not having no direction; it is having a light inside and daring to move forward.
ACT.view|fly|es|Creo que la vida es más hermosa cuando se atreve a ser ella misma.
ACT.view|fly|es|Para mí, la libertad no es no tener rumbo, sino llevar una luz dentro y atreverse a avanzar.
ACT.view|fly|it|Credo che la vita sia più bella quando ha il coraggio di essere se stessa.
ACT.view|fly|it|Per me, la libertà non è non avere una meta, ma avere una luce dentro e osare andare avanti.
ACT.end|fly|zh|它越去越遠，最後融進了天邊的光裡，只留下我心裡久久的悸動。
ACT.end|fly|zh|那一刻的輕盈，從此留在了我的記憶裡。
ACT.end|fly|en|It moves farther and farther away until it melts into the light on the horizon, leaving only a long echo in my heart.
ACT.end|fly|en|The lightness of that moment stays in my memory from then on.
ACT.end|fly|es|Se aleja cada vez más hasta fundirse con la luz del horizonte, dejando solo un largo eco en mi corazón.
ACT.end|fly|es|La ligereza de aquel momento se queda para siempre en mi memoria.
ACT.end|fly|it|Si allontana sempre di più finché si scioglie nella luce dell'orizzonte, lasciando solo una lunga eco nel mio cuore.
ACT.end|fly|it|La leggerezza di quel momento resta per sempre nella mia memoria.
IDIOM|fly|zh|勇往直前,無憂無慮,興高采烈
PROVERB|fly|en|As the saying goes, the sky is the limit.
PROVERB|fly|es|Como dice el refrán, querer es poder.
PROVERB|fly|it|Come dice il proverbio, volere è potere.
ACT.vivid|shine|zh|{O}，光芒溫柔而明亮，把四周都照得暖洋洋的。
ACT.vivid|shine|zh|{O}。那光不刺眼，卻讓人心裡一下子亮了起來。
ACT.vivid|shine|en|{O}, its light soft and bright, warming everything around it.
ACT.vivid|shine|en|{O}. The light is not harsh, yet it suddenly brightens something inside me.
ACT.vivid|shine|es|{O}, con una luz suave y clara que lo calienta todo a su alrededor.
ACT.vivid|shine|es|{O}. La luz no deslumbra, pero de pronto ilumina algo dentro de mí.
ACT.vivid|shine|it|{O}, con una luce dolce e chiara che riscalda tutto intorno.
ACT.vivid|shine|it|{O}. La luce non abbaglia, eppure all'improvviso illumina qualcosa dentro di me.
ACT.simile|shine|zh|那光芒像一雙溫暖的手，輕輕撫平了心裡的皺褶。
ACT.simile|shine|zh|它宛如一盞為遠行人點亮的燈，安靜卻堅定。
ACT.simile|shine|en|The light is like a pair of warm hands smoothing out the creases in my heart.
ACT.simile|shine|en|It is like a lamp lit for a traveler far from home, quiet but steady.
ACT.simile|shine|es|La luz es como unas manos cálidas que alisan las arrugas de mi corazón.
ACT.simile|shine|es|Es como una lámpara encendida para un viajero lejos de casa, callada pero firme.
ACT.simile|shine|it|La luce è come due mani calde che lisciano le pieghe del mio cuore.
ACT.simile|shine|it|È come una lampada accesa per un viaggiatore lontano da casa, silenziosa ma salda.
ACT.feel|shine|zh|我的心頭一暖，好像所有的陰霾都被照散了。
ACT.feel|shine|zh|一種溫柔的感動在心裡蔓延開來，讓人眼眶微微發熱。
ACT.feel|shine|en|My heart grows warm, as if every shadow inside it had been chased away.
ACT.feel|shine|en|A gentle emotion spreads through my heart, and my eyes grow a little warm.
ACT.feel|shine|es|Se me calienta el corazón de ternura, como si todas las sombras se hubieran disipado.
ACT.feel|shine|es|Una emoción tierna se extiende por mi corazón, y se me humedecen un poco los ojos.
ACT.feel|shine|it|Mi si scalda il cuore di tenerezza, come se tutte le ombre fossero svanite.
ACT.feel|shine|it|Un'emozione dolce si diffonde nel mio cuore, e gli occhi mi diventano un po' lucidi.
ACT.view|shine|zh|我相信，每個人心裡都有一束光，只要不放棄，總會照亮前方的路。
ACT.view|shine|zh|在我看來，真正的溫暖，是願意把自己的光分給別人。
ACT.view|shine|en|I believe there is a light in every heart, and if we never give up, it will light the road ahead.
ACT.view|shine|en|To me, true warmth means being willing to share your light with others.
ACT.view|shine|es|Creo que en cada corazón hay una luz, y si no nos rendimos, iluminará el camino.
ACT.view|shine|es|Para mí, el verdadero calor es estar dispuesto a compartir tu luz con los demás.
ACT.view|shine|it|Credo che in ogni cuore ci sia una luce, e se non ci arrendiamo, illuminerà la strada.
ACT.view|shine|it|Per me, il vero calore è essere disposti a condividere la propria luce con gli altri.
ACT.end|shine|zh|光芒灑滿大地，新的一天，就這樣溫柔地開始了。
ACT.end|shine|zh|那道光，從此一直亮在我的心裡。
ACT.end|shine|en|The light spreads across the land, and a new day begins, just like that, gently.
ACT.end|shine|en|That light has stayed bright in my heart ever since.
ACT.end|shine|es|La luz se extiende por la tierra, y un nuevo día comienza así, con suavidad.
ACT.end|shine|es|Esa luz se ha quedado encendida en mi corazón desde entonces.
ACT.end|shine|it|La luce si diffonde sulla terra, e un nuovo giorno comincia così, con dolcezza.
ACT.end|shine|it|Quella luce è rimasta accesa nel mio cuore da allora.
IDIOM|shine|zh|前程似錦,否極泰來,柳暗花明
PROVERB|shine|en|As they say, every cloud has a silver lining.
PROVERB|shine|es|Como dice el refrán, no hay mal que por bien no venga.
PROVERB|shine|it|Come dice il proverbio, dopo la tempesta torna il sereno.
ACT.vivid|fade|zh|{O}，那樣安靜，好像怕驚擾了誰。
ACT.vivid|fade|zh|{O}。曾經的美好一點一點地退去，只留下淡淡的痕跡。
ACT.vivid|fade|en|{O}, so quietly, as if afraid of disturbing anyone.
ACT.vivid|fade|en|{O}. What was once beautiful slowly slips away, leaving only a faint trace behind.
ACT.vivid|fade|es|{O}, tan en silencio, como si temiera molestar a alguien.
ACT.vivid|fade|es|{O}. Lo que fue hermoso se va retirando despacio, dejando solo una huella leve.
ACT.vivid|fade|it|{O}, così in silenzio, come se temesse di disturbare qualcuno.
ACT.vivid|fade|it|{O}. Ciò che era bello si ritira piano, lasciando solo una traccia leggera.
ACT.simile|fade|zh|那像一封寫到最後一頁的信，字跡漸漸淡去，心意卻還在。
ACT.simile|fade|zh|它宛如一聲輕輕的嘆息，飄散在風裡。
ACT.simile|fade|en|It is like a letter on its last page, the ink fading while the feeling remains.
ACT.simile|fade|en|It is like a soft sigh, scattering in the wind.
ACT.simile|fade|es|Es como una carta en su última página, la tinta se borra pero el sentimiento sigue ahí.
ACT.simile|fade|es|Es como un suspiro suave que se dispersa en el viento.
ACT.simile|fade|it|È come una lettera all'ultima pagina, l'inchiostro sbiadisce ma il sentimento resta.
ACT.simile|fade|it|È come un sospiro leggero che si disperde nel vento.
ACT.feel|fade|zh|我的心裡泛起一陣淡淡的不捨，久久不能平靜。
ACT.feel|fade|zh|一絲憂傷輕輕地落在心頭，像秋天的第一片落葉。
ACT.feel|fade|en|A quiet sadness rises in my heart, and it takes a long time to settle.
ACT.feel|fade|en|A thread of sorrow lands softly on my heart, like the first falling leaf of autumn.
ACT.feel|fade|es|Una tristeza callada me sube al corazón, y tarda mucho en calmarse.
ACT.feel|fade|es|Un hilo de melancolía cae suave sobre mi corazón, como la primera hoja del otoño.
ACT.feel|fade|it|Una tristezza silenziosa mi sale al cuore, e ci mette molto a calmarsi.
ACT.feel|fade|it|Un filo di malinconia mi cade piano sul cuore, come la prima foglia d'autunno.
ACT.view|fade|zh|我想，凋零並不是結束，而是為了下一次的綻放。
ACT.view|fade|zh|或許，正因為美好會消失，我們才更懂得珍惜。
ACT.view|fade|en|I believe that fading is not an ending, but a quiet preparation for the next bloom.
ACT.view|fade|en|Perhaps it is because beautiful things fade that we learn to treasure them.
ACT.view|fade|es|Creo que apagarse no es un final, sino una preparación silenciosa para el próximo florecer.
ACT.view|fade|es|Quizás es porque lo bello se acaba que aprendemos a valorarlo.
ACT.view|fade|it|Credo che svanire non sia una fine, ma una preparazione silenziosa per la prossima fioritura.
ACT.view|fade|it|Forse è proprio perché le cose belle finiscono che impariamo ad averne cura.
ACT.end|fade|zh|夜色漸深，一切歸於寂靜，但我知道，明天還會有新的開始。
ACT.end|fade|zh|我輕輕地道了一聲再見，把那份美好收進心裡。
ACT.end|fade|en|The night grows deeper and everything falls silent, but I know tomorrow will bring a new beginning.
ACT.end|fade|en|I softly say goodbye and keep that beauty safe inside my heart.
ACT.end|fade|es|La noche se hace más profunda y todo calla, pero sé que mañana habrá un nuevo comienzo.
ACT.end|fade|es|Me despido en voz baja y guardo esa belleza en mi corazón.
ACT.end|fade|it|La notte si fa più profonda e tutto tace, ma so che domani ci sarà un nuovo inizio.
ACT.end|fade|it|Saluto piano e custodisco quella bellezza nel mio cuore.
IDIOM|fade|zh|過眼雲煙,塞翁失馬,否極泰來
PROVERB|fade|en|As the saying goes, when one door closes, another opens.
PROVERB|fade|es|Como dice el refrán, cuando una puerta se cierra, otra se abre.
PROVERB|fade|it|Come dice il proverbio, quando si chiude una porta si apre un portone.
ACT.vivid|sing|zh|{O}，聲音清亮而悠揚，在空氣裡一圈一圈地蕩漾開來。
ACT.vivid|sing|zh|{O}。那聲音不大，卻輕輕地敲進了每個人的心裡。
ACT.vivid|sing|en|{O}, the sound clear and lilting, spreading through the air in gentle circles.
ACT.vivid|sing|en|{O}. The sound is not loud, yet it softly knocks on every heart.
ACT.vivid|sing|es|{O}, con un sonido claro y melodioso que se extiende por el aire en círculos suaves.
ACT.vivid|sing|es|{O}. El sonido no es fuerte, pero llama suavemente a cada corazón.
ACT.vivid|sing|it|{O}, con un suono limpido e melodioso che si allarga nell'aria in cerchi leggeri.
ACT.vivid|sing|it|{O}. Il suono non è forte, eppure bussa piano a ogni cuore.
ACT.simile|sing|zh|那聲音像山間的清泉，叮叮咚咚地流進心田。
ACT.simile|sing|zh|它宛如一首古老的歌謠，帶著遠方的味道。
ACT.simile|sing|en|The sound is like a mountain spring, trickling straight into my heart.
ACT.simile|sing|en|It is like an old folk song carrying the taste of faraway places.
ACT.simile|sing|es|El sonido es como un manantial de montaña que entra directo en mi corazón.
ACT.simile|sing|es|Es como una vieja canción popular que trae el sabor de lugares lejanos.
ACT.simile|sing|it|Il suono è come una sorgente di montagna che scorre dritta nel mio cuore.
ACT.simile|sing|it|È come una vecchia canzone popolare che porta il sapore di luoghi lontani.
ACT.feel|sing|zh|我閉上眼睛聆聽，心裡湧起一股說不出的溫柔。
ACT.feel|sing|zh|那一刻，我的心彷彿被輕輕地觸動了，暖暖的，又有點想哭。
ACT.feel|sing|en|I close my eyes and listen, and a tenderness I cannot describe fills my heart.
ACT.feel|sing|en|In that moment my heart is gently touched, warm and a little tearful.
ACT.feel|sing|es|Cierro los ojos y escucho, y una ternura que no sé describir me llena el corazón.
ACT.feel|sing|es|En ese momento mi corazón se llena de emoción, cálido y un poco conmovido.
ACT.feel|sing|it|Chiudo gli occhi e ascolto, e una tenerezza che non so descrivere mi riempie il cuore.
ACT.feel|sing|it|In quel momento il mio cuore si commuove, caldo e un po' emozionato.
ACT.view|sing|zh|我想，世界上最動人的聲音，往往來自最真誠的心。
ACT.view|sing|zh|我覺得，願意為生活歌唱的人，心裡一定藏著很多愛。
ACT.view|sing|en|I think the most moving sounds in the world often come from the most honest hearts.
ACT.view|sing|en|To me, anyone who sings for life must be carrying a lot of love inside.
ACT.view|sing|es|Pienso que los sonidos más conmovedores del mundo nacen de los corazones más sinceros.
ACT.view|sing|es|Para mí, quien canta a la vida lleva mucho amor por dentro.
ACT.view|sing|it|Penso che i suoni più commoventi del mondo nascano dai cuori più sinceri.
ACT.view|sing|it|Per me, chi canta per la vita porta dentro tanto amore.
ACT.end|sing|zh|聲音漸漸遠去，卻在我的心裡餘音繞樑，久久不散。
ACT.end|sing|zh|風把那旋律帶向遠方，我卻把它留在了心底。
ACT.end|sing|en|The sound slowly fades away, yet it lingers in my heart for a long, long time.
ACT.end|sing|en|The wind carries the melody far away, but I keep it deep in my heart.
ACT.end|sing|es|El sonido se aleja poco a poco, pero se queda en mi corazón durante mucho tiempo.
ACT.end|sing|es|El viento se lleva la melodía lejos, pero yo la guardo en el fondo de mi corazón.
ACT.end|sing|it|Il suono si allontana piano piano, ma resta nel mio cuore a lungo.
ACT.end|sing|it|Il vento porta lontano la melodia, ma io la custodisco in fondo al cuore.
IDIOM|sing|zh|嘆為觀止,心平氣和,美不勝收
PROVERB|sing|en|As they say, music speaks where words fail.
PROVERB|sing|es|Como dice el refrán, quien canta su mal espanta.
PROVERB|sing|it|Come si dice, la musica arriva dove le parole non arrivano.
ACT.vivid|rest|zh|{O}，四周靜悄悄的，連風都放輕了腳步。
ACT.vivid|rest|zh|{O}。那份安靜不是空白，而是滿滿的安心。
ACT.vivid|rest|en|{O}, and everything around is so quiet that even the wind walks on tiptoe.
ACT.vivid|rest|en|{O}. The stillness is not empty; it is full of peace.
ACT.vivid|rest|es|{O}, y todo alrededor está tan callado que hasta el viento camina de puntillas.
ACT.vivid|rest|es|{O}. La quietud no está vacía; está llena de paz.
ACT.vivid|rest|it|{O}, e tutto intorno è così silenzioso che perfino il vento cammina in punta di piedi.
ACT.vivid|rest|it|{O}. Il silenzio non è vuoto; è pieno di pace.
ACT.simile|rest|zh|那份寧靜像一床柔軟的被子，溫柔地蓋住了整個世界。
ACT.simile|rest|zh|一切宛如一幅靜止的畫，美得讓人捨不得出聲。
ACT.simile|rest|en|The calm is like a soft blanket gently laid over the whole world.
ACT.simile|rest|en|Everything looks like a painting that has stopped in time, too lovely to disturb.
ACT.simile|rest|es|La calma es como una manta suave que cubre con ternura el mundo entero.
ACT.simile|rest|es|Todo parece un cuadro detenido en el tiempo, demasiado bello para molestarlo.
ACT.simile|rest|it|La calma è come una coperta morbida stesa con dolcezza sul mondo intero.
ACT.simile|rest|it|Tutto sembra un quadro fermo nel tempo, troppo bello per disturbarlo.
ACT.feel|rest|zh|我的心也跟著慢了下來，所有的疲憊都悄悄地鬆開了。
ACT.feel|rest|zh|看著這一幕，一種久違的安心在心底輕輕地蔓延。
ACT.feel|rest|en|My heart slows down too, and all my tiredness quietly loosens.
ACT.feel|rest|en|Watching this, a peace I have not felt in a long time spreads softly through my heart.
ACT.feel|rest|es|Mi corazón también se calma, y todo mi cansancio se afloja en silencio.
ACT.feel|rest|es|Al ver esta escena, una paz que hacía tiempo no sentía se extiende por mi corazón.
ACT.feel|rest|it|Anche il mio cuore rallenta, e tutta la stanchezza si scioglie in silenzio.
ACT.feel|rest|it|Guardando questa scena, una pace che non sentivo da tempo si diffonde nel mio cuore.
ACT.view|rest|zh|我想，在忙碌的生活裡，願意停下來，也是一種智慧。
ACT.view|rest|zh|我相信，最深的力量，往往藏在最安靜的時刻。
ACT.view|rest|en|I think that in a busy life, choosing to pause is a kind of wisdom.
ACT.view|rest|en|I believe the deepest strength is often hidden in the quietest moments.
ACT.view|rest|es|Pienso que en una vida tan ocupada, saber detenerse también es sabiduría.
ACT.view|rest|es|Creo que la fuerza más profunda suele esconderse en los momentos más silenciosos.
ACT.view|rest|it|Penso che in una vita così piena, saper fermarsi sia anche saggezza.
ACT.view|rest|it|Credo che la forza più profonda si nasconda spesso nei momenti più silenziosi.
ACT.end|rest|zh|時間彷彿在這裡停了下來，只留下一片溫柔的寧靜。
ACT.end|rest|zh|我輕輕地離開，不忍心打擾這份安詳。
ACT.end|rest|en|Time seems to stop here, leaving only a gentle stillness behind.
ACT.end|rest|en|I leave quietly, unwilling to disturb such peace.
ACT.end|rest|es|El tiempo parece detenerse aquí, dejando solo una calma tierna.
ACT.end|rest|es|Me alejo en silencio, sin querer perturbar tanta paz.
ACT.end|rest|it|Il tempo sembra fermarsi qui, lasciando solo una calma dolce.
ACT.end|rest|it|Me ne vado in silenzio, senza voler disturbare tanta pace.
IDIOM|rest|zh|萬籟俱寂,心平氣和,無憂無慮
PROVERB|rest|en|As the saying goes, still waters run deep.
PROVERB|rest|es|Como dice el refrán, la calma es la madre de la sabiduría.
PROVERB|rest|it|Come dice il proverbio, chi va piano va sano e va lontano.
ACT.vivid|change|zh|{O}，不知不覺間，好多事情都和從前不一樣了。
ACT.vivid|change|zh|{O}。改變來得那麼安靜，等我發現時，已經走了很遠。
ACT.vivid|change|en|{O}, and without anyone noticing, so many things are no longer the same.
ACT.vivid|change|en|{O}. The change came so quietly that by the time I noticed, it had already gone a long way.
ACT.vivid|change|es|{O}, y sin que nadie se diera cuenta, muchas cosas ya no son iguales.
ACT.vivid|change|es|{O}. El cambio llegó tan en silencio que, cuando me di cuenta, ya había recorrido mucho camino.
ACT.vivid|change|it|{O}, e senza che nessuno se ne accorgesse, tante cose non sono più le stesse.
ACT.vivid|change|it|{O}. Il cambiamento è arrivato così in silenzio che, quando me ne sono accorto, aveva già fatto tanta strada.
ACT.simile|change|zh|時光像一位沉默的畫家，一筆一筆地改寫著世界的模樣。
ACT.simile|change|zh|那些改變宛如四季的更替，悄無聲息，卻從不停歇。
ACT.simile|change|en|Time is like a silent painter, changing the face of the world one brushstroke at a time.
ACT.simile|change|en|These changes are like the turning of the seasons, soundless and never-ending.
ACT.simile|change|es|El tiempo es como un pintor callado que cambia la cara del mundo pincelada a pincelada.
ACT.simile|change|es|Estos cambios son como el paso de las estaciones, silenciosos e incesantes.
ACT.simile|change|it|Il tempo è come un pittore silenzioso che cambia il volto del mondo una pennellata alla volta.
ACT.simile|change|it|Questi cambiamenti sono come il passare delle stagioni, silenziosi e senza fine.
ACT.feel|change|zh|我的心裡五味雜陳，有不捨，也有一點點期待。
ACT.feel|change|zh|一股說不出的感慨湧上心頭，讓人忍不住回頭張望。
ACT.feel|change|en|My heart is full of mixed feelings: a little sorrow, and a little hope.
ACT.feel|change|en|A feeling I cannot name rises in my chest, and I can't help looking back.
ACT.feel|change|es|Mi corazón está lleno de sentimientos encontrados: un poco de tristeza y un poco de esperanza.
ACT.feel|change|es|Un sentimiento que no sé nombrar me sube al pecho, y no puedo evitar mirar atrás.
ACT.feel|change|it|Il mio cuore è pieno di sentimenti contrastanti: un po' di malinconia e un po' di speranza.
ACT.feel|change|it|Un sentimento che non so nominare mi sale nel petto, e non riesco a non voltarmi indietro.
ACT.view|change|zh|我想，改變並不可怕，可怕的是害怕改變而停在原地。
ACT.view|change|zh|在我看來，唯一不變的，就是一切都在變；學會擁抱它，人生才會更寬闊。
ACT.view|change|en|I think change is not frightening; what is frightening is standing still because we fear it.
ACT.view|change|en|To me, the only thing that never changes is change itself, and learning to embrace it makes life wider.
ACT.view|change|es|Pienso que el cambio no da miedo; lo que da miedo es quedarse quieto por temor a cambiar.
ACT.view|change|es|Para mí, lo único que no cambia es el cambio mismo, y aprender a abrazarlo hace la vida más amplia.
ACT.view|change|it|Penso che il cambiamento non faccia paura; fa paura restare fermi per timore di cambiare.
ACT.view|change|it|Per me, l'unica cosa che non cambia è il cambiamento stesso, e imparare ad accoglierlo rende la vita più ampia.
ACT.end|change|zh|我深吸一口氣，帶著回憶，也帶著勇氣，繼續往前走。
ACT.end|change|zh|明天會是什麼樣子呢？我微微一笑，決定好好地去迎接它。
ACT.end|change|en|I take a deep breath and walk on, carrying both my memories and my courage.
ACT.end|change|en|What will tomorrow look like? I smile a little and decide to welcome it with open arms.
ACT.end|change|es|Respiro hondo y sigo adelante, llevando conmigo los recuerdos y el valor.
ACT.end|change|es|¿Cómo será el mañana? Sonrío un poco y decido recibirlo con los brazos abiertos.
ACT.end|change|it|Faccio un respiro profondo e vado avanti, portando con me i ricordi e il coraggio.
ACT.end|change|it|Come sarà il domani? Sorrido un po' e decido di accoglierlo a braccia aperte.
IDIOM|change|zh|日新月異,與時俱進,推陳出新
PROVERB|change|en|As they say, the only constant in life is change.
PROVERB|change|es|Como dice el refrán, renovarse o morir.
PROVERB|change|it|Come dice il proverbio, chi si ferma è perduto.
ACT.vivid|general|zh|「{O}」——這句話看似簡單，卻藏著一整個世界。
ACT.vivid|general|zh|{O}。短短的一句，卻讓我想了很久很久。
ACT.vivid|general|en|{O}. It is such a simple sentence, and yet a whole world is hidden inside it.
ACT.vivid|general|en|{O}. Just a few words, but they stay with me for a long time.
ACT.vivid|general|es|{O}. Es una frase muy sencilla, y sin embargo esconde un mundo entero.
ACT.vivid|general|es|{O}. Solo unas pocas palabras, pero se quedan conmigo mucho tiempo.
ACT.vivid|general|it|{O}. È una frase così semplice, eppure nasconde un mondo intero.
ACT.vivid|general|it|{O}. Solo poche parole, ma restano con me a lungo.
ACT.simile|general|zh|那感覺像一顆小石子落進湖裡，泛起一圈又一圈的漣漪。
ACT.simile|general|zh|它宛如一扇半開的窗，讓人忍不住想看看外面的風景。
ACT.simile|general|en|It feels like a pebble dropped into a lake, sending out ripple after ripple.
ACT.simile|general|en|It is like a half-open window that makes you want to look at the view outside.
ACT.simile|general|es|Es como una piedrecita que cae en un lago y deja ondas una tras otra.
ACT.simile|general|es|Es como una ventana entreabierta que invita a mirar el paisaje de fuera.
ACT.simile|general|it|È come un sassolino caduto in un lago, che lascia cerchi uno dopo l'altro.
ACT.simile|general|it|È come una finestra socchiusa che invita a guardare il paesaggio fuori.
ACT.feel|general|zh|我的心裡湧起一股說不出的感動，暖暖的，又帶著一點點惆悵。
ACT.feel|general|zh|那份心情輕輕地落在心頭，久久不散。
ACT.feel|general|en|A feeling I cannot name rises in my heart, warm and a little wistful.
ACT.feel|general|en|The emotion settles softly on my heart and does not leave for a long time.
ACT.feel|general|es|Una emoción que no sé nombrar me sube al corazón, cálida y un poco nostálgica.
ACT.feel|general|es|Ese sentimiento se posa suave en mi corazón y tarda mucho en irse.
ACT.feel|general|it|Un'emozione che non so nominare mi sale al cuore, calda e un po' malinconica.
ACT.feel|general|it|Quel sentimento si posa piano sul mio cuore e non se ne va per molto tempo.
ACT.view|general|zh|我想，生活裡最珍貴的，往往就是這些看似平凡的片刻。
ACT.view|general|zh|我相信，只要用心去看，每一件小事都有它的意義。
ACT.view|general|en|I think the most precious things in life are often these ordinary-looking moments.
ACT.view|general|en|I believe that if we look with our hearts, every small thing has its own meaning.
ACT.view|general|es|Pienso que lo más valioso de la vida suelen ser estos momentos que parecen corrientes.
ACT.view|general|es|Creo que si miramos con el corazón, cada cosa pequeña tiene su sentido.
ACT.view|general|it|Penso che le cose più preziose della vita siano spesso questi momenti che sembrano ordinari.
ACT.view|general|it|Credo che se guardiamo con il cuore, ogni piccola cosa abbia il suo significato.
ACT.end|general|zh|我把這一刻輕輕收進心裡，帶著它，繼續往前走。
ACT.end|general|zh|風輕輕吹過，一切都溫柔得剛剛好。
ACT.end|general|en|I tuck this moment gently into my heart and carry it with me as I walk on.
ACT.end|general|en|A soft wind passes by, and everything is gentle and just right.
ACT.end|general|es|Guardo este momento con cuidado en mi corazón y me lo llevo conmigo.
ACT.end|general|es|Pasa un viento suave, y todo es tierno y justo como debe ser.
ACT.end|general|it|Ripongo questo momento con cura nel mio cuore e lo porto con me.
ACT.end|general|it|Passa un vento leggero, e tutto è dolce e giusto così.
IDIOM|general|zh|一心一意,無憂無慮,心平氣和
PROVERB|general|en|As the old saying goes, little things make a big difference.
PROVERB|general|es|Como dice el refrán, las pequeñas cosas hacen la diferencia.
PROVERB|general|it|Come dice il proverbio, sono le piccole cose a fare la differenza.
EXTRA|-|zh|生活裡總有這樣的瞬間，平凡得幾乎讓人忽略，卻又美好得讓人心頭一顫。
EXTRA|-|zh|我常常覺得，世界對我們說話的方式，就是這些安靜的小事。
EXTRA|-|zh|如果我們願意放慢腳步，就會發現身邊處處都藏著感動。
EXTRA|-|zh|這份感受說不清楚，卻真實地留在了心裡。
EXTRA|-|zh|多年以後，我也許會忘記很多事，卻一定會記得這一刻。
EXTRA|-|zh|原來，最動人的風景，從來都不在遠方，而在眼前。
EXTRA|-|en|Life is full of moments like this, so ordinary that we almost miss them, and yet so beautiful that they make the heart tremble.
EXTRA|-|en|I often feel that this is how the world speaks to us: through small, quiet things.
EXTRA|-|en|If we are willing to slow down, we will find something moving hidden everywhere around us.
EXTRA|-|en|The feeling is hard to put into words, but it stays in my heart all the same.
EXTRA|-|en|Years from now I may forget many things, but I am sure I will remember this moment.
EXTRA|-|en|It turns out that the most moving view is never far away; it is right in front of us.
EXTRA|-|es|La vida está llena de momentos así, tan corrientes que casi los pasamos por alto, y tan hermosos que hacen temblar el corazón.
EXTRA|-|es|A menudo siento que así nos habla el mundo: a través de cosas pequeñas y silenciosas.
EXTRA|-|es|Si nos atrevemos a ir más despacio, descubriremos emociones escondidas por todas partes.
EXTRA|-|es|Es difícil poner este sentimiento en palabras, pero se queda en mi corazón.
EXTRA|-|es|Dentro de muchos años quizás olvide muchas cosas, pero estoy seguro de que recordaré este momento.
EXTRA|-|es|Resulta que el paisaje más conmovedor nunca está lejos; está justo delante de nosotros.
EXTRA|-|it|La vita è piena di momenti così, tanto ordinari che quasi non li vediamo, e tanto belli da far tremare il cuore.
EXTRA|-|it|Spesso sento che è così che il mondo ci parla: attraverso cose piccole e silenziose.
EXTRA|-|it|Se abbiamo il coraggio di rallentare, scopriremo emozioni nascoste ovunque intorno a noi.
EXTRA|-|it|È difficile mettere questa sensazione in parole, ma resta nel mio cuore.
EXTRA|-|it|Tra molti anni forse dimenticherò tante cose, ma sono sicuro che ricorderò questo momento.
EXTRA|-|it|In fondo, il paesaggio più commovente non è mai lontano; è proprio davanti a noi.
MARK.emotion|-|zh|感動¦溫暖¦暖暖¦心裡¦心頭¦心底¦我的心¦心中¦欣慰¦惆悵¦不捨¦憂傷¦安心¦雀躍¦暢快¦感慨¦溫柔¦悸動¦喜悅¦幸福¦思念¦寧靜¦疲憊¦委屈¦害怕¦恐懼¦緊張¦憤怒¦快樂¦難過¦傷心¦孤單¦寂寞¦驕傲¦期待¦心疼¦滿足¦酸楚¦感受¦滋味¦怒火¦怒氣¦喜歡¦勇氣¦熱血¦痛快¦柔軟¦憂愁¦羞澀¦懊悔¦悔恨¦心¦淚¦笑¦怕¦累¦暖¦感覺¦嘆息¦放鬆¦自在¦想念¦好奇¦興奮¦失落¦平靜¦安詳¦感恩
MARK.emotion|-|en|heart¦tenderness¦tender¦joy¦sorrow¦sadness¦peace¦wistful¦warm¦emotion¦feeling¦happy¦love¦chest¦longing¦hope¦wonder¦gratitude¦calm¦fear¦lonely¦proud¦delight¦ache¦smil¦comfort¦soul¦freedom¦tired¦gentle¦moved¦touched¦tears¦laugh¦afraid¦glad¦quiet¦courage¦memor
MARK.emotion|-|es|corazón¦ternura¦alegría¦tristeza¦nostalgia¦paz¦emoción¦melancolía¦esperanza¦amor¦pecho¦calma¦miedo¦orgullo¦sonre¦alma¦consuelo¦felicidad¦sentimiento¦cansancio¦libertad¦lágrima¦reír¦valor¦recuerd¦suave¦tierno¦silencio
MARK.emotion|-|it|cuore¦tenerezza¦gioia¦tristezza¦malinconia¦pace¦emozione¦speranza¦amore¦petto¦calma¦paura¦orgoglio¦sorrid¦anima¦conforto¦felicità¦sentimento¦commuove¦stanchezza¦libertà¦lacrim¦ridere¦coraggio¦ricord¦dolce¦silenzio
MARK.view|-|zh|我想¦我相信¦我始終相信¦我覺得¦在我看來¦或許¦原來
MARK.view|-|en|I believe¦I think¦To me¦Perhaps¦It turns out
MARK.view|-|es|Creo que¦Pienso que¦Para mí¦Quizás¦Resulta que
MARK.view|-|it|Credo che¦Penso che¦Per me¦Forse¦In fondo
MARK.simile|-|zh|彷彿¦宛如¦像¦猶如¦如同
MARK.simile|-|en| like ¦as if¦as though
MARK.simile|-|es| como ¦cual
MARK.simile|-|it| come ¦quasi
"""
}
