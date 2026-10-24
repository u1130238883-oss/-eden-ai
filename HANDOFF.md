# Hollow（空洞占卜）交接文件

最後更新：2026-10-24
最新分支：`claude/hollow-ipa`（因 GitHub 帳號多次切換，曾推送至下列倉庫，內容以本壓縮檔為準）
- `u1130238883-oss/-1.-mkdir-my-project-cd-my-project-2.-Git-git-init-`（最新，含合盤 VS 橫幅）
- `zc2694437-sudo/ZcA304`（到「貴人」為止）
- `zahanchangyuan-sudo/miro`、`changyuanzhang006-sketch/-`（較舊，已無法存取）
- 最早的原始分支：`claude/persona5-fortune-app-g8om8v`（`zc2694437-sudo/ZcA304`）

---

## 1. 專案概要

| 項目 | 內容 |
|---|---|
| App 名稱（桌面顯示） | **Hollow** |
| 類型 | iOS 算命 App（SwiftUI） |
| 最低系統 | iOS 16.0，iPhone / iPad |
| 算法 | 完整沿用原版 **Nine & Twelve（九型十二宮）**，由原版 IPA 反編譯還原 |
| 風格 | 《絕區零》街頭霓虹風：黑底、螢光黃綠（lime）、橘、青，警示條紋、電視螢幕卡片 |
| 語言 | 繁體中文、English、Español、Italiano（「我」頁切換，會記住） |
| 資料儲存 | 只存在本機 `UserDefaults`，不上傳 |
| 發佈形式 | **未簽名 IPA**，需以 Sideloadly / AltStore / TrollStore / 簽名工具自行簽名安裝 |
| Bundle ID | `com.phantomthieves.fortune`（專案 target 名稱沿用早期的 `Persona5Fortune`） |

---

## 2. 畫面與功能

底部五個分頁（只有「今天」在啟動時建立，其他分頁第一次點開才建立，之後常駐）：

1. **今天**
   - 右上角日曆按鈕可切換任意日期。
   - 日宮（大卡片）、夜宮。
   - 流月、流年、大運三張卡：顯示「N宮・宮名」＋「好/正/壞 X 因 Y」＋果←因。點開看詳情。
2. **運勢**：流月 / 流年 / 大運
   - 流月：年份切換 ‹ › ，列 12 個月。
   - 流年：年份切換 ‹ › ，從所選年份起列 12 年，今年以綠底標示。
   - 大運：列 10 段大運，目前所在段綠底。
   - 點任一列 → 詳情頁；流年／大運的詳情頁內含「引動」清單（見 §3.7），大運另含「這一段大運的十二個方面」，每一項都可再點開。
3. **命盤**：九型人格（靈數對應型號）＋本命十二宮；點任一宮 → 詳情頁內含「本命宮引動的本命宮」（見 §3.7）。
4. **合盤**：輸入對方名字＋生日 → 頂部絕區零風「合盤橫條」：左＝合盤靈數（兩人靈數相加化約到 1…9）、中＝「本人 & 對方」、右＝合盤命宮（宮位＋宮名，即合盤十二宮第一列）；下方合盤十二宮；保留最近 20 筆。
5. **我**：語言、名字、生日、十二宮含義（可搜尋）、進階設定（年錨、清除資料）。

判讀顯示格式（依原版）：

| 語言 | 格式 | 例 |
|---|---|---|
| 繁中 | `{好/正/壞}{果}因{因}` | 好6因8 |
| English | `{Favorable/Aligned/Adverse} {果} from {因}` | Favorable 6 from 8 |
| Español | `… {果} de {因}` | Favorable 6 de 8 |
| Italiano | `… {果} da {因}` | Favorevole 6 da 8 |

依使用者要求，**畫面不顯示年、月、日三柱的數字**，只顯示宮位與判讀。

---

## 3. 算法規格（`Engine.swift`）

以下皆為整數運算。

### 3.1 化約函式
- `r12(n) = ((n − 1) mod 12) + 1` → 1…12
- `r9(n)  = ((n − 1) mod 9) + 1` → 1…9
- `lifeDigit(n)`：反覆相加各位數直到剩一位；結果 0 視為 9。

### 3.2 三柱與靈數
- 出生年、月、日各自 `lifeDigit` → 三柱 `T = (y, m, d)`（再經 `r12`）。
- 三柱相加：`T1 + T2 = (r12(y1+y2), r12(m1+m2), r12(d1+d2))`
- 靈數 `L = lifeDigit(y + m + d)`；九型人格型號 = `r9(L)`。

### 3.3 宮位五行
| 宮 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 五行 | 火 | 金 | 水 | 水 | 火 | 水 | 金 | 火 | 木 | 土 | 土 | 木 |

相生：金→水→木→火→土→金；相剋：金剋木、木剋土、水剋火、火剋金、土剋水。

### 3.4 判讀（一列三柱 → 好/正/壞、果、因）
令 `yE = 五行(y)`, `mE = 五行(m)`, `a = r12(y + d)`, `b = r12(m + d)`：

