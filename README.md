# 九型十二宮

一個 iOS 與 Android App，完整實作《九型十二宮算命系統方法》這套自創命理系統。
兩個平台共用同一套演算法，並以同一組測試案例驗證，算出來的結果必須一模一樣。

輸入出生年月日即可排出命盤，並推算 **大運、流年、月運、白天日運、晚上日運**，
以及輸入兩個人生日的 **合盤**。

---

## 功能

| 頁面 | 內容 |
|---|---|
| **今日** | 白天／晚上日運、當月月運、今年流年、當前大運，可切換日期、顯示年齡、一鍵分享 |
| **命盤** | 本命三柱與靈數、十二宮盤 |
| **運程** | 一生大運時間軸、大運各段、流年（十二年一循環）、月運（一到十二月） |
| **合盤** | 輸入對方生日，兩盤三柱相加後排出合盤十二宮 |
| **設定** | 修改出生資料、切換語言（繁體中文／English）、十二宮含義（可搜尋）、流年錨定 |

盤上任何一列都可以點開，會顯示這一列是怎麼算出來的：年月柱的五行關係、
被剋／受生的是哪一柱、果與因分別落在哪一宮、以及那些宮位的含義。

### 兩個語言版本

同一份程式碼會建置出兩個獨立的 App，可同時安裝（套件名不同）：

| 版本 | 語言 | 名稱 | iOS | Android |
|---|---|---|---|---|
| 預設 | 繁體中文 / English | 九型十二宮 | `NineTwelve-zh-en-ipa` | `NineTwelve-zh-en-*-apk` |
| latin | Español / Italiano | Nueve y Doce | `NueveYDoce-es-it-ipa` | `NueveYDoce-es-it-*-apk` |

各版本的設定頁只會列出該版本的兩種語言，首次啟動依系統語言自動選擇。

**主畫面上的名稱會跟著手機的系統語言換**：中文手機顯示「九型十二宮」、
英文手機顯示「Nine & Twelve」、西班牙文顯示「Nueve y Doce」、
義大利文顯示「Nove e Dodici」。iOS 靠 `<語言>.lproj/InfoPlist.strings`，
Android 靠 `res/values-<語言>/strings.xml`；兩邊都由建置流程確保
一個版本只收自己那兩種語言。

> 系統做得到的就到這裡：iOS 與 Android 都不允許 App 從自己的設定頁
> 改掉主畫面上的名稱，只能跟著手機的系統語言走。

十二宮含義與全部介面文字四種語言都完整翻譯。

英文採用命理文獻的既定術語：
桃花 Peach Blossom、正財 Direct Wealth、偏財 Indirect Wealth、宮 Palace、
年月日柱 Year / Month / Day Pillar、大運 Luck Pillar、流年 Annual Luck、
五行相生相剋 Five Elements generating / controlling。

### 會員

命盤、運程、合盤三頁需要訂閱才能使用；今日的日運永遠免費。

| 平台 | 發行管道 | 收款方式 |
|---|---|---|
| iOS | App Store | Apple 自動續訂內購（StoreKit 2） |
| Android | Google Play | Google Play 帳單（Play Billing 7） |
| Android | 自己發 APK | 微信支付／支付寶 + 啟用碼 |

商店規則（App Store 3.1.1、Google Play 付款政策）都規定：在商店上架的 App，
App 內解鎖數位功能只能走該商店的內購，不能接第三方收款。
**但 Android 可以不透過商店發行** —— 自己發 APK 就不受這條約束，
所以安卓多做了一個「直連版」，直接收微信／支付寶。

- iOS：[`docs/上架與收款.md`](docs/上架與收款.md)
- Android：[`docs/谷歌商店上架與收款.md`](docs/谷歌商店上架與收款.md)

所有資料只存在裝置本機，不會上傳。

---

## 演算法

以下規則全部取自原始文件，並以文件中的每一個範例寫成單元測試 ——
iOS 見 `ios/NineTwelveTests/EngineTests.swift`，
Android 見 `android/app/src/test/.../EngineTest.kt`，兩邊是同一組案例。

### 1. 本命三柱與靈數

出生的年、月、日各自用生命靈數方式化約成 1–9：

