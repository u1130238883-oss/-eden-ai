# 潮流壁紙（StreetWall）交接文件

最後更新：2026-11-15
分支：`claude/zzz-wallpaper-app`（倉庫 `zc2694437-sudo/ZcA304`）
目前程式碼版本：**v2.6（build 16）**
最後一個成功建置並發給使用者的 IPA：**v2.4（build 14）**

> v2.5 / v2.6 已推到 GitHub，但沒能建置。GitHub 回覆 "recent account payments have failed or your spending limit needs to be increased"：帳號付款失敗，或 Actions 花費上限不足。倉庫是私人的，私人倉庫用 Mac runner 建置要計費。要重新出 IPA，二選一：
> - 修好帳單（Settings → Billing and plans）
> - 把倉庫改成公開（公開倉庫的 Actions 免費）

---

## 1. 專案概要

| 項目 | 內容 |
|---|---|
| App 名稱（桌面顯示） | 潮流壁紙 |
| 類型 | iOS 壁紙切換 App（SwiftUI），絕區零風街頭潮流 UI |
| 目標裝置 | iPhone 16e（1170×2532），iOS 17+ |
| Bundle ID | `com.streetwall.app` |
| 壁紙數量 | 82 張（4 個系列，見 §4） |
| 發佈形式 | 未簽名 IPA，用 Sideloadly / AltStore / 簽名工具裝 |
| 資料儲存 | 只在本機 `UserDefaults` |

### 底部四個分頁

1. **頻道（ChannelView）**：CRT 電視造型的預覽。
   - 左右滑換台，點一下顯示或隱藏鎖屏時鐘，長按全螢幕。
   - 右側：▲／隨機／▼、收藏。
   - 下方：「一鍵套用」（選單：設為鎖定畫面／設為主畫面／鎖定＋主畫面／安裝捷徑）、存相簿、分享。
2. **片庫（LibraryView）**：系列篩選（全部／霓虹街區／街頭新番／都市潮流／黃綠系列／收藏）、三欄縮圖、全部存相簿。
3. **生成（GeneratorView）**：壁紙生成器。
   - 10 種版式、12 組配色，文字可自訂。
   - 開關：網點、膠帶、掃描線、顆粒；傾斜角度。
   - 按鈕：隨機骰、上一個、✦換個變化（seed）、時鐘預覽、一鍵套用、存相簿（1170×2532）。
4. **自動（AutoView）**：
   - 換台順序：順序／隨機／收藏。
   - 自動套用到：鎖定／主畫面／兩者。
   - 安裝「潮流自動換壁紙」捷徑，並有建立自動化的步驟說明。
   - 「主畫面是純色？」說明頁、立即試跑。

---

## 2. 檔案結構

```
project.yml                  XcodeGen 專案設定（版本號在這裡改）
StreetWall/
  StreetWallApp.swift        App 入口、底部分頁、Toaster、URL scheme、兩個 sheet
  Model.swift                Series / Wallpaper / Catalog（82 張清單）/ Rotation / WallStore / PhotoSaver
  Theme.swift                配色、字型、斜角按鈕、網點、掃描線、警示條紋等元件
  ChannelView.swift          頻道頁
  LibraryView.swift          片庫頁
  GeneratorView.swift        生成器（WallArt 畫布 390×844pt，ImageRenderer @3x）
  AutoView.swift             自動頁
  Apply.swift                一鍵套用流程、WallTarget、ShortcutSetupSheet、HomeGuideSheet
  Intents.swift              App Intents（下一張壁紙／目前頻道壁紙／指定頻道）
  Info.plist                 URL scheme streetwall://、相簿寫入權限
  Resources/Wallpapers/      wp01–wp20.png、wp21–wp82.jpg、各自的 _thumb.jpg（390×844）
  Assets.xcassets/           App 圖示、AccentColor、LaunchBG
scripts/
  make_shortcut.py           產生 4 個未簽名捷徑（lock/home/both/auto）
  hubsign.sh                 用 RoutineHub 的 HubSign 服務簽名捷徑（不需要 Apple ID）
.github/workflows/build-ipa.yml
                             GitHub Actions：產生並簽名捷徑 → xcodegen → xcodebuild → 打包 IPA → 發 Release
design-src/
  *.dc.html + render.js      1–20 號原始設計（Design 畫布匯出）
  neo/_gen.py + render.js    21–32「街頭新番」
  neo2/_gen.py + meta.json   33–82「霓虹街區」（10 類 × 5 張，黑底 + 黃綠）
```