| 關係 | 判讀 | 果 | 因 |
|---|---|---|---|
| yE = mE（同行） | 正 | d | r12(a + b) |
| 年生月 | 好 | b | a |
| 月生年 | 好 | a | b |
| 年剋月 | 壞 | b | a |
| 月剋年 | 壞 | a | b |

（原版資料結構順序為 verdict, result(果), cause(因)。）

### 3.5 排盤
`chart(start, T0)`：第 i 列（i = 0…11）宮位 `r12(start − i)`，三柱 `T0 + i`（三柱各加 i），判讀依 §3.4。

- **本命盤**：`chart(L, T + 1)`；第 0 列即命宮（= 靈數宮）。
- **合盤**：`T合 = T甲 + T乙`，`L合 = lifeDigit(Σ T合)`，`chart(L合, T合 + 1)`。
- **合盤靈數**（畫面頂部大數字）：`r9(L甲 + L乙)`，即兩人靈數相加後化約到 1…9。注意它與上面排盤用的 `L合` 不一定相同。

### 3.6 年、大運、月、日
- **年對應列**（年錨）：
  - 依出生年（預設）：`row(Y) = (Y − 出生年 + 1) mod 12`
  - 固定 2017：`row(Y) = (Y − 2017) mod 12`
- **流年**：本命盤第 `row(Y)` 列。
- **大運**：第一段 `出生年 … 出生年 + 8 − (L mod 9)`，之後每段 9 年；該段的列 = 流年(起始年)。
- **大運十二方面**：由大運「**結束年**」所在列 `k = row(結束年)` 起，第 N 方面 = 本命盤第 `(k + N − 1) mod 12` 列，**第 N 方面即 N 宮**。
- **流月**：`chart(r12(流年宮位 − 1), 大運三柱 + 流年三柱)`，第 i 列 = 第 i+1 月。
- **日運**：`S = 月的各位數和 + 日的各位數和`
  - 日宮 = `r12( r12(L + r12(L + 月)) + S )`
  - 夜宮 = `r9(L + S)`

### 3.7 引動
- **流年引動大運方面**：在該年所屬大運的十二方面中，果 **或** 因 = 流年宮位者。
- **大運引動本命宮**：本命十二宮中，果 **或** 因 = 大運宮位者。
- **本命宮引動本命宮**：點命盤某一宮 P，其他本命宮中果 **或** 因 = P 者（不含 P 本身）。例：2006-01-14 的 9 宮引動 2宮好2因9、8宮壞9因2。
- 沒有引動時，詳情頁不顯示該區塊。

### 3.8 驗證範例（2006-01-14）
本命：5宮壞3因8、4宮壞10因5、3宮壞12因7、2宮好2因9、1宮壞11因4、12宮正11因7、11宮壞8因3、10宮好10因5、9宮好12因7、8宮壞9因2、7宮壞4因11、6宮正5因7

| 項目 | 結果 | 引動 |
|---|---|---|
| 2025 流年 | 9宮 好12因7 | 6宮好2因9、12宮壞9因2 |
| 2026 流年 | 8宮 壞9因2 | 3宮壞3因8、9宮壞8因3 |
| 2019–2027 大運 | 3宮 壞12因7 | 本命 5宮壞3因8、11宮壞8因3 |

修改算法後，請用此例核對。

---

## 4. 內容資料（`NineTwelveData.swift`）

- 十二宮簡稱、十二宮關鍵詞、九型人格（名稱、標語、概述、7 個段落）四種語言，**逐字擷取自原版 App**。
- 陣列第一層索引為語言：`0 繁中、1 English、2 Español、3 Italiano`。
- 使用者追加的關鍵詞（四語皆加）：
  - 3 宮：「思想」（在「思考」之後）、「精神」（在「新鮮感」之後）；「同桌」改為「同胞」
  - 5 宮：「被看見」（在「父親」之前）
  - 6 宮：「反覆」（在「重複的事情」之後）
  - 11 宮：「貴人」（最後）
  - 12 宮：「欺騙」（最後）
- 十二宮的生活化主題名稱（如「戀愛・桃花」）與介面文字為本專案自行撰寫／翻譯，放在 `Plain.swift`、各畫面檔案的 `L("中","英","西","義")` 中。

---

## 5. 程式結構

```
project.yml                 XcodeGen 專案設定（名稱、Bundle ID、Info.plist 鍵）
Support/Info.plist          啟動畫面設定（LaunchBackground 顏色＋LaunchLogo 圖）
.github/workflows/build-ipa.yml
                            推送後在 macOS 上產生未簽名 IPA，並提交回 dist/
Persona5Fortune/
  App.swift        入口、分頁容器（延遲載入）、底部分頁列、首次設定畫面、生日選擇器
  Tabs.swift       五個分頁：今天、運勢、命盤、合盤、我
  Plain.swift      判讀標籤、列表列、詳情頁、引動區塊、共用詞彙 Words、十二宮主題名
  Engine.swift     算法（§3）、語言 Lang 與 L()、宮位與九型存取
  Store.swift      使用者資料（本人、合盤紀錄、年錨、語言）存取 UserDefaults
  Theme.swift      絕區零風格元件：配色 Z、警示條紋、卡片、電視螢幕、按鈕、年份切換、分段選擇
  NineTwelveData.swift  四語內容資料（§4）
  Assets.xcassets  App 圖示、強調色、啟動畫面資源
dist/Persona5Fortune.ipa    CI 產生的最新未簽名 IPA
```

