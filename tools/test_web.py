#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""網站的整套測試：自己起一個伺服器，把整條流程走一遍。

    python3 tools/test_web.py

會檢查：算出來的結果對不對、沒付錢進不進得去、付款流程通不通、
啟用碼會不會被重複用、後台有沒有擋住外人、亂送資料會不會弄掛伺服器。
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = int(os.environ.get("NT_TEST_PORT", "8799"))
BASE = "http://127.0.0.1:%d" % PORT
PASSWORD = "test-password-not-a-real-one"
DB = "/tmp/nt-test-%d.sqlite3" % os.getpid()

fails = []


def check(label, got, want):
    ok = got == want
    print("  %s  %-46s %s" % ("OK " if ok else "!!!", label, got))
    if not ok:
        fails.append("%s：得到 %r，應為 %r" % (label, got, want))


class Session:
    """記得 cookie 的小客戶端。要收好每一個 cookie，不能只留最後一個。"""

    def __init__(self):
        self.jar = {}

    @property
    def cookie(self):
        return "; ".join("%s=%s" % kv for kv in self.jar.items())

    def post(self, path, body=None):
        data = json.dumps(body or {}).encode()
        req = urllib.request.Request(BASE + path, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        if self.cookie:
            req.add_header("Cookie", self.cookie)
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                self._save(r)
                return r.status, json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            self._save(e)
            raw = e.read().decode()
            try:
                return e.code, json.loads(raw or "{}")
            except ValueError:
                return e.code, {"raw": raw}

    def post_raw(self, path, raw):
        req = urllib.request.Request(BASE + path, data=raw.encode(), method="POST")
        req.add_header("Content-Type", "application/json")
        if self.cookie:
            req.add_header("Cookie", self.cookie)
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return r.status
        except urllib.error.HTTPError as e:
            return e.code

    def _save(self, resp):
        for c in resp.headers.get_all("Set-Cookie") or []:
            name, _, value = c.split(";")[0].partition("=")
            self.jar[name.strip()] = value.strip()


def wait_up(proc):
    for _ in range(60):
        try:
            with urllib.request.urlopen(BASE + "/healthz", timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            pass
        if proc.poll() is not None:
            return False
        time.sleep(0.25)
    return False


def run():
    print("=== 1. 算出來的結果要和 App 一致 ===")
    u = Session()
    u.post("/api/me")

    _, d = u.post("/api/today", {"year": 2006, "month": 1, "day": 14,
                                 "forMonth": 8, "forDay": 17, "lang": "zh"})
    check("靈數", d["lifeNumber"], 5)
    check("8月17日 白天", d["day"]["palace"], 10)
    check("8月17日 晚上", d["night"]["palace"], 3)

    print("\n=== 2. 沒有會員，三頁都要鎖住 ===")
    for path in ("/api/natal", "/api/fortune", "/api/synastry"):
        code, _ = u.post(path, {"year": 2006, "month": 1, "day": 14})
        check("未付費 " + path, code, 402)
    code, _ = u.post("/api/today", {"year": 2006, "month": 1, "day": 14})
    check("今日永遠免費", code, 200)

    print("\n=== 3. 付款流程 ===")
    _, o = u.post("/api/order", {"plan": "p10"})
    ref = o["ref"]
    check("方案金額", o["amount"], 10)
    check("方案天數", o["days"], 5)
    check("編號長度", len(ref), 6)
    _, st = u.post("/api/order/status", {"ref": ref})
    check("尚未確認", st["status"], "pending")

    admin = Session()
    code, _ = admin.post("/api/admin/login", {"password": "wrong"})
    check("後台密碼錯", code, 403)
    code, _ = admin.post("/api/admin/login", {"password": PASSWORD})
    check("後台密碼對", code, 200)

    _, lst = admin.post("/api/admin/orders", {"status": "pending"})
    check("後台看得到這筆", ref in [x["ref"] for x in lst["orders"]], True)

    st_code, _ = admin.post("/api/admin/confirm", {"ref": ref})
    check("後台確認收款", st_code, 200)
    _, me = u.post("/api/me")
    check("確認後成為會員", me["member"], True)
    check("拿到 5 天", me["daysLeft"], 5)

    _, again = admin.post("/api/admin/confirm", {"ref": ref})
    check("重複確認會被擋", bool(again.get("note")), True)
    _, me = u.post("/api/me")
    check("天數沒有被加第二次", me["daysLeft"], 5)

    print("\n=== 4. 會員可以看三頁，而且數字要對 ===")
    _, n = u.post("/api/natal", {"year": 2006, "month": 1, "day": 14, "lang": "zh"})
    check("本命三柱", n["triple"], [8, 1, 5])
    check("命盤首列", "%s %s %s" % (n["rows"][0]["palaceLabel"],
                                    n["rows"][0]["tripleText"],
                                    n["rows"][0]["readingText"]), "5宮 9；2；6 壞3因8")
    check("命盤末列", "%s %s %s" % (n["rows"][11]["palaceLabel"],
                                    n["rows"][11]["tripleText"],
                                    n["rows"][11]["readingText"]), "6宮 8；1；5 正5因7")
    check("九型人格", n["enneagram"]["label"], "第五型")

    _, f = u.post("/api/fortune", {"year": 2006, "month": 1, "day": 14,
                                   "targetYear": 2026, "lang": "zh"})
    check("2026 大運起訖", (f["currentLuck"]["start"], f["currentLuck"]["end"]), (2019, 2027))
    check("2026 一月", "%s %s %s" % (f["months"][0]["row"]["palaceLabel"],
                                     f["months"][0]["row"]["tripleText"],
                                     f["months"][0]["row"]["readingText"]), "7宮 5；3；11 壞4因2")

    _, s = u.post("/api/synastry", {"a": {"year": 2006, "month": 1, "day": 14},
                                    "b": {"year": 2007, "month": 1, "day": 23},
                                    "lang": "zh"})
    check("合盤靈數", s["lifeNumber"], 8)
    check("合盤首列", "%s %s %s" % (s["rows"][0]["palaceLabel"],
                                    s["rows"][0]["tripleText"],
                                    s["rows"][0]["readingText"]), "8宮 6；3；11 正11因7")

    print("\n=== 5. 啟用碼 ===")
    _, made = admin.post("/api/admin/codes", {"make": True, "days": 30, "count": 2})
    check("產生兩組", len(made["created"]), 2)
    code_a = made["created"][0]

    u2 = Session()
    u2.post("/api/me")
    st, _ = u2.post("/api/redeem", {"code": code_a})
    check("兌換成功", st, 200)
    _, me2 = u2.post("/api/me")
    check("拿到 30 天", me2["daysLeft"], 30)

    u3 = Session()
    u3.post("/api/me")
    st, r = u3.post("/api/redeem", {"code": code_a})
    check("同一組不能用第二次", st, 400)
    st, _ = u3.post("/api/redeem", {"code": "NT-0000-0000-0000"})
    check("亂打的碼會被拒", st, 400)

    print("\n=== 6. 別人的會員不會外漏 ===")
    guest = Session()
    guest.post("/api/me")
    for path in ("/api/natal", "/api/fortune", "/api/synastry"):
        code, _ = guest.post(path, {"year": 2000, "month": 1, "day": 1})
        check("新訪客 " + path, code, 402)

    print("\n=== 7. 後台不能被外人碰 ===")
    for path, body in (("/api/admin/confirm", {"ref": ref}),
                       ("/api/admin/cancel", {"ref": ref}),
                       ("/api/admin/orders", {}),
                       ("/api/admin/codes", {"make": True, "days": 9999})):
        code, _ = guest.post(path, body)
        check("未登入 " + path, code, 403)

    print("\n=== 8. 會員憑證可以換裝置 ===")
    _, me = u.post("/api/me")
    moved = Session()
    moved.post("/api/me")
    _, r = moved.post("/api/restore", {"uid": me["uid"]})
    check("恢復後是會員", r["member"], True)
    st, _ = moved.post("/api/restore", {"uid": "0" * 32})
    check("假憑證會被拒", st, 400)

    print("\n=== 9. 亂送資料不會弄掛伺服器 ===")
    for raw in ('{"year":"abc","month":1,"day":1}', '{"year":null,"month":1,"day":1}',
                'not json at all', '[1,2,3]', '{"year":1e999}', '"hello"'):
        got = u.post_raw("/api/today", raw)
        check("壞資料 %-32s" % raw[:32], got, 400)
    code, _ = u.post("/api/today", {"year": -5, "month": 99, "day": 999})
    check("超出範圍會被夾住而不是報錯", code, 200)
    code, _ = u.post("/api/order", {"plan": "p999"})
    check("不存在的方案", code, 400)

    print("\n=== 10. 四種語言 ===")
    want = {
        "zh": ("5宮", "桃花", "壞3因8", "第五型"),
        "en": ("Palace 5", "Peach Blossom", "Adverse 3 from 8", "Type 5"),
        "es": ("Palacio 5", "Flor de Durazno", "Adverso 3 de 8", "Tipo 5"),
        "it": ("Palazzo 5", "Fiore di Pesco", "Avverso 3 da 8", "Tipo 5"),
    }
    for lg, (pl, short, rd, ty) in want.items():
        _, n = u.post("/api/natal", {"year": 2006, "month": 1, "day": 14, "lang": lg})
        r = n["rows"][0]
        check("%s 宮位" % lg, r["palaceLabel"], pl)
        check("%s 簡稱" % lg, r["palaceShort"], short)
        check("%s 判讀" % lg, r["readingText"], rd)
        check("%s 九型" % lg, n["enneagram"]["label"], ty)

    print("\n  ── 內容在四種語言都要有，不能空白或掉回中文 ──")
    for lg in ("en", "es", "it"):
        _, e = u.post("/api/enneagram", {"type": 5, "lang": lg})
        check("%s 九型詳情有摘要" % lg, bool(e["summary"].strip()), True)
        check("%s 九型詳情七段" % lg, len(e["sections"]), 7)
        check("%s 每段都有內容" % lg, all(s["lines"] for s in e["sections"]), True)
        _, p = u.post("/api/palace", {"palace": 9, "lang": lg})
        check("%s 宮位含義有內容" % lg, len(p["keywords"]) > 0, True)

    print("\n  ── 錯誤訊息也要跟著語言走 ──")
    msgs = {}
    for lg in ("zh", "en", "es", "it"):
        _, r = u.post("/api/redeem", {"code": "NT-0000-0000-0000", "lang": lg})
        msgs[lg] = r["error"]
        check("%s 錯誤訊息非空" % lg, bool(r["error"].strip()), True)
    check("四種語言的訊息互不相同", len(set(msgs.values())), 4)
    _, r = u.post("/api/today", {"year": "abc", "month": 1, "day": 1, "lang": "es"})
    check("西語的日期錯誤訊息", r["error"], "La fecha debe ser numérica")

    print("\n=== 11. 演算法不能外流到瀏覽器 ===")
    with urllib.request.urlopen(BASE + "/static/app.js", timeout=10) as r:
        js = r.read().decode()
    for word in ("digit_root9", "GEN =", "OVR =", "luck_period", "r12(", "ELEM"):
        check("前端不含「%s」" % word, word in js, False)
    for path in ("/static/../server/engine.py", "/server/engine.py", "/static/engine.py"):
        try:
            with urllib.request.urlopen(BASE + path, timeout=5) as r:
                got = r.status
        except urllib.error.HTTPError as e:
            got = e.code
        check("拿不到 " + path, got in (403, 404), True)


def main():
    env = dict(os.environ)
    env.update({"PORT": str(PORT), "NT_DB": DB, "NT_ADMIN_PASSWORD": PASSWORD})
    proc = subprocess.Popen([sys.executable, os.path.join(ROOT, "web", "server", "app.py")],
                            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        if not wait_up(proc):
            print("伺服器沒起來：")
            print((proc.stderr.read() or b"").decode())
            return 1
        run()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        for suffix in ("", "-wal", "-shm"):
            try:
                os.remove(DB + suffix)
            except OSError:
                pass

    print("\n" + "=" * 62)
    if fails:
        print("不符 %d 項：" % len(fails))
        for f in fails:
            print("  " + f)
        return 1
    print("網站全部檢查通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
