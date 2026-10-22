#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""九型十二宮 網站。

只用 Python 內建的東西，不必安裝任何套件：

    python3 web/server/app.py

環境變數：
    PORT                  監聽的埠，預設 8000
    NT_DB                 資料庫檔位置，預設 web/data/nt.sqlite3
    NT_ADMIN_PASSWORD     後台密碼。沒設的話後台打不開。
    NT_WECHAT_NAME        收款人顯示名稱（微信），預設空白
    NT_ALIPAY_NAME        收款人顯示名稱（支付寶），預設空白

演算法在 engine.py，只在這一端跑；瀏覽器拿到的都是算好的結果。
"""
import hmac
import html
import http.cookies
import json
import mimetypes
import os
import sys
import time
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
WEB = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import content as C          # noqa: E402
import engine as E           # noqa: E402
from store import PLANS, Store   # noqa: E402

STATIC = os.path.join(WEB, "static")
DB_PATH = os.environ.get("NT_DB", os.path.join(WEB, "data", "nt.sqlite3"))
ADMIN_PASSWORD = os.environ.get("NT_ADMIN_PASSWORD", "")
COOKIE_UID = "nt_uid"
COOKIE_ADMIN = "nt_admin"
MAX_BODY = 64 * 1024

store = Store(DB_PATH)


# ── 小工具 ──────────────────────────────────────────────────────────


def admin_token():
    return hmac.new(store.secret().encode(), b"admin", sha256).hexdigest()


class BadInput(Exception):
    """訊息用代號表示，等到要回應時才照請求的語言翻出來。"""

    def __init__(self, key):
        super().__init__(key)
        self.key = key


def as_int(v, default=None):
    """送來的可能是字串、None 或別的東西，一律安全轉成整數。"""
    if v is None or v == "":
        if default is None:
            raise BadInput("incompleteDate")
        return default
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        raise BadInput("badNumber")


def guess_lang(accept_language):
    """瀏覽器說它想要哪個語言。只在還沒讀到 body 時當備案用。"""
    for part in accept_language.lower().replace(" ", "").split(","):
        code = part.split(";")[0]
        if code.startswith("zh"):
            return "zh"
        if code.startswith("es"):
            return "es"
        if code.startswith("it"):
            return "it"
        if code.startswith("en"):
            return "en"
    return C.DEFAULT_LANG


def clamp_date(y, m, d):
    """把生日限在說得通的範圍，順便擋掉亂送的東西。"""
    return (max(1, min(9999, as_int(y))),
            max(1, min(12, as_int(m))),
            max(1, min(31, as_int(d))))


class Ctx:
    """一個請求要用到的東西。"""

    def __init__(self, handler):
        self.h = handler
        self.cookies = http.cookies.SimpleCookie(handler.headers.get("Cookie", ""))
        self.set_cookies = []
        raw = self.cookies[COOKIE_UID].value if COOKIE_UID in self.cookies else None
        self.uid, is_new = store.ensure_user(raw)
        if is_new or raw != self.uid:
            self.set_cookies.append(
                "%s=%s; Path=/; Max-Age=%d; HttpOnly; SameSite=Lax"
                % (COOKIE_UID, self.uid, 3600 * 24 * 730))

    @property
    def is_member(self):
        return store.is_member(self.uid)

    @property
    def is_admin(self):
        if not ADMIN_PASSWORD:
            return False
        got = self.cookies[COOKIE_ADMIN].value if COOKIE_ADMIN in self.cookies else ""
        return hmac.compare_digest(got, admin_token())


# ── API ─────────────────────────────────────────────────────────────


def me_json(ctx):
    exp = store.expires_at(ctx.uid)
    left = max(0, exp - int(time.time()))
    return {
        "uid": ctx.uid,
        "member": exp > time.time(),
        "expiresAt": exp,
        "daysLeft": (left + 86399) // 86400,
        "plans": [{"id": k, "amount": v["amount"], "days": v["days"]}
                  for k, v in sorted(PLANS.items(), key=lambda kv: kv[1]["amount"])],
        "payeeWechat": os.environ.get("NT_WECHAT_NAME", ""),
        "payeeAlipay": os.environ.get("NT_ALIPAY_NAME", ""),
    }


def api_today(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    y, m, d = clamp_date(body.get("year", 2000), body.get("month", 1), body.get("day", 1))
    now = time.localtime()
    tm = as_int(body.get("forMonth"), now.tm_mon)
    td = as_int(body.get("forDay"), now.tm_mday)
    tm = max(1, min(12, tm))
    td = max(1, min(31, td))

    dest = E.Destiny(y, m, d, body.get("anchor", "birth"))
    f = dest.day_fortune(tm, td)
    return {
        "lifeNumber": dest.life_number,
        "lifePalace": C.palace_named(dest.life_number, lang),
        "date": {"month": tm, "day": td, "monthName": C.month_name(tm, lang)},
        "day": {"palace": f["day"], "named": C.palace_named(f["day"], lang),
                "brief": C.palace_brief(f["day"], lang),
                "keywords": C.palace_keywords(f["day"], lang)},
        "night": {"palace": f["night"], "named": C.palace_named(f["night"], lang),
                  "brief": C.palace_brief(f["night"], lang),
                  "keywords": C.palace_keywords(f["night"], lang)},
    }


def api_natal(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    y, m, d = clamp_date(body.get("year", 2000), body.get("month", 1), body.get("day", 1))
    dest = E.Destiny(y, m, d, body.get("anchor", "birth"))
    return {
        "birth": {"year": y, "month": m, "day": d},
        "triple": list(dest.triple),
        "lifeNumber": dest.life_number,
        "lifePalace": C.palace_named(dest.life_number, lang),
        "enneagram": C.enneagram_json(dest.life_number, lang),
        "rows": [C.row_json(r, lang) for r in dest.natal_chart],
    }


def api_fortune(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    y, m, d = clamp_date(body.get("year", 2000), body.get("month", 1), body.get("day", 1))
    dest = E.Destiny(y, m, d, body.get("anchor", "birth"))
    target = as_int(body.get("targetYear"), time.localtime().tm_year)
    target = max(1, min(9999, target))
    start = max(1, target - 2)
    period = dest.luck_period_containing(target)
    aspects = dest.luck_aspects(target)
    return {
        "targetYear": target,
        "aspects": {
            "start": aspects["start"], "end": aspects["end"],
            "rows": [dict(C.row_json(r, lang), aspect=r["aspect"],
                          aspectLabel=C.palace_label(r["aspect"], lang),
                          aspectShort=C.palace_short(r["aspect"], lang),
                          aspectBrief=C.palace_brief(r["aspect"], lang))
                     for r in aspects["aspects"]],
        },
        "years": [{"year": it["year"], "row": C.row_json(it["row"], lang)}
                  for it in dest.years(start, 12)],
        "luck": [{"start": p["start"], "end": p["end"], "row": C.row_json(p["row"], lang)}
                 for p in dest.luck_periods(8)],
        "currentLuck": {"start": period["start"], "end": period["end"],
                        "row": C.row_json(period["row"], lang)},
        "months": [{"month": it["month"], "name": C.month_name(it["month"], lang),
                    "row": C.row_json(it["row"], lang)}
                   for it in dest.month_chart(target)],
    }


def api_synastry(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    a = body.get("a") or {}
    b = body.get("b") or {}
    ay, am, ad = clamp_date(a.get("year", 2000), a.get("month", 1), a.get("day", 1))
    by, bm, bd = clamp_date(b.get("year", 2000), b.get("month", 1), b.get("day", 1))
    da = E.Destiny(ay, am, ad)
    db = E.Destiny(by, bm, bd)
    syn = da.synastry(db)
    return {
        "a": {"year": ay, "month": am, "day": ad, "lifeNumber": da.life_number},
        "b": {"year": by, "month": bm, "day": bd, "lifeNumber": db.life_number},
        "lifeNumber": syn["life_number"],
        "lifePalace": C.palace_named(syn["life_number"], lang),
        "enneagram": C.enneagram_json(syn["life_number"], lang),
        "rows": [C.row_json(r, lang) for r in syn["chart"]],
    }


def api_enneagram(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    n = E.r9(as_int(body.get("type"), 1))
    return C.enneagram_json(n, lang, full=True)


def api_palace(ctx, body):
    lang = C.norm_lang(body.get("lang"))
    n = E.r12(as_int(body.get("palace"), 1))
    return {"palace": n, "named": C.palace_named(n, lang),
            "keywords": C.palace_keywords(n, lang),
            "text": C.palace_text(n, lang)}


def api_order(ctx, body):
    plan = body.get("plan")
    if plan not in PLANS:
        return {"error": C.err("noSuchPlan", C.norm_lang(body.get("lang")))}, 400
    o = store.create_order(ctx.uid, plan)
    return {"ref": o["ref"], "amount": o["amount"], "days": o["days"],
            "status": o["status"], "createdAt": o["created_at"]}


def api_order_status(ctx, body):
    o = store.order((body.get("ref") or "").strip().upper())
    if not o or o["uid"] != ctx.uid:
        return {"error": C.err("noSuchOrder", C.norm_lang(body.get("lang")))}, 404
    return {"ref": o["ref"], "status": o["status"], "amount": o["amount"],
            "days": o["days"], "member": ctx.is_member,
            "expiresAt": store.expires_at(ctx.uid)}


def api_redeem(ctx, body):
    exp, err_key = store.redeem(ctx.uid, body.get("code"))
    if err_key:
        return {"error": C.err(err_key, C.norm_lang(body.get("lang")))}, 400
    return {"ok": True, "expiresAt": exp}


def api_restore(ctx, body):
    """換裝置時用會員憑證把會員接回來。"""
    uid = (body.get("uid") or "").strip().lower()
    u = store.user(uid)
    if not u:
        return {"error": C.err("badKey", C.norm_lang(body.get("lang")))}, 400
    ctx.uid = uid
    ctx.set_cookies.append("%s=%s; Path=/; Max-Age=%d; HttpOnly; SameSite=Lax"
                           % (COOKIE_UID, uid, 3600 * 24 * 730))
    return me_json(ctx)


# ── 後台 ────────────────────────────────────────────────────────────


def api_admin_login(ctx, body):
    if not ADMIN_PASSWORD:
        return {"error": C.err("adminNoPassword")}, 403
    if not hmac.compare_digest(str(body.get("password", "")), ADMIN_PASSWORD):
        return {"error": C.err("adminBadPassword")}, 403
    ctx.set_cookies.append("%s=%s; Path=/; Max-Age=%d; HttpOnly; SameSite=Lax"
                           % (COOKIE_ADMIN, admin_token(), 3600 * 12))
    return {"ok": True}


def _order_json(o):
    return {"ref": o["ref"], "amount": o["amount"], "days": o["days"],
            "status": o["status"], "createdAt": o["created_at"],
            "confirmedAt": o["confirmed_at"], "uid": o["uid"][:8]}


def api_admin_orders(ctx, body):
    if not ctx.is_admin:
        return {"error": C.err("adminLogin")}, 403
    status = body.get("status") or None
    return {"orders": [_order_json(o) for o in store.list_orders(status)],
            "stats": store.stats()}


def api_admin_confirm(ctx, body):
    if not ctx.is_admin:
        return {"error": C.err("adminLogin")}, 403
    o, err_key = store.confirm_order((body.get("ref") or "").strip().upper())
    if err_key and not o:
        return {"error": C.err(err_key)}, 400
    return {"ok": True, "note": C.err(err_key) if err_key else "",
            "order": _order_json(o)}


def api_admin_cancel(ctx, body):
    if not ctx.is_admin:
        return {"error": C.err("adminLogin")}, 403
    store.cancel_order((body.get("ref") or "").strip().upper())
    return {"ok": True}


def api_admin_codes(ctx, body):
    if not ctx.is_admin:
        return {"error": C.err("adminLogin")}, 403
    if body.get("make"):
        days = max(1, min(3650, as_int(body.get("days"), 5)))
        count = max(1, min(100, as_int(body.get("count"), 1)))
        made = store.make_codes(days, count)
        return {"created": made}
    return {"codes": [{"code": c["code"], "days": c["days"],
                       "used": bool(c["used_by"]), "createdAt": c["created_at"]}
                      for c in store.list_codes()]}


ROUTES = {
    "/api/me": (lambda ctx, body: me_json(ctx), False),
    "/api/today": (api_today, False),
    "/api/natal": (api_natal, True),
    "/api/fortune": (api_fortune, True),
    "/api/synastry": (api_synastry, True),
    "/api/enneagram": (api_enneagram, True),
    "/api/palace": (api_palace, False),
    "/api/order": (api_order, False),
    "/api/order/status": (api_order_status, False),
    "/api/redeem": (api_redeem, False),
    "/api/restore": (api_restore, False),
    "/api/admin/login": (api_admin_login, False),
    "/api/admin/orders": (api_admin_orders, False),
    "/api/admin/confirm": (api_admin_confirm, False),
    "/api/admin/cancel": (api_admin_cancel, False),
    "/api/admin/codes": (api_admin_codes, False),
}


# ── 收款碼 ──────────────────────────────────────────────────────────

PLACEHOLDER = """<svg xmlns="http://www.w3.org/2000/svg" width="260" height="300"
     viewBox="0 0 260 300"><rect width="260" height="300" rx="16" fill="{bg}"/>