---

## 3. 一鍵套用的原理（最重要）

iOS 不允許 App 直接換桌布，只有「捷徑」App 能換，所以流程是：

1. App 把目前的壁紙（PNG 或 JPEG）放進**剪貼簿**（120 秒後過期、只限本機）。
2. 用 `shortcuts://x-callback-url/run-shortcut?name=…` 執行對應的捷徑。
3. 捷徑跑完後，透過 `streetwall://applied`、`shortcut-error` 或 `shortcut-cancel` 回到 App，App 顯示結果。失敗時會打開安裝說明頁。

### App 內建 4 個已簽名捷徑（CI 產生，放進 IPA）

| 捷徑名稱 | 動作 |
|---|---|
| 潮流換壁紙（鎖定畫面） | 取得剪貼簿 → 取得目前桌布（Current）→ 第一項 → 設定桌布（WFSelectedPoster） |
| 潮流換壁紙主畫面 | 同上，但「設定桌布」加 `WFWallpaperLocation = ["Home Screen"]` |
| 潮流換壁紙兩者 | 同「鎖定畫面」，再加一個 Home Screen 的「設定桌布」 |
| 潮流自動換壁紙 | 打開 `streetwall://auto` → App 換到下一台 → 用上面選的捷徑套用 |

所有「設定桌布」都設了 `WFWallpaperShowPreview = false`、`WFWallpaperSmartCrop = false`、`WFWallpaperLegibilityBlur = false`。

### 踩過的坑（都已修正）

| 問題 | 原因 | 解法 |
|---|---|---|
| 「找不到動作」 | 動作 ID 寫錯（`getlatestphotos`） | 正確是 `is.workflow.actions.getlastphoto`，後來改用剪貼簿 |
| 換別張還是第一張 | 「最新照片」受相簿有限存取影響 | 改用剪貼簿傳圖 |
| 「Scegli un valore per ogni parametro」 | 捷徑裡的 If 判斷、或沒有指定桌布時的 Location | 每個目標拆成獨立捷徑，不用 If |
| 每跑一次就多一組桌布、主畫面變純色 | 沒指定 `WFSelectedPoster` 時會新建一組桌布 | 先「取得目前桌布」，再更新同一組 |
| App 不再跳安裝頁 | 舊的「已安裝」狀態被記住了 | 狀態鍵改名（目前 `sw.readyTargets6`）。捷徑有改版時要再改一次，讓使用者重裝 |

### 尚未解決或未確認

- **主畫面模糊**：主畫面設成「Abbinata」（配對）時，用捷徑換圖後 iOS 會強制開啟模糊（Sfocatura）。`WFWallpaperLegibilityBlur = false` 沒有效果。
- **v2.4 的「兩者」**：先設鎖定畫面，再把主畫面單獨設成同一張照片（Location = Home Screen）。這是最後一個嘗試，使用者還沒回報結果。
- **退路**：存相簿 → Foto → 分享 → Usa come sfondo，手動設主畫面。
- `posters.get` 的 `WFPosterType = "Current"`：在使用者的 iPhone 上可以運作（v2.2 之後沒再新增桌布）。

### 使用者裝置的特殊點

- 系統語言是**義大利文**。說明文字要寫義大利文的選項名稱，例如：Comandi rapidi、Aggiungi comando rapido、Sostituisci、Consenti sempre、Impostazioni → Sfondo、Abbinata／Colore／Gradiente／Foto、Sfocatura、Fine。
- 使用者**沒有 Mac 或電腦**，一切都要做成一鍵安裝。

---

## 4. 壁紙系列

