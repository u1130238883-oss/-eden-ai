# -*- coding: utf-8 -*-
"""做短語、句子用的名詞、形容詞、動詞變化（四語），西班牙文、義大利文的陰陽性、複數、冠詞都寫好。

名詞一行：中文|量詞|English|English 複數|a/an|分類|Español|複數|陰陽|Italiano|複數|冠詞（il/lo/l'm/l'f/la）
分類：obj 物品、food 食物、animal 動物、person 人、vehicle 交通工具、cloth 衣物、place 地方、nature 自然
"""

NOUN_DATA = """
書|本|book|books|a|obj|libro|libros|m|libro|libri|il
筆|枝|pen|pens|a|obj|bolígrafo|bolígrafos|m|penna|penne|la
鉛筆|枝|pencil|pencils|a|obj|lápiz|lápices|m|matita|matite|la
桌子|張|table|tables|a|obj|mesa|mesas|f|tavolo|tavoli|il
椅子|把|chair|chairs|a|obj|silla|sillas|f|sedia|sedie|la
床|張|bed|beds|a|obj|cama|camas|f|letto|letti|il
門|扇|door|doors|a|obj|puerta|puertas|f|porta|porte|la
窗戶|扇|window|windows|a|obj|ventana|ventanas|f|finestra|finestre|la
鑰匙|把|key|keys|a|obj|llave|llaves|f|chiave|chiavi|la
雨傘|把|umbrella|umbrellas|an|obj|paraguas|paraguas|m|ombrello|ombrelli|l'm
手機|支|phone|phones|a|obj|teléfono|teléfonos|m|telefono|telefoni|il
電腦|台|computer|computers|a|obj|computadora|computadoras|f|computer|computer|il
相機|台|camera|cameras|a|obj|cámara|cámaras|f|fotocamera|fotocamere|la
手錶|支|watch|watches|a|obj|reloj|relojes|m|orologio|orologi|l'm
包包|個|bag|bags|a|obj|bolso|bolsos|m|borsa|borse|la
背包|個|backpack|backpacks|a|obj|mochila|mochilas|f|zaino|zaini|lo
行李箱|個|suitcase|suitcases|a|obj|maleta|maletas|f|valigia|valigie|la
箱子|個|box|boxes|a|obj|caja|cajas|f|scatola|scatole|la
杯子|個|cup|cups|a|obj|taza|tazas|f|tazza|tazze|la
盤子|個|plate|plates|a|obj|plato|platos|m|piatto|piatti|il
瓶子|個|bottle|bottles|a|obj|botella|botellas|f|bottiglia|bottiglie|la
鏡子|面|mirror|mirrors|a|obj|espejo|espejos|m|specchio|specchi|lo
燈|盞|lamp|lamps|a|obj|lámpara|lámparas|f|lampada|lampade|la
時鐘|個|clock|clocks|a|obj|reloj|relojes|m|orologio|orologi|l'm
枕頭|個|pillow|pillows|a|obj|almohada|almohadas|f|cuscino|cuscini|il
毛巾|條|towel|towels|a|obj|toalla|toallas|f|asciugamano|asciugamani|l'm
地圖|張|map|maps|a|obj|mapa|mapas|m|mappa|mappe|la
照片|張|photo|photos|a|obj|foto|fotos|f|foto|foto|la
信|封|letter|letters|a|obj|carta|cartas|f|lettera|lettere|la
票|張|ticket|tickets|a|obj|boleto|boletos|m|biglietto|biglietti|il
報紙|份|newspaper|newspapers|a|obj|periódico|periódicos|m|giornale|giornali|il
雜誌|本|magazine|magazines|a|obj|revista|revistas|f|rivista|riviste|la
筆記本|本|notebook|notebooks|a|obj|cuaderno|cuadernos|m|quaderno|quaderni|il
禮物|份|gift|gifts|a|obj|regalo|regalos|m|regalo|regali|il
玩具|個|toy|toys|a|obj|juguete|juguetes|m|giocattolo|giocattoli|il
球|顆|ball|balls|a|obj|pelota|pelotas|f|palla|palle|la
吉他|把|guitar|guitars|a|obj|guitarra|guitarras|f|chitarra|chitarre|la
鋼琴|台|piano|pianos|a|obj|piano|pianos|m|pianoforte|pianoforti|il
沙發|張|sofa|sofas|a|obj|sofá|sofás|m|divano|divani|il
冰箱|台|fridge|fridges|a|obj|nevera|neveras|f|frigorifero|frigoriferi|il
電視|台|television|televisions|a|obj|televisor|televisores|m|televisore|televisori|il
刀子|把|knife|knives|a|obj|cuchillo|cuchillos|m|coltello|coltelli|il
叉子|支|fork|forks|a|obj|tenedor|tenedores|m|forchetta|forchette|la
湯匙|支|spoon|spoons|a|obj|cuchara|cucharas|f|cucchiaio|cucchiai|il
碗|個|bowl|bowls|a|obj|cuenco|cuencos|m|ciotola|ciotole|la
錢包|個|wallet|wallets|a|obj|cartera|carteras|f|portafoglio|portafogli|il
眼鏡|副|pair of glasses|pairs of glasses|a|obj|gafas|gafas|f|occhiali|occhiali|gli
蘋果|顆|apple|apples|an|food|manzana|manzanas|f|mela|mele|la
香蕉|根|banana|bananas|a|food|plátano|plátanos|m|banana|banane|la
柳橙|顆|orange|oranges|an|food|naranja|naranjas|f|arancia|arance|l'f
檸檬|顆|lemon|lemons|a|food|limón|limones|m|limone|limoni|il
番茄|顆|tomato|tomatoes|a|food|tomate|tomates|m|pomodoro|pomodori|il
馬鈴薯|顆|potato|potatoes|a|food|patata|patatas|f|patata|patate|la
蛋|顆|egg|eggs|an|food|huevo|huevos|m|uovo|uova|l'm
蛋糕|塊|cake|cakes|a|food|pastel|pasteles|m|torta|torte|la
三明治|個|sandwich|sandwiches|a|food|sándwich|sándwiches|m|panino|panini|il
披薩|個|pizza|pizzas|a|food|pizza|pizzas|f|pizza|pizze|la
漢堡|個|hamburger|hamburgers|a|food|hamburguesa|hamburguesas|f|hamburger|hamburger|l'm
餅乾|塊|cookie|cookies|a|food|galleta|galletas|f|biscotto|biscotti|il
麵包|個|bread roll|bread rolls|a|food|panecillo|panecillos|m|panino|panini|il
冰淇淋|球|ice cream|ice creams|an|food|helado|helados|m|gelato|gelati|il
咖啡|杯|coffee|coffees|a|food|café|cafés|m|caffè|caffè|il
茶|杯|tea|teas|a|food|té|tés|m|tè|tè|il
啤酒|杯|beer|beers|a|food|cerveza|cervezas|f|birra|birre|la
果汁|杯|juice|juices|a|food|zumo|zumos|m|succo|succhi|il
西瓜|顆|watermelon|watermelons|a|food|sandía|sandías|f|anguria|angurie|l'f
草莓|顆|strawberry|strawberries|a|food|fresa|fresas|f|fragola|fragole|la
狗|隻|dog|dogs|a|animal|perro|perros|m|cane|cani|il
貓|隻|cat|cats|a|animal|gato|gatos|m|gatto|gatti|il
鳥|隻|bird|birds|a|animal|pájaro|pájaros|m|uccello|uccelli|l'm
魚|條|fish|fish|a|animal|pez|peces|m|pesce|pesci|il
馬|匹|horse|horses|a|animal|caballo|caballos|m|cavallo|cavalli|il
兔子|隻|rabbit|rabbits|a|animal|conejo|conejos|m|coniglio|conigli|il
熊|隻|bear|bears|a|animal|oso|osos|m|orso|orsi|l'm
老虎|隻|tiger|tigers|a|animal|tigre|tigres|m|tigre|tigri|la
大象|頭|elephant|elephants|an|animal|elefante|elefantes|m|elefante|elefanti|l'm
猴子|隻|monkey|monkeys|a|animal|mono|monos|m|scimmia|scimmie|la
牛|頭|cow|cows|a|animal|vaca|vacas|f|mucca|mucche|la
羊|隻|sheep|sheep|a|animal|oveja|ovejas|f|pecora|pecore|la
雞|隻|chicken|chickens|a|animal|gallina|gallinas|f|gallina|galline|la
鴨子|隻|duck|ducks|a|animal|pato|patos|m|anatra|anatre|l'f
蝴蝶|隻|butterfly|butterflies|a|animal|mariposa|mariposas|f|farfalla|farfalle|la
烏龜|隻|turtle|turtles|a|animal|tortuga|tortugas|f|tartaruga|tartarughe|la
朋友|位|friend|friends|a|person|amigo|amigos|m|amico|amici|l'm
老師|位|teacher|teachers|a|person|profesor|profesores|m|insegnante|insegnanti|l'm
醫生|位|doctor|doctors|a|person|médico|médicos|m|medico|medici|il
學生|個|student|students|a|person|estudiante|estudiantes|m|studente|studenti|lo
孩子|個|child|children|a|person|niño|niños|m|bambino|bambini|il
女孩|個|girl|girls|a|person|chica|chicas|f|ragazza|ragazze|la
男孩|個|boy|boys|a|person|chico|chicos|m|ragazzo|ragazzi|il
鄰居|位|neighbor|neighbors|a|person|vecino|vecinos|m|vicino|vicini|il
廚師|位|cook|cooks|a|person|cocinero|cocineros|m|cuoco|cuochi|il
司機|位|driver|drivers|a|person|conductor|conductores|m|autista|autisti|l'm
車|輛|car|cars|a|vehicle|coche|coches|m|macchina|macchine|la
腳踏車|輛|bicycle|bicycles|a|vehicle|bicicleta|bicicletas|f|bicicletta|biciclette|la
公車|輛|bus|buses|a|vehicle|autobús|autobuses|m|autobus|autobus|l'm
火車|列|train|trains|a|vehicle|tren|trenes|m|treno|treni|il
飛機|架|plane|planes|a|vehicle|avión|aviones|m|aereo|aerei|l'm
船|艘|boat|boats|a|vehicle|barco|barcos|m|barca|barche|la
機車|輛|motorcycle|motorcycles|a|vehicle|moto|motos|f|moto|moto|la
計程車|輛|taxi|taxis|a|vehicle|taxi|taxis|m|taxi|taxi|il
襯衫|件|shirt|shirts|a|cloth|camisa|camisas|f|camicia|camicie|la
外套|件|coat|coats|a|cloth|abrigo|abrigos|m|cappotto|cappotti|il
裙子|條|skirt|skirts|a|cloth|falda|faldas|f|gonna|gonne|la
帽子|頂|hat|hats|a|cloth|sombrero|sombreros|m|cappello|cappelli|il
洋裝|件|dress|dresses|a|cloth|vestido|vestidos|m|vestito|vestiti|il
毛衣|件|sweater|sweaters|a|cloth|suéter|suéteres|m|maglione|maglioni|il
圍巾|條|scarf|scarves|a|cloth|bufanda|bufandas|f|sciarpa|sciarpe|la
領帶|條|tie|ties|a|cloth|corbata|corbatas|f|cravatta|cravatte|la
房子|間|house|houses|a|place|casa|casas|f|casa|case|la
房間|間|room|rooms|a|place|habitación|habitaciones|f|stanza|stanze|la
餐廳|家|restaurant|restaurants|a|place|restaurante|restaurantes|m|ristorante|ristoranti|il
商店|家|shop|shops|a|place|tienda|tiendas|f|negozio|negozi|il
飯店|家|hotel|hotels|a|place|hotel|hoteles|m|albergo|alberghi|l'm
學校|所|school|schools|a|place|escuela|escuelas|f|scuola|scuole|la
公園|座|park|parks|a|place|parque|parques|m|parco|parchi|il
醫院|家|hospital|hospitals|a|place|hospital|hospitales|m|ospedale|ospedali|l'm
銀行|家|bank|banks|a|place|banco|bancos|m|banca|banche|la
博物館|座|museum|museums|a|place|museo|museos|m|museo|musei|il
教堂|座|church|churches|a|place|iglesia|iglesias|f|chiesa|chiese|la
圖書館|座|library|libraries|a|place|biblioteca|bibliotecas|f|biblioteca|biblioteche|la
花園|座|garden|gardens|a|place|jardín|jardines|m|giardino|giardini|il
橋|座|bridge|bridges|a|place|puente|puentes|m|ponte|ponti|il
樹|棵|tree|trees|a|nature|árbol|árboles|m|albero|alberi|l'm
花|朵|flower|flowers|a|nature|flor|flores|f|fiore|fiori|il
山|座|mountain|mountains|a|nature|montaña|montañas|f|montagna|montagne|la
河|條|river|rivers|a|nature|río|ríos|m|fiume|fiumi|il
湖|座|lake|lakes|a|nature|lago|lagos|m|lago|laghi|il
島|座|island|islands|an|nature|isla|islas|f|isola|isole|l'f
星星|顆|star|stars|a|nature|estrella|estrellas|f|stella|stelle|la
石頭|顆|stone|stones|a|nature|piedra|piedras|f|pietra|pietre|la
"""

