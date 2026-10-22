# 九型十二宮 — 專案交接（貼給新的 Claude 對話用）

> 使用者說明：我把這份文件連同 `ninetwelve-source-2026-09-24.zip` 一起給你。
> 請先把 zip 解開，那就是完整的專案，**已經包含我最近這一輪請人改好的全部東西**。
> 以下是你需要知道的全部背景。
>
> 這份文件最後更新：2026-09-24（第六輪）。

---

## 零、最重要的三件事

1. **這套算命方法是我自己發明的，是我吃飯的本事。**
   介面上**絕對不可以出現任何洩露計算方法的文字** —— 不可以寫「年柱剋月柱所以是壞」、
   不可以寫「取十二進制餘數」、不可以寫「果加因等於幾」、
   不可以寫「因為流年走8宮，所以引動因8的方面」。
   只呈現**結果**：第幾宮、好／正／壞、果與因落在哪一宮、那些宮位的含義。
   新加任何畫面都要守這條。

2. **絕對不可以自己發明命理規則。**
   所有規則都來自我的原始文件或我親口說的例子，程式裡的每一條都有對應的範例測試。
   看不懂或文件沒寫的，**問我**，不要猜、不要「合理推論」。

3. **給我連結時，要把完整網址單獨列一行。**
   我看不到 markdown 的連結語法（`[文字](網址)` 對我來說是隱形的）。

---

## 一、這是什麼

《九型十二宮算命系統方法》—— 我自創的命理系統，做成 iOS + Android App。
輸入出生年月日排出命盤，推算大運、流年、月運、白天日運、晚上日運，以及兩人合盤。

- **iOS**：SwiftUI，最低 iOS 16
- **Android**：Kotlin + Jetpack Compose，minSdk 24 / compileSdk 35
- **兩個平台共用同一套演算法**，用同一組測試案例驗證，算出來必須一模一樣
- 另外還有一個**會員制網站**（純 Python 標準函式庫，零套件），在 `web/`

### ★ 我現在要的成品：只要一個 IPA

**從 2026-09-23 起，我只要一個 iOS 的 IPA**：

- 四種語言（繁體中文／English／Español／Italiano）都在同一個 App 裡，
  **在「設定 → 語言」裡直接切換**
- 完全解鎖（沒有付費機制）
- bundle id：`com.ninetwelve.fortune.free`（會蓋掉手機上原本的中英解鎖版，這是對的）
- GitHub Actions 上的成品名稱：`NineTwelve-4lang-FREE-ipa`

**不要再編 APK 了。** `android-build.yml` 已經改成只能手動觸發（推送時不會跑），
Android 的程式碼還是跟著同步改，只是不編成品。

程式裡的做法：`Lang.available` 多了一個 `LOCALE_ALL` 旗標，帶這個旗標建置時四種語言全開。
`ios-build.yml` 用 `SWIFT_ACTIVE_COMPILATION_CONDITIONS="LOCALE_ALL UNLOCKED"`、
`NINETWELVE_LANGS="zh-Hant en es it"` 只編這一個。
主畫面上的 App 名稱**四種語言都叫 Nine & Twelve**（2026-09-23 第三輪改的；原本是跟著語言換）。
設定頁「語言」下面那行說明已經拿掉。

舊的兩語版本（中英、西義、付費版）程式裡都還在，只是 CI 不再編它們。

---

## 二、GitHub 帳號與倉庫

**GitHub Actions 的分鐘數是算在「倉庫擁有者」頭上，不是算在推送的人頭上。**
所以只換一個帳號來推送**沒有用**，一定要在**新帳號底下建一個新倉庫**。

### 用過、額度都用完或已經不能用的