| 編號 | 系列 | 格式 | 來源 |
|---|---|---|---|
| 1–10 | 都市潮流 | PNG | `design-src/*.dc.html` |
| 11–20 | 黃綠系列 | PNG | `design-src/L1x*.dc.html` |
| 21–32 | 街頭新番 | JPEG q88（每張約 0.6MB） | `design-src/neo/_gen.py` |
| 33–82 | 霓虹街區 | JPEG q86（每張約 250KB） | `design-src/neo2/_gen.py` |

「霓虹街區」共 10 類：霓虹招牌、票券、警告標誌、復古科技、漫畫音效、路牌、貼紙、大字海報、像素城市、幾何圖案。

**配色規則（使用者明確要求）**：黑底、深灰，加上**偏黃的螢光黃綠**：`#D4FF1A`、`#EAFF3A`、`#F7FFB3`、`#C2EE14`。**不要用墨綠或橄欖綠當背景**（使用者說那是「單純的綠色」）。`_gen.py` 裡的 `recolor()` 會把殘留的彩色自動轉成黃綠色階。

### 新增壁紙的流程

1. 在 `_gen.py` 加設計（畫布 390×844 CSS px；上方 y 90–260 是鎖屏時鐘區，要留空）。
2. 執行：
   ```
   python3 design-src/neo2/_gen.py
   node design-src/neo/render.js design-src/neo2 <輸出資料夾>
   ```
   會輸出 1170×2532 的圖（需要 Playwright 與 Chromium）。
3. 存成 `StreetWall/Resources/Wallpapers/wpNN.jpg`，再存一張 390×844 的 `wpNN_thumb.jpg`。
4. 在 `Model.swift` 的 `Catalog.all` 加一列，並更新 `Intents.swift` 的編號上限。

---

## 5. 建置 IPA

### 方法 A：GitHub Actions（目前的做法）

- push 到分支就會自動跑 `.github/workflows/build-ipa.yml`，使用 `macos-15` runner。
- 產物會發到 Releases，tag 是 `build-<run>-<attempt>`；也會上傳成 Artifact。
- 捷徑簽名：先試 `shortcuts sign`（CI 沒登入 iCloud，會失敗），再改用 `scripts/hubsign.sh`。
- 需要 Actions 能跑（見文件開頭的帳單問題）。

### 方法 B：自己的 Mac

```bash
brew install xcodegen
for k in lock home both auto; do python3 scripts/make_shortcut.py $k /tmp/$k.shortcut; done
# 各自簽名（Mac 已登入 iCloud 時）：
shortcuts sign --mode anyone --input /tmp/lock.shortcut --output StreetWall/Resources/潮流換壁紙.shortcut
shortcuts sign --mode anyone --input /tmp/home.shortcut --output StreetWall/Resources/潮流換壁紙主畫面.shortcut
shortcuts sign --mode anyone --input /tmp/both.shortcut --output StreetWall/Resources/潮流換壁紙兩者.shortcut
shortcuts sign --mode anyone --input /tmp/auto.shortcut --output StreetWall/Resources/潮流自動換壁紙.shortcut
xcodegen generate
open StreetWall.xcodeproj   # 用自己的 Apple ID 簽名後直接裝到 iPhone
```

---

## 6. 版本紀錄（摘要）

| 版本 | 內容 |
|---|---|
| 1.0 | 20 張壁紙、頻道／片庫／自動 UI、App Intents |
| 1.1 | 一鍵套用改用 x-callback，加安裝說明頁 |
| 1.2–1.8 | 內建簽名捷徑；修動作 ID、改剪貼簿傳圖、拿掉 If |
| 2.0 | 鎖定／主畫面／兩者三個捷徑、自動換壁紙捷徑、12 張「街頭新番」、生成器大改 |
| 2.1 | 主畫面一次性設定說明頁 |
| 2.2 | 改成更新目前桌布，不再新增 |
| 2.3 | 關閉 Legibility Blur |
| 2.4 | 「兩者」把主畫面單獨設成同一張（最後一個發出的 IPA） |
| 2.5 | 50 張「霓虹街區」（JPEG）；App 支援 JPEG |
| 2.6 | 50 張改成黑底 + 偏黃的螢光黃綠；21–32 也改存 JPEG，原始碼縮到 30MB 以內（未建置，見文件開頭） |
