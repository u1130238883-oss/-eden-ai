# IPA 在線簽名

一個自己架設的 IPA 簽名網站：上傳一次證書（.p12 + .mobileprovision），之後在 iPhone 的 Safari 裡上傳 IPA，就能簽名，然後點「安裝」直接裝到手機上。

- 簽名用開源的 [zsign](https://github.com/zhlynn/zsign)，Docker 構建時自動編譯
- 可以修改 Bundle ID、App 名稱和版本號
- 可以向蘋果 OCSP 查詢證書有沒有被吊銷（掉簽）
- 整個網站用密碼保護。證書只保存在你自己的服務器上

## 必須是 HTTPS

iPhone 的 `itms-services://` 線上安裝**只接受 HTTPS**，而且證書要是瀏覽器信任的（例如 Let's Encrypt），自簽證書不行。下面兩種部署方式都會自動配好 HTTPS。

## 部署方式一：VPS + Docker + Caddy（推薦）

需要一台 Linux VPS，以及一個指向它的域名，例如 `sign.example.com`。

```bash
git clone <這個 repo>
cd <repo>/ipa-signer
docker build -t ipa-signer .
docker run -d --name ipa-signer --restart unless-stopped \
  -e ACCESS_PASSWORD='換成你自己的長密碼' \
  -v /srv/ipa-signer:/data \
  -p 127.0.0.1:8000:8000 ipa-signer
```

再用 Caddy 做 HTTPS 反向代理（Caddy 會自動申請 Let's Encrypt 證書）。`/etc/caddy/Caddyfile`：

```
sign.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

`systemctl reload caddy`，然後在 iPhone 的 Safari 打開 `https://sign.example.com`。

## 部署方式二：Render / Fly.io 等平台

選擇 Docker 部署，Root Directory 填 `ipa-signer`，再設置：

- 環境變量 `ACCESS_PASSWORD`：網站登錄密碼
- 掛載一個**持久化磁碟**到 `/data`。沒有持久化磁碟的話，每次重啟證書和 App 都會丟失

平台會自動提供 HTTPS 域名。

## 環境變量

| 變量 | 說明 |
|---|---|
| `ACCESS_PASSWORD` | **必填**，網站登錄密碼 |
| `PUBLIC_URL` | 可選，例如 `https://sign.example.com`。反向代理沒有傳 `X-Forwarded-*` 頭時才需要 |
| `DATA_DIR` | 數據目錄，Docker 裡默認是 `/data` |
| `PORT` | 端口，默認 `8000` |

## 使用

1. 登錄後，在「上傳證書」裡選 `.p12`，填證書密碼，再選 `.mobileprovision`，保存
2. 點「檢查證書是否被吊銷」，確認狀態是「有效」
3. 選 IPA，點「開始簽名」
4. 簽好後點「安裝」，在彈窗裡確認，回到桌面就能看到 App 在下載

## 常見問題

- **提示「無法安裝」**：Ad Hoc 描述文件只能裝在登記過的設備上。看一下頁面上「可安裝設備」的 UDID 是不是你的 iPhone。
- **裝好後一打開就閃退**：通常是證書被吊銷了。先點「檢查證書是否被吊銷」確認。
- **App 需要的權限描述文件裡沒有**（例如推送、iCloud）：相關功能可能用不了，但一般不影響安裝。
- **安全**：證書、密碼和簽好的 IPA 都保存在服務器的 `/data` 目錄。安裝鏈接是隨機生成的，別人猜不到，但不要把它公開分享。