| 帳號／倉庫 | 狀況 |
|---|---|
| `u1130238883-oss/-1.-mkdir-my-project-cd-my-project-2.-Git-git-init-` | 額度用完 |
| `zhangchangyuan036-eng/036-` | 額度用完（main 是另一個專案 Parole in Tasca） |
| `changyaunzhang-commits/-` | 額度用完（main 是另一個專案 MeVoice） |
| `zahanchangyuan-spec/minrifumknri` | 2026-09-23 用過（分支 `claude/annual-transit-palace-trigger-x02hyh`），第二輪要推的時候已經連不到了 |
| `miro25114728-star/miro-loveou` | 2026-09-23 用過第三～五輪（分支 `claude/ipa-distribution-toqxr0`），2026-09-24 倉庫已經不見了（not found） |

⚠️ 要推到新倉庫之前，先確認那個倉庫是乾淨的；如果裡面已經有別的專案，**先問我**，不要混在一起。

### 新帳號要做的事

```bash
# 1. 在新帳號建一個空的 private 倉庫
# 2. 解開 zip，進到資料夾
git init
git add -A
git commit -m "九型十二宮：iOS + Android + 網站"
git branch -M main
git remote add origin https://github.com/<新帳號>/<新倉庫>.git
git push -u origin main
```

推上去之後會自動跑：

| 流程 | 跑在 | 產出 |
|---|---|---|
| `ios-build.yml` | macOS | **一個** IPA（四語解鎖版） + 單元測試 |
| `web-test.yml` | Ubuntu | 網站的檢查 |
| `android-build.yml` | — | 不會自動跑（要手動按 Run workflow） |

**額度**：免費帳號每月 2000 分鐘，macOS 是 10 倍計費。
現在只編一個 IPA，一輪大約 5 分鐘實際時間 ≈ 50 分鐘額度，一個月大約可以編 35～40 次。
**不要為了小改動反覆推送；能一次改完再推。**
成品 90 天後過期，編完記得早點下載。

---

## 三、演算法（絕對不能改，只能照抄）

三個平台各一份實作，**內容必須完全一致**：

```
ios/NineTwelve/Engine/                                      Swift
android/app/src/main/java/com/ninetwelve/fortune/engine/    Kotlin
web/server/engine.py                                        Python（網站用）
```

### 驗證腳本（改任何東西之前、之後都要跑）

```bash
python3 tools/verify_algorithm.py     # 用原始文件的範例驗算法
python3 tools/verify_web_engine.py    # 網站引擎和 App 算出來一樣（含「引動」）
python3 tools/test_web.py             # 網站檢查
python3 tools/check_pbxproj.py        # Xcode 專案檔結構
python3 tools/parse_pbxproj.py        # Xcode 專案檔語法／語意
```

### 幾個容易踩到的重點

- **大運十二方面**：以該段大運**最後一年**的年運為第一宮，往下接滿十二宮；
  第 N 宮就用第 N 宮的含義去讀。入口是運程頁大運卡片左邊那個宮位圓圈。
  詳情頁也要用「第幾個方面」那一宮去讀，不是那一列本命的宮位。
- **摘要（brief）取前四個關鍵字，但要跳過和宮位簡稱相同的那一個**，往後遞補。
- **九型人格**的資料只有一份：`tools/enneagram_data.py`，
  用 `python3 tools/gen_enneagram.py` 產生 Swift 和 Kotlin，CI 會檢查有沒有同步。

---

## 四、引動（2026-09-23 新增）

### 規則（我親口說的，2026-09-28 改過）

- **流年引動大運**：某一年走第 X 宮 → 在「那一年所屬大運的十二個方面」裡，
  找出**因 = X 或 果 = X** 的每一項，就是被引動的。以「第幾個方面」那一宮去讀。
- **大運引動本命**：某一段大運走第 X 宮 → 在**本命盤**裡，
  找出**因 = X 或 果 = X** 的每一列，就是被引動的。以本命盤的宮位去讀。