# 形容詞：中文|English|es 陽性單數|es 陰性單數|it 陽性單數|it 陰性單數|適用分類（逗號）
ADJ_DATA = """
紅色|red|rojo|roja|rosso|rossa|obj,cloth,vehicle,food,nature
藍色|blue|azul|azul|blu|blu|obj,cloth,vehicle
綠色|green|verde|verde|verde|verde|obj,cloth,vehicle,food
黃色|yellow|amarillo|amarilla|giallo|gialla|obj,cloth,vehicle,food,nature
黑色|black|negro|negra|nero|nera|obj,cloth,vehicle,animal
白色|white|blanco|blanca|bianco|bianca|obj,cloth,vehicle,animal,nature
灰色|gray|gris|gris|grigio|grigia|obj,cloth,vehicle,animal
大|big|grande|grande|grande|grande|obj,cloth,vehicle,food,animal,place,nature
小|small|pequeño|pequeña|piccolo|piccola|obj,cloth,vehicle,food,animal,place,nature
新|new|nuevo|nueva|nuovo|nuova|obj,cloth,vehicle,place
舊|old|viejo|vieja|vecchio|vecchia|obj,cloth,vehicle,place
貴|expensive|caro|cara|caro|cara|obj,cloth,vehicle,food,place
便宜|cheap|barato|barata|economico|economica|obj,cloth,vehicle,food,place
乾淨|clean|limpio|limpia|pulito|pulita|obj,cloth,vehicle,place
髒|dirty|sucio|sucia|sporco|sporca|obj,cloth,vehicle,place,animal
重|heavy|pesado|pesada|pesante|pesante|obj,vehicle
輕|light|ligero|ligera|leggero|leggera|obj,cloth
長|long|largo|larga|lungo|lunga|cloth,obj
短|short|corto|corta|corto|corta|cloth,obj
熱|hot|caliente|caliente|caldo|calda|food
冷|cold|frío|fría|freddo|fredda|food
好吃|delicious|delicioso|deliciosa|delizioso|deliziosa|food
新鮮|fresh|fresco|fresca|fresco|fresca|food
漂亮|beautiful|hermoso|hermosa|bello|bella|place,nature,cloth,obj
可愛|cute|lindo|linda|carino|carina|animal,person
快|fast|rápido|rápida|veloce|veloce|vehicle,animal
慢|slow|lento|lenta|lento|lenta|vehicle,animal
安靜|quiet|tranquilo|tranquila|tranquillo|tranquilla|place,animal,person
有名|famous|famoso|famosa|famoso|famosa|place,person,nature
壞掉的|broken|roto|rota|rotto|rotta|obj,vehicle
"""