```
2006年1月14日 → 2+0+0+6=8 ； 1 ； 1+4=5   →  三柱 8；1；5
三柱相加以九進制化約：8+1+5=14 → 靈數 5
```

### 2. 排十二宮盤

首列落在靈數宮（命宮），之後宮位**逆序**：5→4→3→2→1→12→11→10→9→8→7→6。
三柱由「本命三柱 +1」起算，每列再加一（十二進制），第十二列剛好回到本命三柱。

### 3. 十二宮五行

| 五行 | 宮位 |
|---|---|
| 金 | 2、7 |
| 木 | 9、12 |
| 水 | 3、4、6 |
| 火 | 1、5、8 |
| 土 | 10、11 |

相生：木生火、火生土、土生金、金生水、水生木
相剋：木剋土、土剋水、水剋火、火剋金、金剋木

### 4. 好／正／壞的判定

看**年柱與月柱**的五行關係，**日柱**作為加數，所有加法皆為十二進制。

| 關係 | 判定 | 果 | 因 |
|---|---|---|---|
| 相剋 | 壞 | 被剋的那一柱 + 日柱 | 去剋的那一柱 + 日柱 |
| 相生 | 好 | 受生的那一柱 + 日柱 | 去生的那一柱 + 日柱 |
| 同五行 | 正 | 日柱本身 | (年柱+日柱) + (月柱+日柱) |

```
9；2；6   9木、2金，金剋木 → 被剋 9+6=15→3，去剋 2+6=8   → 壞3因8
4；9；1   4水、9木，水生木 → 受生 9+1=10，去生 4+1=5      → 好10因5
2；7；11  皆為金 → 果=11；2+11=1、7+11=6、1+6=7          → 正11因7
```

### 5. 流年

十二宮盤同時就是流年盤，一列一年，**12 年一循環**。
出生年落在命宮的下一個位置（第二列）。2006 年生的人，命宮那一列即 2017 年；
2029 年與 2017 年、2005 年的運勢完全相同。

> 設定中可切換為「固定 2017 年錨點」——兩種錨定方式都能重現原始文件的範例，
> 但推廣到其他出生年時結果不同。

### 6. 大運

出生年落在九宮循環中「靈數的下一個位置」。第一段大運從出生年走到九宮第 9 位為止，
之後每段固定九年。每段取**起始那一年的流年**作為整段運勢。

```
2006年生、靈數5 → 出生年在第6位
2006–2009（4宮 壞10因5）、2010–2018（12宮 正11因7）
2019–2027（3宮 壞12因7）、2028–2036（6宮 正5因7）
```

### 7. 月運

該年所屬**大運的三柱** ＋ 該年**流年的三柱**（年加年、月加月、日加日，十二進制），
組成一月的盤；一月宮位 = 流年宮位 − 1，之後宮位逆序、三柱每月加一。

```
2026年：大運 11；4；8 ＋ 流年 6；11；3 = 5；3；11
流年走 8宮 → 一月為 7宮 5；3；11 壞4因2
```

### 8. 日運

**白天（十二進制）**：靈數 + 月份 得 a；靈數 + a 得 b；b 再加月份與日期的各位數字。

```
靈數5、8月17日 → 5+8=13→1 ； 5+1=6 ； 6+8+1+7=22→10宮
```

**晚上（九進制）**：靈數直接加上月份與日期的各位數字。

```
靈數5、8月17日 → 5+8+1+7=21 → 3宮
```

### 9. 合盤

兩人本命三柱相加（年加年、月加月、日加日，十二進制）得合盤三柱，
再依本命盤方式排出十二宮。

```
8；1；5 與 9；1；5 → 5；2；10，靈數 8
```

---

## 取得 IPA

每次推送都會由 GitHub Actions 在 macOS 上建置，產出**未簽章**的 IPA。

1. 打開本倉庫的 **Actions** 分頁
2. 點最新一次 **Build IPA** 執行紀錄
3. 在下方 **Artifacts** 下載 `NineTwelve-zh-en-ipa`（繁中／英文）
   或 `NueveYDoce-es-it-ipa`（西班牙文／義大利文）