- （2026-09-23 原本只看「因 = X」，2026-09-28 使用者舉例改成因或果都算。）
- **本命引動本命**（2026-10-20 新增）：本命盤第 X 宮 → 在本命盤裡找出**因 = X 或 果 = X** 的每一列。
  例：2006-01-14 本命 9宮 → 2宮 好2因9、8宮 壞9因2。命盤頁每一列的詳情多一張「引動本命」，
  點圓圈：有引動就只開引動，沒有就開完整詳情（跟流年一樣）。
  ⚠️ 照規則，本命 2宮（好2因9）和 10宮（好10因5）會引動到自己那一列，還沒問過要不要排除。

### 我的例子（2006年1月14日生，全部寫進了測試）

| 點開 | 走 | 引動 |
|---|---|---|
| 2025 流年 | 9宮 好12因7 | 大運(2019–2027) 6宮 好2因9、12宮 壞9因2 （使用者的例子） |
| 2026 流年 | 8宮 壞9因2 | 大運(2019–2027) 3宮 壞3因8、9宮 壞8因3 （使用者的例子） |
| 2027 流年 | 7宮 壞4因11 | 大運(2019–2027) 2宮 正5因7、5宮 壞12因7、8宮 正11因7、11宮 好12因7 |
| 2029 流年 | 5宮 壞3因8 | 大運(2028–2036) 1宮 好10因5、5宮 正5因7、7宮 壞10因5 |
| 大運 2019–2027 | 3宮 壞12因7 | 本命 5宮 壞3因8、11宮 壞8因3 （使用者的例子） |
| 大運 2010–2018 | 12宮 正11因7 | 本命 3宮 壞12因7、9宮 好12因7 |
| 大運 2028–2036 | 6宮 正5因7 | 沒有（卡片不顯示） |

### 畫面

- 點開流年 → 詳情頁第三張卡「引動大運」（副標是那段大運的年份）
- 點開大運 → 詳情頁第三張卡「引動本命」
- 每一項可以再點開，看那一宮的完整詳情
- **沒有引動的時候，整張卡不顯示**（我叫人拿掉「沒有引動」那張空卡）
- 能點開流年的地方：流年列表每一列、今日頁的流年卡
- 能點開大運的地方：大運卡片、一生大運時間軸、十二方面最上面那張卡、今日頁的當前大運
- 網站的引擎也有 `triggered_aspects` / `triggered_natal_rows`，
  但**網站畫面還沒顯示引動**（網站本來就沒有點開流年／大運的詳情頁）。要不要加，問我。

### 程式位置

```
ios/NineTwelve/Engine/Fortune.swift            triggeredAspects(forYear:) / triggeredNatalRows(for:)
ios/NineTwelve/Views/ChartTable.swift          TriggerList、TriggerCard、RowDetailView(triggers:)
android/.../engine/Fortune.kt                  triggeredAspects / triggeredNatalRows
android/.../ui/ChartTable.kt                   TriggerList、TriggerCard、RowDetailSheet(triggers=)
web/server/engine.py                           triggered_aspects / triggered_natal_rows
```

---

## 五、十二宮含義要怎麼改（有個坑，一定要看）

十二宮含義一共有**三份**：

```
ios/NineTwelve/Engine/PalaceMeanings.swift                        Swift
android/.../com/ninetwelve/fortune/engine/PalaceMeanings.kt       Kotlin
web/server/palace_data.py                                         Python（網站用）
```

流程：

1. 編輯 `tools/patch_palace.py` 最上面的 `NEW_ZH`（只列有改動的宮，寫**整宮的新清單**），
   新出現的詞要在 `NEW_TERMS` 補上英／西／義三種譯法。
2. 跑 `python3 tools/patch_palace.py` —— 它會同時重寫 **Swift 和 Kotlin**。
3. **坑**：它**不會**改 `web/server/palace_data.py`（檔頭說的 `tools/gen_palace_py.py` 不存在），
   要自己寫回去，不然網站是舊的，而且下次跑 `patch_palace.py` 會把新改的蓋回去：

