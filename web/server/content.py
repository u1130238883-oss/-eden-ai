# -*- coding: utf-8 -*-
"""把引擎算出來的數字，變成畫面上要顯示的文字。

四種語言：zh（繁體中文）、en、es、it。
"""
import engine as E
import enneagram_data as ED
import palace_data as PD

LANGS = ("zh", "en", "es", "it")
DEFAULT_LANG = "zh"

ZH_DIGITS = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]


def norm_lang(lang):
    return lang if lang in LANGS else DEFAULT_LANG


def pick(d, lang):
    """從 {'zh':..,'en':..} 取值，西／義缺的時候退回英文。"""
    return d.get(lang) or d.get("en") or d.get("zh")


# ── 宮位 ────────────────────────────────────────────────────────────


def palace_label(n, lang):
    n = E.r12(n)
    return {"zh": "%d宮" % n, "en": "Palace %d" % n,
            "es": "Palacio %d" % n, "it": "Palazzo %d" % n}[lang]


def palace_short(n, lang):
    return PD.SHORT[lang][E.r12(n) - 1]


def palace_named(n, lang):
    sep = "・" if lang == "zh" else " · "
    return palace_label(n, lang) + sep + palace_short(n, lang)


def palace_keywords(n, lang):
    return PD.KEYWORDS[lang][E.r12(n) - 1]


def palace_brief(n, lang, limit=4):
    """摘要都是接在宮位簡稱底下顯示的，跳過和簡稱一樣的那一個，
    不然標題與第一個關鍵字會重複；跳過後往後遞補，仍取四個。"""
    sep = "、" if lang == "zh" else ", "
    name = palace_short(n, lang)
    return sep.join([k for k in palace_keywords(n, lang) if k != name][:limit])


def palace_text(n, lang):
    sep = "、" if lang == "zh" else ", "
    return sep.join(palace_keywords(n, lang))


# ── 判讀 ────────────────────────────────────────────────────────────


def reading_text(reading, lang):
    kind, effect, cause = reading
    if lang == "zh":
        return "%s%d因%d" % (kind, effect, cause)
    return "%s %d %s %d" % (E.VERDICT_NAME[kind][lang], effect,
                            E.CAUSE_WORD[lang], cause)


def row_json(row, lang):
    """一列盤：宮位、三柱、判讀，全部連同要顯示的文字一起送出去。"""
    kind, effect, cause = row["reading"]
    t = row["triple"]
    return {
        "palace": row["palace"],
        "palaceLabel": palace_label(row["palace"], lang),
        "palaceShort": palace_short(row["palace"], lang),
        "element": E.ELEM_NAME[E.ELEM[row["palace"]]][lang],
        "triple": t,
        "tripleText": ("%d；%d；%d" % tuple(t)) if lang == "zh"
                      else ("%d / %d / %d" % tuple(t)),
        "verdict": kind,
        "verdictText": E.VERDICT_NAME[kind][lang],
        "effect": effect,
        "cause": cause,
        "readingText": reading_text(row["reading"], lang),
        "brief": palace_brief(row["palace"], lang),
        "keywords": palace_keywords(row["palace"], lang),
    }


# ── 九型人格 ────────────────────────────────────────────────────────


def enneagram_label(n, lang):
    n = E.r9(n)
    return {"zh": "第%s型" % ZH_DIGITS[n - 1], "en": "Type %d" % n,
            "es": "Tipo %d" % n, "it": "Tipo %d" % n}[lang]


def enneagram_json(life_number, lang, full=False):
    n = E.r9(life_number)
    t = ED.TYPES[n - 1]
    out = {
        "type": n,
        "label": enneagram_label(n, lang),
        "name": pick(t["name"], lang),
        "tagline": pick(t["tagline"], lang),
        "color": "#" + ED.COLORS[n],
    }
    if full:
        out["summary"] = pick(t["summary"], lang)
        out["sections"] = [
            {"title": pick(ED.SECTION_TITLES[i], lang),
             "lines": t["sections"][i][lang] or t["sections"][i]["en"]}
            for i in range(len(ED.SECTION_TITLES))
        ]
    return out


# ── 介面字串 ────────────────────────────────────────────────────────