未簽章的 IPA 不能直接安裝到 iPhone，需要用自己的 Apple ID 簽章，任選一種：

- **AltStore / SideStore** — 免費 Apple ID，裝好後把 IPA 拖進去，每 7 天自動續簽
- **Sideloadly**（Mac／Windows）— 接上 iPhone，選 IPA 與 Apple ID 即可安裝
- **Xcode**（Mac）— 直接開 `ios/NineTwelve.xcodeproj`，在 Signing & Capabilities
  選自己的 Apple ID，接上 iPhone 按 ▶︎ 執行，這是最省事的方式
- **Apple Developer Program**（$99/年）— 可做正式簽章與 TestFlight 發佈

---

## 取得 APK

每次推送也會在 Ubuntu 上建置四個 APK（**可直接安裝**，用固定的除錯金鑰簽章）：

| Artifact | 語言 | 收款方式 |
|---|---|---|
| `NineTwelve-zh-en-play-apk` | 繁中／英文 | Google Play 帳單 |
| `NueveYDoce-es-it-play-apk` | 西／義 | Google Play 帳單 |
| `NineTwelve-zh-en-direct-apk` | 繁中／英文 | 微信／支付寶 + 啟用碼 |
| `NueveYDoce-es-it-direct-apk` | 西／義 | 微信／支付寶 + 啟用碼 |

四個套件名互不相同，可以同時裝在同一支手機上。
安裝時 Android 會問「要允許從這個來源安裝嗎」，按允許即可。

> 直連版裡的微信／支付寶收款碼目前是**佔位圖**，發佈前要換成自己的，
> 見 [`docs/谷歌商店上架與收款.md`](docs/谷歌商店上架與收款.md)。

---

## 本機開發

```bash
open ios/NineTwelve.xcodeproj      # 需要 Xcode 16 以上
```

專案檔由腳本產生，新增／刪除原始碼後重新執行：

```bash
python3 tools/gen_xcodeproj.py     # 重新產生 .xcodeproj
python3 tools/check_pbxproj.py     # 結構檢查
python3 tools/parse_pbxproj.py     # 以 plist 文法解析並做語意檢查
python3 tools/make_icon.py out.png # 重新產生 App 圖示
```

Android：

```bash
cd android
gradle assembleCjkPlayDebug assembleLatinPlayDebug \
       assembleCjkDirectDebug assembleLatinDirectDebug
gradle testCjkPlayDebugUnitTest    # 與 iOS 版同一組演算法測試
```

```bash
python3 tools/make_android_assets.py                      # 圖示與收款碼佔位圖
NINETWELVE_SECRET=... python3 tools/make_activation_code.py <裝置碼> <月數>
```

## 目錄

```
ios/NineTwelve/Engine/     演算法（與 UI 完全無關，可單獨測試）
  Numerology.swift         九進制、十二進制、生命靈數化約
  Element.swift            十二宮五行與生剋
  Chart.swift              三柱、好／正／壞判定、排盤
  Fortune.swift            流年、大運、月運、日運、合盤
  PalaceMeanings.swift     十二宮含義（中英對照）
  Localization.swift       繁體中文／英文字串
ios/NineTwelve/Store/      訂閱（StoreKit 2）
ios/NineTwelve/Views/      SwiftUI 介面
  LuckTimeline.swift       一生大運時間軸、因果圖
  Palette.swift            顏色
ios/NineTwelveTests/       以原始文件範例為準的單元測試

android/app/src/main/      兩個語言版本共用的程式碼
  engine/                  演算法，與 ios/NineTwelve/Engine 逐行對應
  model/                   狀態與儲存
  ui/                      Jetpack Compose 介面
  billing/Membership.kt    會員狀態的共用介面
android/app/src/cjk|latin/ 各語言版本開放的語言與 App 名稱
android/app/src/play/      Google Play 帳單
android/app/src/direct/    微信／支付寶 + 啟用碼
android/app/src/test/      與 iOS 版同一組演算法測試

tools/                     專案檔、圖示、啟用碼產生器
```

## 免責

本 App 為個人命理研究方法的數位化工具，僅供參考與娛樂，不構成任何醫療、
財務、法律或人生決策建議。