```python
import io, sys
sys.path.insert(0, "tools"); sys.path.insert(0, "web/server")
import patch_palace as PP
table = PP.build()
path = "web/server/palace_data.py"
src = io.open(path, encoding="utf-8").read()
start = src.index("KEYWORDS = {"); end = src.index("\n}\n", start) + 3
out = ["KEYWORDS = {"]
for lang in ("zh", "en", "es", "it"):
    out.append("    '%s': [" % lang)
    for row in table[lang]:
        out.append("        %r," % (list(row),))
    out.append("    ],")
out.append("}\n")
io.open(path, "w", encoding="utf-8").write(src[:start] + "\n".join(out) + src[end:])
```

4. 再跑一次 `python3 tools/patch_palace.py`，`git diff` 應該沒有變化（代表三份一致）。

如果覺得應該把 `gen_palace_py.py` 補起來，**先問我**再動手。

### 最近新增的含義

| 宮 | 新增（都接在該宮最後面） | 英 / 西 / 義 |
|---|---|---|
| 3宮 | 活力 | Liveliness / Vivacidad / Vivacità |
| 3宮 | 新鮮感 | A sense of novelty / Sensación de novedad / Senso di novità |
| 3宮 | 甲狀腺（**3宮的最末尾**） | The thyroid / La tiroides / La tiroide |
| 12宮 | 隔絕 | Being cut off / Estar aislado del mundo / Essere tagliati fuori |
| 12宮 | 隱匿 | Hiding away / Ocultarse / Nascondersi |
| 2宮 | 價值觀、認知、動力、口腔 | （見 patch_palace.py） |
| 8宮 | 別人的隱私和隱秘、別人的私生活、隱耗、生存、體力、精力、健康情況 | |
| 9宮 | 盲目、自大、意義、機遇、機會（機遇、機會從 11宮 搬來） | |

（12宮原本就有「隔離＝Isolation」「隱藏＝Concealment」，所以隔絕、隱匿用了不同的譯法避免重複。）

現在各宮的條目數：`[9, 10, 25, 16, 12, 18, 12, 19, 26, 24, 16, 30]`

---

## 六、Xcode 專案檔是「產生」出來的

`ios/NineTwelve.xcodeproj/project.pbxproj` 由 `python3 tools/gen_xcodeproj.py` 產生。
**新增或刪除任何 .swift 檔之後一定要重新產生**，否則 CI 會擋下來。
只改現有檔案內容就不用。

---

## 七、網站（`web/`）

```bash
NT_ADMIN_PASSWORD=你的密碼 python3 web/server/app.py
# 打開 http://localhost:8000
```

- 四種語言，介面文字在 `web/server/content.py`
- 方案：`p10` ¥10/5天、`p20` ¥20/15天、`p30` ¥30/30天
- 收款：「訂單編號 + 後台手動確認」
- **網站是唯一真正保護算法的做法**（App 可以被反編譯）。
  之前提過把 App 改成「瘦客戶端」，**我還沒決定，可以再提醒我一次。**

---

## 八、絕對不可以進版控的東西

- 我的**微信／支付寶收款碼圖片**（現在都是佔位圖）
- 我的 **Apple 帳號 email**
- 啟用碼的**簽章金鑰**（版控裡永遠是 `CHANGE-ME-BEFORE-RELEASE`）
- 會員資料庫 `*.sqlite3`、後台密碼

---

## 九、和我合作的方式

- **我叫你改什麼就改什麼，不要順手改別的。** 看到旁邊有問題，**先跟我講**。
- **連結一定要完整網址單獨列一行。**
- 我人在義大利，講繁體中文。
- 我改完東西就是要**成品**：現在是**一個 IPA** 的下載連結。不用問我要不要，直接編好給我。
- **介面上不要自作主張加東西**（加過小箭頭，對不齊，被我叫人拿掉）。
- Claude 在雲端環境**沒辦法自己編譯 iOS**（要 Mac），一定要靠 GitHub Actions。
- 有些環境連不到成品下載主機，給我 GitHub 上的連結就好。
- 如果 GitHub 額度又用完了：把改好的**原始碼 zip + 更新過的這份交接文件**給我。

---

## 十、2026-09-23～24 改了什麼（六輪）