UI = {
    "appName":   {"zh": "九型十二宮", "en": "Nine & Twelve",
                  "es": "Nueve y Doce", "it": "Nove e Dodici"},
    "today":     {"zh": "今日", "en": "Today", "es": "Hoy", "it": "Oggi"},
    "chart":     {"zh": "命盤", "en": "Chart", "es": "Carta", "it": "Carta"},
    "fortune":   {"zh": "運程", "en": "Fortune", "es": "Destino", "it": "Sorte"},
    "synastry":  {"zh": "合盤", "en": "Synastry", "es": "Sinastría", "it": "Sinastria"},
    "member":    {"zh": "會員", "en": "Membership", "es": "Membresía", "it": "Abbonamento"},
    "lifeNumber": {"zh": "靈數", "en": "Life Number",
                   "es": "Número de Vida", "it": "Numero di Vita"},
    "lifePalace": {"zh": "命宮", "en": "Life Palace",
                   "es": "Palacio de Vida", "it": "Palazzo della Vita"},
    "pillars":   {"zh": "本命三柱", "en": "The three pillars",
                  "es": "Los tres pilares", "it": "I tre pilastri"},
    "year":      {"zh": "年", "en": "Year", "es": "Año", "it": "Anno"},
    "month":     {"zh": "月", "en": "Month", "es": "Mes", "it": "Mese"},
    "day":       {"zh": "日", "en": "Day", "es": "Día", "it": "Giorno"},
    "daytime":   {"zh": "白天", "en": "Daytime", "es": "De día", "it": "Di giorno"},
    "night":     {"zh": "晚上", "en": "Night", "es": "De noche", "it": "Di notte"},
    "twelve":    {"zh": "十二宮盤", "en": "The twelve palaces",
                  "es": "Los doce palacios", "it": "I dodici palazzi"},
    "enneagram": {"zh": "九型人格", "en": "Enneagram",
                  "es": "Eneagrama", "it": "Enneagramma"},
    "annual":    {"zh": "流年", "en": "Annual", "es": "Anual", "it": "Annuale"},
    "luck":      {"zh": "大運", "en": "Major cycles",
                  "es": "Ciclos mayores", "it": "Cicli maggiori"},
    "monthly":   {"zh": "月運", "en": "Monthly", "es": "Mensual", "it": "Mensile"},
    "locked":    {"zh": "這一頁需要會員", "en": "This page needs a membership",
                  "es": "Esta página requiere membresía",
                  "it": "Questa pagina richiede l'abbonamento"},
}


def ui(lang):
    return {k: pick(v, lang) for k, v in UI.items()}


# ── 錯誤訊息 ────────────────────────────────────────────────────────
#
# 客人看得到的訊息一律四種語言都要有，不能只寫中文。

ERRORS = {
    "badNumber": {
        "zh": "日期要填數字",
        "en": "The date must be numbers",
        "es": "La fecha debe ser numérica",
        "it": "La data deve essere numerica"},
    "incompleteDate": {
        "zh": "日期沒有填完整",
        "en": "The date is incomplete",
        "es": "La fecha está incompleta",
        "it": "La data è incompleta"},
    "badFormat": {
        "zh": "格式不對",
        "en": "Malformed request",
        "es": "Formato incorrecto",
        "it": "Formato non valido"},
    "tooLarge": {
        "zh": "資料太大",
        "en": "Request too large",
        "es": "Solicitud demasiado grande",
        "it": "Richiesta troppo grande"},
    "notFound": {
        "zh": "找不到這個位址",
        "en": "Not found",
        "es": "No encontrado",
        "it": "Non trovato"},
    "serverBusy": {
        "zh": "伺服器忙不過來，請稍後再試",
        "en": "The server is busy, please try again shortly",
        "es": "El servidor está ocupado, inténtalo de nuevo",
        "it": "Il server è occupato, riprova tra poco"},
    "noSuchPlan": {
        "zh": "方案不存在",
        "en": "No such plan",
        "es": "Ese plan no existe",
        "it": "Piano inesistente"},
    "noSuchOrder": {
        "zh": "查無此訂單",
        "en": "No such payment reference",
        "es": "No existe esa referencia de pago",
        "it": "Riferimento di pagamento inesistente"},
    "orderDone": {
        "zh": "這筆已經確認過了",
        "en": "This one was already confirmed",
        "es": "Este ya fue confirmado",
        "it": "Questo è già stato confermato"},
    "badCode": {
        "zh": "啟用碼不正確",
        "en": "That activation code is not valid",
        "es": "Ese código de activación no es válido",
        "it": "Codice di attivazione non valido"},
    "codeUsed": {
        "zh": "這個啟用碼已經用過了",
        "en": "That activation code has already been used",
        "es": "Ese código de activación ya se ha usado",
        "it": "Questo codice di attivazione è già stato usato"},
    "badKey": {
        "zh": "憑證不正確",
        "en": "That member key is not valid",
        "es": "Esa clave de miembro no es válida",
        "it": "Chiave non valida"},
    # 後台只有店主會看到，維持中文
    "adminNoPassword": {"zh": "後台沒有設密碼，請先設定 NT_ADMIN_PASSWORD"},
    "adminBadPassword": {"zh": "密碼不對"},
    "adminLogin": {"zh": "請先登入"},
}


def err(key, lang=DEFAULT_LANG):
    """把錯誤代號翻成該語言的句子。"""
    return pick(ERRORS.get(key, {"zh": key}), lang) or key


def month_name(m, lang):
    m = max(1, min(12, m))
    if lang == "zh":
        return "%d月" % m
    return {
        "en": ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        "es": ["ene", "feb", "mar", "abr", "may", "jun",
               "jul", "ago", "sep", "oct", "nov", "dic"],
        "it": ["gen", "feb", "mar", "apr", "mag", "giu",
               "lug", "ago", "set", "ott", "nov", "dic"],
    }[lang][m - 1]