# 動詞（主詞：我、你、他、她、我們、他們）
SUBJECTS = [("我", "I", "", "", 0), ("你", "you", "", "", 1), ("他", "he", "él ", "lui ", 2), ("她", "she", "ella ", "lei ", 2),
            ("我們", "we", "", "", 3), ("他們", "they", "ellos ", "loro ", 4)]
VERBS = {
    # 中文, en 原形, en 第三人稱單數, es[yo,tú,él,nosotros,ellos], it[io,tu,lui,noi,loro], 受詞前的介係詞（義大利文 avere bisogno di）
    "want": ("想要", "want", "wants", ["quiero", "quieres", "quiere", "queremos", "quieren"], ["voglio", "vuoi", "vuole", "vogliamo", "vogliono"], ""),
    "need": ("需要", "need", "needs", ["necesito", "necesitas", "necesita", "necesitamos", "necesitan"],
             ["ho bisogno di", "hai bisogno di", "ha bisogno di", "abbiamo bisogno di", "hanno bisogno di"], ""),
    "buy": ("買", "buy", "buys", ["compro", "compras", "compra", "compramos", "compran"], ["compro", "compri", "compra", "compriamo", "comprano"], ""),
    "have": ("有", "have", "has", ["tengo", "tienes", "tiene", "tenemos", "tienen"], ["ho", "hai", "ha", "abbiamo", "hanno"], ""),
    "see": ("看到", "see", "sees", ["veo", "ves", "ve", "vemos", "ven"], ["vedo", "vedi", "vede", "vediamo", "vedono"], ""),
}
VERB_CATS = {"want": {"obj", "food", "cloth", "vehicle", "animal"}, "need": {"obj", "food", "cloth", "vehicle"},
             "buy": {"obj", "food", "cloth", "vehicle"}, "have": {"obj", "cloth", "vehicle", "animal"},
             "see": {"obj", "animal", "vehicle", "nature", "place", "person"}}