第一輪：
1. 新增「引動」（見第四節），三份引擎同步、加測試。

第二輪：
1. 3宮加「活力、新鮮感、甲狀腺」（甲狀腺在最末尾），12宮加「隔絕、隱匿」。
2. 沒有引動時，整張「引動」卡片不顯示。
3. 只編一個四語解鎖版 IPA；四種語言在設定裡直接切換；Android 不再自動編。

第一輪在 `zahanchangyuan-spec/minrifumknri` 上 Build IPA、Build APK、Test Web 三個都綠。
**第二輪還沒在 CI 上編過**（推的時候倉庫已經連不到）。本機五個驗證腳本全過，
但 Swift 程式沒有實際編譯過，新的 Claude 推上去之後要看 Build IPA 是不是綠的。
第二輪動到的 Swift：`Localization.swift`（`LOCALE_ALL`）、`ChartTable.swift`（空的引動卡不顯示）、
`PalaceMeanings.swift`（產生的）。

---

第三輪（在 `miro25114728-star/miro-loveou`，分支 `claude/ipa-distribution-toqxr0`）：
1. 命盤、合盤結果、流年、月運列表每列右邊的「›」拿掉（整列照樣可點開）。
   合盤頁「最近合過的人」名單的「›」還在，沒叫拿。
2. 運程頁「大運怎麼排」那張卡拿掉。
3. 主畫面名稱四語都叫 Nine & Twelve；設定 → 語言下面那行字拿掉。
Build IPA、Test Web 都綠。

第四輪：試過「星穹鐵道」深色風格，使用者覺得不好看，已經換掉。

第五輪：iOS 改成白色系新設計（版面、字級、顏色都重排）。
先試了靛藍紫，使用者不喜歡紫色，改成使用者選的「深海藍＋金」：
暖白頁面底（#FAF7F2）＋白色圓角卡片加柔和陰影、深海藍主色（#1E3A5F）、金色點綴（#C9A24D）、
標題與大數字用襯線字、固定淺色模式。
今日頁頂部是深海藍卡片＋金色靈數圈；白天日運是淡金卡、晚上日運是深海藍卡；
**命盤與合盤的十二宮改成三欄方格**（`ChartTable(grid: true)`），流年、月運仍是一列一列；
宮位標記改成淡五行色底＋彩色數字；判定標籤小的是淡底彩字、大的是實心；
運程頁的大運／流年／月運切換改成膠囊按鈕。
共用外觀在 `ios/NineTwelve/Views/Palette.swift`（Theme、CardShape、CardBackground、PageBackground、
SectionLabel、PrimaryButtonLabel）與 `Components.swift`。
另外修了年份顯示成「2,019」「2,000」有千分位逗號的問題（`Text(verbatim:)`）。

**自動截圖**：`ios-build.yml` 最後一步在模擬器上截每一頁，推到 `screenshots` 分支（[skip ci]）。
用的是 Debug 版才有的啟動參數：`-uiDemo YES`（放示範資料 2006-01-14，合盤放 1990-06-15）、
`-uiTab N`（開哪一頁）、`-uiSeg year|month`（運程頁哪一段）。這些都包在 `#if DEBUG`，IPA 裡沒有。
抓截圖：`git fetch origin screenshots`。
Android 還是舊的樣式，沒同步。
第五輪在 `miro25114728-star/miro-loveou` 上 Build IPA、Test Web 都綠，截圖也看過。

第六輪（2026-09-24，倉庫已經不見，**沒有在 CI 上編過**）：
1. 合盤頁輸入對方資料時，「稱呼」改成「稱呼：」（四語：稱呼：／Name:／Nombre:／Nome:），
   並拿掉「例如：自己」的提示字。
   做法：`BirthInputView` 多一個 `forOther` 參數，只有合盤頁傳 `forOther: true`；
   第一次開 App 的輸入畫面和設定裡的「修改出生資料」都沒動。Android 沒同步。
   只改了這兩個 Swift 檔：`Views/BirthInputView.swift`、`Views/SynastryView.swift`。
   新的 Claude 推上去之後要看 Build IPA 是不是綠的，也可以看 `screenshots` 分支的 `6-synastry.png`。

