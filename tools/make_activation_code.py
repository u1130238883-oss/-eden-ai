#!/usr/bin/env python3
"""產生直連版（微信／支付寶收款）的會員啟用碼。

用法：

    python3 tools/make_activation_code.py <裝置碼> [月數]

例：

    python3 tools/make_activation_code.py K7QX4M2Z 1
    → 20260919-P4WT9BXK

流程：用戶在 App 的付款頁看到自己的「裝置碼」，付款時一併傳給你；
你用這支程式產生啟用碼回給他；他輸入後 App 在本機驗證，不需要連網。

金鑰必須與建置 APK 時使用的 `ninetwelve.activationSecret` 完全一致，
否則產出的碼 App 不認。金鑰從環境變數 NINETWELVE_SECRET 讀取：

    export NINETWELVE_SECRET='你的金鑰'

啟用碼綁定裝置碼，換手機就失效，所以不能互相轉傳。
但要清楚一件事：金鑰是編進 APK 裡的，會反編譯的人可以挖出來自己發碼。
這對這個規模的軟體夠用，但不是防不破的。
"""
import datetime
import hashlib
import hmac
import os
import sys

# 去掉容易看錯的 I O 0 1，必須與 DirectMembership.ALPHABET 相同
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
MAC_LENGTH = 8


def sign(secret: str, device: str, expiry: str) -> str:
    digest = hmac.new(secret.encode("utf-8"),
                      f"{device}|{expiry}".encode("utf-8"),
                      hashlib.sha256).digest()
    return "".join(ALPHABET[b & 0x1F] for b in digest[:MAC_LENGTH])


def add_months(d: datetime.date, months: int) -> datetime.date:
    total = d.month - 1 + months
    year = d.year + total // 12
    month = total % 12 + 1
    # 月底日期不存在時往前退（例如 1/31 加一個月 → 2/28）
    day = d.day
    while True:
        try:
            return datetime.date(year, month, day)
        except ValueError:
            day -= 1


def make_code(secret: str, device: str, months: int) -> tuple[str, str]:
    device = "".join(c for c in device.upper() if c.isalnum())
    expiry_date = add_months(datetime.date.today(), months)
    expiry = expiry_date.strftime("%Y%m%d")
    return f"{expiry}-{sign(secret, device, expiry)}", expiry_date.isoformat()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1

    secret = os.environ.get("NINETWELVE_SECRET")
    if not secret:
        print("錯誤：請先設定環境變數 NINETWELVE_SECRET，"
              "值要與建置 APK 時的 ninetwelve.activationSecret 一致。",
              file=sys.stderr)
        return 2
    if secret == "CHANGE-ME-BEFORE-RELEASE":
        print("警告：你還在用預設金鑰，正式發佈前請換掉。", file=sys.stderr)

    device = argv[1]
    months = int(argv[2]) if len(argv) > 2 else 1

    code, expiry = make_code(secret, device, months)
    print(f"裝置碼　：{''.join(c for c in device.upper() if c.isalnum())}")
    print(f"有效期至：{expiry}（{months} 個月）")
    print(f"啟用碼　：{code}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