class Noun:
    def __init__(self, line):
        f = line.split("|")
        (self.zh, self.mw, self.en, self.en_pl, self.a, self.cat, self.es, self.es_pl, self.es_g,
         self.it, self.it_pl, self.it_art) = f
        self.plural_only = self.it_art == "gli"   # 眼鏡（occhiali）、gafas

    # 西班牙文
    def es_def(self): return ("los " if self.es_g == "m" else "las ") + self.es_pl if self.plural_only else ("el " if self.es_g == "m" else "la ") + self.es
    def es_indef(self): return ("unas " + self.es_pl) if self.plural_only else ("un " if self.es_g == "m" else "una ") + self.es
    def es_this(self): return ("estas " + self.es_pl) if self.plural_only else ("este " if self.es_g == "m" else "esta ") + self.es
    def es_that(self): return ("esas " + self.es_pl) if self.plural_only else ("ese " if self.es_g == "m" else "esa ") + self.es
    def es_my(self): return "mis " + self.es_pl if self.plural_only else "mi " + self.es

    # 義大利文
    @property
    def it_g(self): return "f" if self.it_art in ("la", "l'f") else "m"
    def it_def(self):
        if self.plural_only: return "gli " + self.it_pl
        return {"il": "il ", "lo": "lo ", "l'm": "l'", "l'f": "l'", "la": "la "}[self.it_art] + self.it
    def it_def_pl(self): return {"il": "i ", "lo": "gli ", "l'm": "gli ", "l'f": "le ", "la": "le ", "gli": "gli "}[self.it_art] + self.it_pl
    def it_indef(self):
        if self.plural_only: return "degli " + self.it_pl
        return {"il": "un ", "lo": "uno ", "l'm": "un ", "l'f": "un'", "la": "una "}[self.it_art] + self.it
    def it_this(self): return ("questi " + self.it_pl) if self.plural_only else ("questo " if self.it_g == "m" else "questa ") + self.it
    def it_that(self):
        if self.plural_only: return "quegli " + self.it_pl
        return {"il": "quel ", "lo": "quello ", "l'm": "quell'", "l'f": "quell'", "la": "quella "}[self.it_art] + self.it
    def it_my(self):
        if self.plural_only: return "i miei " + self.it_pl
        return ("il mio " if self.it_g == "m" else "la mia ") + self.it

    # 英文
    def en_indef(self): return ("a " if self.a == "a" else "an ") + self.en

    def zh_one(self): return "一" + self.mw + self.zh