第七輪（2026-09-24，倉庫 `zc2694437-sudo/ZcA304`，分支 `claude/ipa-file-delivery-1ehiuk`）：
1. 第六輪原樣推上去，Build IPA 綠。
2. 使用者說「改成之前沒有改過顏色的」：只改顏色，版面（三欄方格、襯線字、膠囊按鈕）沒動。
   舊的 iOS 程式已經找不到，照 Android `ui/Theme.kt`（檔頭寫「與 iOS 版 Palette.swift 相同」）還原：
   主色金棕（淺色 #9E7329／深色 #C69A42）、判定與五行原本的顏色、頁面與卡片用系統的分組底色，
   拿掉「固定淺色模式」，跟著手機淺色／深色切換。今日頁頂部卡片改成金棕漸層；晚上日運卡改成深灰。
   只改了 `Views/Palette.swift`、`App/NineTwelveApp.swift`。

第八輪（同一個倉庫與分支）：
使用者傳了原版的截圖和原版 IPA（`NineTwelve-4lang-free.ipa`，第六輪以前的版本），說「是這版原版」，
要的是**原版的樣子**，再加上第六輪合盤的「稱呼：」與拿掉「例如：自己」。
原版 iOS 原始碼已經沒有了，照截圖、Android 版（舊樣式）和原版 IPA 裡用到的元件還原：
- 十二宮（命盤、合盤）改回一列一列，不再是三欄方格
- 宮位圓標：五行色的實心圓＋白字；判定標籤：實心色塊＋白字
- 系統字（不用襯線字），標題黑色；卡片是系統白卡，沒有陰影、沒有漸層
- 運程頁切換用系統的分段控制；年份加減用系統的 Stepper
- 今日頁：頂部白卡＋金棕靈數圓；白天／晚上日運都是白卡、金棕標題
- 導覽列、分頁列用系統預設；跟著手機淺色／深色
`CardBackground`、`SectionLabel`、`PrimaryButtonLabel` 這些共用元件名稱還留著，只是外觀改回原版。

第九輪：使用者說字體大小和原版不一樣。量過原版截圖，原版每個尺寸都和 Android 版寫死的數字相同
（宮位圓 38、分隔線縮排 54、日運數字 38、三柱數字 22、摘要字 11……），
Material 字級對應：titleSmall→.headline、titleMedium→.title3、bodyMedium→.subheadline、bodySmall→.caption。
iOS 已照這個對應改好。**以後要改 iOS 畫面，先看 Android 同一個畫面的數字。**

第十輪：點「宮位圓圈」和點「卡片／整列右邊」分開（`ChipTap`、`ChipSheet`，在 `Views/ChartTable.swift`）：
- 今日頁：月運圓圈 → 只開那一宮的含義；流年、大運圓圈 → 有引動就只開引動，沒有引動照舊開完整詳情。右邊照舊。
- 運程頁：流年列表圓圈同今日的流年；月運列表圓圈同今日的月運；
  **大運卡片的圓圈照舊開十二方面**（使用者選的），引動和宮位含義在右邊點開的詳情裡。
- 合盤頁：十二宮圓圈 → 只開那一宮的含義。
- 命盤頁沒動。Android 沒同步。

第十一輪：
1. 今日頁換日期時會彈出詳情（iOS 日期選擇器的點擊穿透到下面用 onTapGesture 的卡片）。
   摘要卡、十二宮列表的每一列、宮位圓圈都改成 Button，不再用 onTapGesture。
2. 5宮在「父親」前面加「被看見」（Being seen / Ser visto / Essere visti）；
   6宮最後加「反覆」（Going back and forth / Idas y vueltas / Andirivieni）。三份含義同步。

