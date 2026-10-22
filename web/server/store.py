# -*- coding: utf-8 -*-
"""會員資料：SQLite，一個檔案，放在伺服器上。

存的東西很少 —— 一個隨機識別碼、會員到期時間、訂單與啟用碼。
不存姓名、不存 email、不存生日（生日只在算的時候經過，不落地）。
"""
import os
import secrets
import sqlite3
import time
import threading

# 方案：金額（人民幣元）→ 天數
PLANS = {
    "p10": {"amount": 10, "days": 5},
    "p20": {"amount": 20, "days": 15},
    "p30": {"amount": 30, "days": 30},
}

# 訂單編號與啟用碼用的字元，去掉容易看錯的 0O1I
ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

_local = threading.local()


def _now():
    return int(time.time())


class Store:
    def __init__(self, path):
        self.path = path
        os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
        self._init_schema()

    # 每個執行緒各自一條連線，sqlite3 的連線不能跨執行緒共用
    @property
    def db(self):
        conn = getattr(_local, "conn_" + str(id(self)), None)
        if conn is None:
            conn = sqlite3.connect(self.path, timeout=10)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            setattr(_local, "conn_" + str(id(self)), conn)
        return conn

    def _init_schema(self):
        db = self.db
        db.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                uid        TEXT PRIMARY KEY,
                expires_at INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS orders (
                ref          TEXT PRIMARY KEY,
                uid          TEXT NOT NULL,
                plan         TEXT NOT NULL,
                amount       INTEGER NOT NULL,
                days         INTEGER NOT NULL,
                status       TEXT NOT NULL DEFAULT 'pending',
                created_at   INTEGER NOT NULL,
                confirmed_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS codes (
                code       TEXT PRIMARY KEY,
                days       INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                used_by    TEXT,
                used_at    INTEGER
            );
            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS orders_status ON orders(status, created_at);
        """)
        db.commit()

    # ── 設定 ────────────────────────────────────────────────────────

    def setting(self, key, default=None):
        row = self.db.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row["value"] if row else default

    def set_setting(self, key, value):
        self.db.execute(
            "INSERT INTO settings(key, value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, value))
        self.db.commit()

    def secret(self):
        """簽章用的密鑰。沒有就自己生一個存起來。"""
        s = self.setting("secret")
        if not s:
            s = secrets.token_hex(32)
            self.set_setting("secret", s)
        return s

    # ── 使用者 ──────────────────────────────────────────────────────

    def new_uid(self):
        uid = secrets.token_hex(16)
        self.db.execute("INSERT INTO users(uid, expires_at, created_at) VALUES(?,0,?)",
                        (uid, _now()))
        self.db.commit()
        return uid

    def user(self, uid):
        if not uid:
            return None
        return self.db.execute("SELECT * FROM users WHERE uid=?", (uid,)).fetchone()

    def ensure_user(self, uid):
        """有這個 uid 就沿用，沒有就開一個新的。回傳 (uid, 是不是新開的)。"""
        if uid and self.user(uid):
            return uid, False
        return self.new_uid(), True

    def expires_at(self, uid):
        u = self.user(uid)
        return u["expires_at"] if u else 0

    def is_member(self, uid):
        return self.expires_at(uid) > _now()

    def grant_days(self, uid, days):
        """加時間。還在會員期內就往後接，過期了就從現在算起。"""
        now = _now()
        base = max(self.expires_at(uid), now)
        new_exp = base + days * 86400
        self.db.execute("UPDATE users SET expires_at=? WHERE uid=?", (new_exp, uid))
        self.db.commit()
        return new_exp

    # ── 訂單 ────────────────────────────────────────────────────────

    def _fresh_ref(self):
        while True:
            ref = "".join(secrets.choice(ALPHABET) for _ in range(6))
            if not self.db.execute("SELECT 1 FROM orders WHERE ref=?", (ref,)).fetchone():
                return ref

    def create_order(self, uid, plan):
        p = PLANS[plan]
        ref = self._fresh_ref()
        self.db.execute(
            "INSERT INTO orders(ref, uid, plan, amount, days, status, created_at) "
            "VALUES(?,?,?,?,?,'pending',?)",
            (ref, uid, plan, p["amount"], p["days"], _now()))
        self.db.commit()
        return self.order(ref)

    def order(self, ref):
        return self.db.execute("SELECT * FROM orders WHERE ref=?", (ref,)).fetchone()

    def orders_for(self, uid, limit=20):
        return self.db.execute(
            "SELECT * FROM orders WHERE uid=? ORDER BY created_at DESC LIMIT ?",
            (uid, limit)).fetchall()

    def list_orders(self, status=None, limit=200):
        if status:
            return self.db.execute(
                "SELECT * FROM orders WHERE status=? ORDER BY created_at DESC LIMIT ?",
                (status, limit)).fetchall()
        return self.db.execute(
            "SELECT * FROM orders ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()

    def confirm_order(self, ref):
        """確認收到錢：給時間，訂單標成已完成。重複點不會給第二次。

        第二個回傳值是錯誤代號，不是句子 —— 這一層不知道客人用哪個語言，
        翻譯交給 content.err()。
        """
        o = self.order(ref)
        if not o:
            return None, "noSuchOrder"
        if o["status"] == "paid":
            return o, "orderDone"
        self.grant_days(o["uid"], o["days"])
        self.db.execute("UPDATE orders SET status='paid', confirmed_at=? WHERE ref=?",
                        (_now(), ref))
        self.db.commit()
        return self.order(ref), None

    def cancel_order(self, ref):
        self.db.execute("UPDATE orders SET status='cancelled' WHERE ref=? AND status='pending'",
                        (ref,))
        self.db.commit()

    # ── 啟用碼 ──────────────────────────────────────────────────────

    def make_codes(self, days, count=1):
        out = []
        for _ in range(count):
            while True:
                body = "".join(secrets.choice(ALPHABET) for _ in range(12))
                code = "NT-%s-%s-%s" % (body[:4], body[4:8], body[8:])
                if not self.db.execute("SELECT 1 FROM codes WHERE code=?", (code,)).fetchone():
                    break
            self.db.execute("INSERT INTO codes(code, days, created_at) VALUES(?,?,?)",
                            (code, days, _now()))
            out.append(code)
        self.db.commit()
        return out

    def redeem(self, uid, code):
        code = (code or "").strip().upper().replace(" ", "")
        if code and not code.startswith("NT-") and len(code) == 12:
            code = "NT-%s-%s-%s" % (code[:4], code[4:8], code[8:])
        row = self.db.execute("SELECT * FROM codes WHERE code=?", (code,)).fetchone()
        if not row:
            return None, "badCode"
        if row["used_by"]:
            return None, "codeUsed"
        self.db.execute("UPDATE codes SET used_by=?, used_at=? WHERE code=?",
                        (uid, _now(), code))
        self.db.commit()
        return self.grant_days(uid, row["days"]), None

    def list_codes(self, limit=200):
        return self.db.execute(
            "SELECT * FROM codes ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()

    # ── 給後台看的小統計 ────────────────────────────────────────────

    def stats(self):
        now = _now()
        q = self.db.execute
        return {
            "members": q("SELECT COUNT(*) c FROM users WHERE expires_at>?", (now,)).fetchone()["c"],
            "users": q("SELECT COUNT(*) c FROM users").fetchone()["c"],
            "pending": q("SELECT COUNT(*) c FROM orders WHERE status='pending'").fetchone()["c"],
            "paid": q("SELECT COUNT(*) c FROM orders WHERE status='paid'").fetchone()["c"],
            "revenue": q("SELECT COALESCE(SUM(amount),0) s FROM orders WHERE status='paid'"
                         ).fetchone()["s"],
        }