class Adj:
    def __init__(self, line):
        f = line.split("|")
        self.zh, self.en, self.es_m, self.es_f, self.it_m, self.it_f = f[:6]
        self.cats = set(f[6].split(","))

    def es(self, g, pl=False):
        base = self.es_m if g == "m" else self.es_f
        if not pl: return base
        if base[-1] in "aeiouáéó": return base + "s"
        if base.endswith("z"): return base[:-1] + "ces"
        return base + "es"

    def it(self, g, pl=False):
        base = self.it_m if g == "m" else self.it_f
        if not pl or base in ("blu",): return base
        if base.endswith("co") and g == "m": return base[:-1] + ("hi" if base in ("sporco", "fresco", "bianco") else "i")
        if base.endswith("ca") and g == "f": return base[:-1] + "he"
        if base.endswith("go") and g == "m": return base[:-1] + "hi"
        if base.endswith("ga") and g == "f": return base[:-1] + "he"
        if base.endswith("io"): return base[:-1]
        if base.endswith("o"): return base[:-1] + "i"
        if base.endswith("a"): return base[:-1] + "e"
        if base.endswith("e"): return base[:-1] + "i"
        return base


NOUNS = [Noun(l) for l in NOUN_DATA.strip().splitlines()]
ADJS = [Adj(l) for l in ADJ_DATA.strip().splitlines()]

if __name__ == "__main__":
    print(len(NOUNS), "nouns,", len(ADJS), "adjectives")
    for n in NOUNS[:3] + [x for x in NOUNS if x.it_art in ("lo", "l'm", "l'f", "gli")][:6]:
        print(n.zh, "|", n.es_def(), n.es_indef(), n.es_that(), "|", n.it_def(), n.it_def_pl(), n.it_indef(), n.it_that(), n.it_my())
    for a in ADJS[:5]:
        print(a.zh, a.es("m", True), a.es("f", True), a.it("m", True), a.it("f", True))