第十二輪：換日期會彈出詳情 —— 原因是點小日曆「旁邊」把它關掉的那一下落到下面的月運卡上。
試過整頁日曆，使用者覺得醜，**日曆維持原本的小日曆（compact），不要改外觀**。
做法：`TodayView.swift` 的 `OverlayGuard`，卡片與宮位圓圈被點時，
若小日曆開著、正在收起、或剛收起不到 0.5 秒，就不理這一下（今日頁每 0.1 秒記一次狀態）。

第十三輪：引動規則改成「因或果等於所走那一宮」（見第四節），三份引擎與測試同步。

第十四輪：12宮最後面加「欺騙」（Deception / Engaño / Inganno），三份含義同步。

第十五輪：3宮「思考」後加「思想」（Mindset / Mentalidad / Mentalità）、「新鮮感」後加「精神」
（Spirit / Ánimo / Spirito）、「同桌」改「同胞」（Compatriots / Compatriotas / Connazionali）；
命盤加入本命引動本命（見第四節）。

第十六輪：使用者回報「流年的引動算錯了」—— 截圖是 2027 年那一列（7宮 壞4因11）卻顯示 2026 年的引動
（3宮 壞3因8、9宮 壞8因3）。**規則沒錯，是畫面的錯**：`ChartTable` 用 `selectedIndex` 記第幾列，
但詳情頁的 sheet 讀到的是舊值。改成點開時就把那一列和它的引動一起存進 `SelectedRow`。
2027 年正確的引動是：2宮 正5因7、5宮 壞12因7、8宮 正11因7、11宮 好12因7。
使用者另外傳了一個叫 Hollow（com.phantomthieves.fortune，Persona5 風格）的 IPA 當參考，沒有用到它的內容。
這一輪 GitHub 連不上（使用者說連結的不是同一個 GitHub），只交原始碼 zip 與這份文件，**沒有在 CI 上編過**。

第十七輪（2026-10-22，倉庫 `u1130238883-oss/-eden-ai`，分支 `ninetwelve`）：
1. 原樣推上去，Build IPA 綠。使用者解不開 artifact 的 zip，改把 IPA 放到 GitHub Release 給 `.ipa` 直接下載連結
   （分支 `ninetwelve-ipa-日期` 上的 `ipa-release.yml`，建立分支時觸發、只跑 Ubuntu；推送時 commit 訊息加 [skip ci]）。
   ⚠️ 這個倉庫是**公開的**，已經告訴使用者，還沒決定怎麼處理。
2. 11宮最後面加「貴人」（Benefactors / Benefactores / Benefattori），三份含義同步。

## 十一、開著沒決定的

1. （已由 2026-09-28 的新規則涵蓋：2029 年引動 1、5、7 三個方面。）
2. 網站要不要也顯示引動。
3. 要不要把 App 改成瘦客戶端。
4. 要不要把 `tools/gen_palace_py.py` 補起來。
5. 命盤頁十二宮方格下面那行小字還是「點任一列可看詳細」，方格應該說「點任一格」。要不要改。
6. **可能洩露算法、但使用者沒叫改的地方**（Claude 提過，還沒回覆）：
   命盤頁「三柱相加（九進制）　8 + 1 + 5 = 14 → 靈數 5」那一行；
   今日頁白天／晚上日運卡片底下的「十二進制」「九進制」小字。
7. 合盤頁「最近合過的人」名單每一列右邊的「›」要不要也拿掉。
8. Android 要不要同步成新的白色系設計。
9. 本命引動本命：2宮（好2因9）、10宮（好10因5）會引動到自己那一列，要不要排除？（已問，未回）

---

## 十二、給新 Claude 的開場白（可以直接照抄）

> 這是我自創的命理系統做成的 App（iOS + Android + 網站），
> 附件的 zip 是完整原始碼，這份 md 是交接文件，請先讀完再動手。
> 請把這份程式碼推到我新帳號的新倉庫，讓 GitHub Actions 編出那一個四語解鎖版 IPA，
> 然後把 IPA 的下載連結給我（完整網址，單獨一行）。