<rect x="30" y="30" width="200" height="200" rx="12" fill="#fff"/>
<text x="130" y="120" font-size="15" fill="#888" text-anchor="middle">還沒放收款碼</text>
<text x="130" y="148" font-size="12" fill="#aaa" text-anchor="middle">把圖片放到</text>
<text x="130" y="168" font-size="11" fill="#aaa" text-anchor="middle"
      font-family="monospace">static/pay/{name}.png</text>
<text x="130" y="268" font-size="16" fill="#fff" text-anchor="middle">{title}</text></svg>"""

PAY_STYLE = {
    "wechat": ("#09BB07", "微信支付"),
    "alipay": ("#1677FF", "支付寶"),
}


# ── HTTP ────────────────────────────────────────────────────────────


class Handler(BaseHTTPRequestHandler):
    server_version = "NineTwelve"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))

    # 回應

    def _send(self, code, body, ctype, ctx=None, extra=None):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "same-origin")
        for c in (ctx.set_cookies if ctx else []):
            self.send_header("Set-Cookie", c)
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, obj, code=200, ctx=None):
        self._send(code, json.dumps(obj, ensure_ascii=False),
                   "application/json; charset=utf-8", ctx,
                   {"Cache-Control": "no-store"})

    def _file(self, path, ctx=None):
        if not os.path.isfile(path):
            return self._send(404, "not found", "text/plain; charset=utf-8", ctx)
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype == "application/javascript":
            ctype += "; charset=utf-8"
        with open(path, "rb") as f:
            data = f.read()
        cache = "no-cache" if path.endswith(".html") else "public, max-age=3600"
        self._send(200, data, ctype, ctx, {"Cache-Control": cache})

    # 路由

    def do_GET(self):
        ctx = Ctx(self)
        path = urlparse(self.path).path

        if path in ("/", "/index.html"):
            return self._file(os.path.join(STATIC, "index.html"), ctx)
        if path == "/admin":
            return self._file(os.path.join(STATIC, "admin.html"), ctx)

        if path.startswith("/pay/"):
            name = os.path.basename(path)
            stem = os.path.splitext(name)[0]
            if stem not in PAY_STYLE:
                return self._send(404, "not found", "text/plain; charset=utf-8", ctx)
            real = os.path.join(STATIC, "pay", stem + ".png")
            if os.path.isfile(real):
                return self._file(real, ctx)
            bg, title = PAY_STYLE[stem]
            svg = PLACEHOLDER.format(bg=bg, title=html.escape(title), name=stem)
            return self._send(200, svg, "image/svg+xml; charset=utf-8", ctx,
                              {"Cache-Control": "no-store"})

        if path.startswith("/static/"):
            rel = path[len("/static/"):]
            full = os.path.normpath(os.path.join(STATIC, rel))
            if not full.startswith(STATIC):          # 擋住 ../ 之類的路徑
                return self._send(403, "no", "text/plain; charset=utf-8", ctx)
            return self._file(full, ctx)

        if path == "/healthz":
            return self._send(200, "ok", "text/plain; charset=utf-8", ctx)

        # GET 也讓 /api/me 通，方便開頁時先問一次
        if path == "/api/me":
            return self._json(me_json(ctx), 200, ctx)

        return self._send(404, "not found", "text/plain; charset=utf-8", ctx)

    def do_HEAD(self):
        self.do_GET()

    def do_POST(self):
        ctx = Ctx(self)
        path = urlparse(self.path).path
        # 還沒讀到 body 之前，先用 Accept-Language 猜；讀到 body 再以它為準
        lang = guess_lang(self.headers.get("Accept-Language", ""))
        route = ROUTES.get(path)
        if not route:
            return self._json({"error": C.err("notFound", lang)}, 404, ctx)

        fn, needs_member = route
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length > MAX_BODY:
            return self._json({"error": C.err("tooLarge", lang)}, 413, ctx)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
            if not isinstance(body, dict):
                raise ValueError
        except Exception:
            return self._json({"error": C.err("badFormat", lang)}, 400, ctx)

        lang = C.norm_lang(body.get("lang")) if body.get("lang") else lang

        if needs_member and not ctx.is_member:
            return self._json({"error": "locked", "member": False}, 402, ctx)

        try:
            result = fn(ctx, body)
        except BadInput as exc:
            return self._json({"error": C.err(exc.key, lang)}, 400, ctx)
        except Exception as exc:                      # 不要把內部訊息漏給前端
            sys.stderr.write("!! %s %r\n" % (path, exc))
            return self._json({"error": C.err("serverBusy", lang)}, 500, ctx)

        if isinstance(result, tuple):
            payload, code = result
        else:
            payload, code = result, 200
        return self._json(payload, code, ctx)


def main():
    port = int(os.environ.get("PORT", "8000"))
    if not ADMIN_PASSWORD:
        sys.stderr.write("注意：沒有設 NT_ADMIN_PASSWORD，後台 /admin 會打不開。\n")
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    sys.stderr.write("九型十二宮 網站啟動： http://0.0.0.0:%d\n" % port)
    sys.stderr.write("資料庫：%s\n" % DB_PATH)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