---

## 6. 建置與安裝

### 自動（目前使用）
推送到任何分支 → GitHub Actions（macos-15）執行：
1. `brew install xcodegen` → `xcodegen generate`
2. `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`
3. 打包 `Payload/Persona5Fortune.app` → `dist/Persona5Fortune.ipa`，上傳 artifact 並提交回分支（`[skip ci]`）

### 本機（需要 Mac＋Xcode 16 以上）
```sh
brew install xcodegen
xcodegen generate
open Persona5Fortune.xcodeproj
```
在 Xcode 選自己的開發者帳號即可直接裝到手機；或照 workflow 指令產生未簽名 IPA。

---

## 7. 常見修改

| 想改 | 位置 |
|---|---|
| App 名稱 | `project.yml` → `INFOPLIST_KEY_CFBundleDisplayName`；首次設定畫面標題在 `App.swift`（`Text("Hollow")`） |
| Bundle ID | `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` |
| 配色 | `Theme.swift` → `enum Z`（lime、orange、cyan、pink…）；好/正/壞顏色在 `Plain.swift` → `Verdict.color` |
| 宮位關鍵詞 | `NineTwelveData.swift` → `PalaceData.keywords[語言][宮-1]`（四種語言都要改） |
| 十二宮主題名 | `Plain.swift` → `Topic.title` |
| 介面文字／翻譯 | 搜尋 `L("` ，四個參數依序為 繁中、英、西、義 |
| App 圖示 | `Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024×1024，不透明） |
| 啟動畫面 | `Support/Info.plist`、`LaunchBackground.colorset`、`LaunchLogo.imageset` |
| 算法 | `Engine.swift`，改後以 §3.8 範例核對 |

---

## 8. 已知事項與限制

- **未在實機以外環境測試**：每次都有在 CI 成功編譯，但畫面與流暢度僅由使用者在實機確認。
- **合盤橫條（`Theme.swift` 末尾 `Slant`、`SynastryBar`；`Tabs.swift` 的 `MatchTab.result`）尚未編譯驗證**，只在本壓縮檔中；第一次編譯若出錯從這裡查。若失敗，看 Actions 日誌；
- **GitHub 帳號常切換**：每切換一次，之前的倉庫就推不上去。新倉庫只要放入本原始碼，推送任何分支就會自動編譯 IPA（需該帳號 Actions 額度未用完）。
- **App 圖示**是依截圖重繪的「空洞命書」電視圖示；如有原始圖檔可直接替換。
- **夜宮**原版只算到 1…9，目前以宮位（1…9 宮）呈現。
- 內部 target／檔名仍叫 `Persona5Fortune`（早期版本名稱），不影響使用；若要改名需同步修改 `project.yml` 與 workflow 內的路徑。
- IPA 為未簽名，免費 Apple ID 自簽的 App 通常 7 天需重簽。

---

## 9. 版本歷程（摘要）

1. P5 風格塔羅算命（初版，後廢棄）
2. 改為沿用原版 Nine & Twelve 算法（反編譯還原引擎與內容）
3. 隱藏年月日數字；改為絕區零風格、白話化、底部分頁
4. 判讀改回「好X因Y」；配對改名合盤
5. 修正果／因順序
6. 日期切換、流月/流年命名、引動加入詳情
7. 四語切換；App 改名 Hollow
8. 宮位標示補齊、引動僅在詳情、分頁切換流暢化；空洞命書圖示
9. 啟動加速（延遲載入分頁、品牌啟動畫面）
10. 關鍵詞追加（被看見、反覆、欺騙）；引動規則依原版修正（果或因、大運方面由結束年起排）
11. 流年加年份切換；合盤配色改為螢光黃綠
12. 3 宮關鍵詞：「思考」後加「思想」、「新鮮感」後加「精神」、「同桌」改「同胞」（英 Ideas/Spirit/Compatriots，西 Ideas/Espíritu/Compatriotas，義 Idee/Spirito/Compatrioti）；命盤加入本命宮引動
13. 合盤移除好/正/壞數量與「合盤命宮」
14. 11 宮關鍵詞最後加「貴人」（Benefactors / Benefactores / Benefattori）
15. 合盤頂部改為絕區零風 VS 對戰橫幅
16. 合盤加入「合盤靈數」（兩人靈數相加化約到 1…9）
17. 合盤頂部依使用者草圖改為單列橫條：合盤靈數｜名字｜合盤命宮（取代 VS 橫幅）
