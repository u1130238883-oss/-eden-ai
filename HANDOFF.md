# NineSun 交接文件

> 最後更新：2026-09-29　分支：`claude/ninesun-ai-ipa`　倉庫：`u1130238883-oss/-eden-ai`（公開 repo，GitHub Actions 免費不限分鐘；舊倉庫 `changyuanzhang006-sketch/-` 額度已用完）

## 0. 一句話

NineSun 是一個從零手寫的 iOS AI 夥伴，介面是絕區零風格。它的底層認知是使用者自己的 **九型十二宮**，另外會排 **八字、紫微斗數**、算 **易經** 卦。本地不會的問題，它會**自己上網查、讀網頁、比對後回答**。整個 App 不用任何付費 API。

---

## 1. 目前狀態（重要）

| 項目 | 狀態 |
|---|---|
| 最後一版**測試全過、已出 IPA** | `ninesun-build-62`（commit `a16461a`）：<https://github.com/changyuanzhang006-sketch/-/releases/download/ninesun-build-62/NineSun.ipa>。內容包括八字／紫微深入解讀、補時辰、為什麼講含義、上網搜尋、紫微流月、三方四正、神煞 |
| 之後的 commit | `0bf7b4f` → `38c57df`：GitHub Actions 額度用完，**這幾版沒有 CI 驗證**。其中 `0bf7b4f`、`4fb4064`、`71e72cc` 在額度用完前跑過，**編譯成功**，只有一個測試失敗；那個測試已在 `ff88c7c` 修正。`ff88c7c` 以後（八字合婚、怎麼辦的具體建議、**WebAgent 上網思路**）**還沒編譯過** |
| 下一步第一件事 | 找一台能跑 macOS 的環境跑一次 `swift test` 和 `xcodebuild`（見第 5 節），修掉可能的編譯錯誤，再出 IPA |

未驗證的 commit（由舊到新）：
- `0bf7b4f`：幫別人排八字／紫微（猜性別、不改自己的生日）；完整解讀加上八字／紫微對照
- `4fb4064`：八字流日（今天／明天）；網路答案的摘要
- `71e72cc`：九型十二宮的宮位人物與身體部位
- `ff88c7c`：八字合婚；幫別人看時不把「老公」「媽媽」當成主題
- `fd0eb27`：「怎麼辦」依宮位給具體建議；README
- `3c751a2`：**WebAgent**（自己上網：理解 → 規劃 → 搜尋 → 讀網頁 → 比對 → 回答 → 記住）；八字／紫微解讀後自動上網對照
- `38c57df`：修正合盤的 optional switch

---

## 2. 使用者（命主）的要求與規則

1. **不用付費 API**（沒有 Claude/OpenAI 金鑰）。
2. 每一輪做完都要給 **未簽名 IPA 連結**（GitHub Releases `ninesun-build-N`）。
3. **九型十二宮是底層**，八字、紫微是輔助。
4. 不要幸運色、幸運數字（九型十二宮沒有這些）。
5. 設定頁只留：語言、生日／出生時間／性別（自動儲存）、清除對話。**不要 GitHub**。
6. 「為什麼」**不要講算法**，要講含義（因宮的事 → 飛到哪個領域 → 得到什麼結果 → 情緒處境）。
7. 點鍵盤以外的地方要收起鍵盤。
8. AI 要能**自己上網查資料、有自己的思路**。本地資料庫沒有的問題也要能回答。

### 九型十二宮的讀法（使用者親自定的）

- **飛宮**：一列「P宮 V R 因 C」讀成：因宮 C 的含義，飛到本宮 P 的領域，得到果宮 R 的好／正／壞版本。
  - 例：2006-01-14 生的人，大運走 3宮「壞12因7」，會引動本命 5宮「壞3因8」。意思是 8宮的身體、焦灼飛到 5宮（感情、性），得到壞3：沒交流、沒新鮮感、事情沒發生，是一個「空」的象。
  - 同一個大運也引動 11宮「壞8因3」：交流飛到朋友，得到壞8，孤獨焦灼。
- **問主題的回答節奏**（感情、健康、婚姻、錢財、性生活……都一樣）：
  1. 大運本身是不是走這一宮（好／壞）
  2. 大運有沒有引動本命這一宮（好／壞的引動）
  3. 大運十二方面的這一方面（好／壞）
  4. 今年是不是走這一宮的流年？流年有沒有引動這一方面？
  5. 期限：哪幾段大運好、壞；哪幾年好、壞；今年哪幾個月的流月走到這一宮
  6. 綜合（含情緒與處境、牽涉的人、身體提醒）
- **宮位對應**：
  - 感情看 5宮 + 7宮：5宮是戀愛、性生活、吸引力；7宮是負責任的一對一關係、結婚、婚姻。
  - 健康看 8宮。
  - 朋友看 11宮。
  - 事業工作看 10宮。
  - 錢財看 2宮 + 8宮：2宮是我的錢、小錢；8宮是別人的錢、大錢。
  - 九型十二宮參考了西洋占星的十二宮，但有自己的含義；每一宮都代表個人的情緒和處境。
- **日運**：白天看日宮，晚上看夜宮。

---

## 3. 架構

```
ai/                  Python（訓練、資料產生、與 Swift 逐字對照的 fixture）
ios/EchoCore/        Swift Package：所有引擎、路由、解讀（有單元測試）
ios/NineSun/         SwiftUI App（介面、上網、儲存）
ios/project.yml      XcodeGen
.github/workflows/build-ninesun-ipa.yml   macOS：swift test → xcodebuild → 未簽名 IPA → Release
```

### 對話流程（`EchoEngine.reply`）
規則 → 觸發回覆 → 教新詞 → 幫別人看（九型） → **八字／紫微（ManticReader）** → 八字／紫微追問 → 九型人格 → 生日／時辰／性別 → 自己的命盤 → 易經 → 九型追問 → 完整解讀 → 規劃（什麼時候） → 主題（topicZh） → 九型流日／月／年／大運 → 資料庫 → 工具 → 聊天（陪伴 → 對話庫 → **知識題就上網** → 宮位感知 → **上網**）

### 主要檔案
| 檔案 | 作用 |
|---|---|
| `NineTwelve.swift` | Hollow 算法：本命、流年、大運（含十二方面）、流月、日宮夜宮、引動 |
| `FlowReading.swift` | 十二宮的領域／因／果（好正壞）、情緒處境、牽涉的人、身體、改善建議 |
| `Reader.swift` | 九型十二宮的所有解讀；`topicZh` 就是主題的①～⑥節奏；`whyZh` 講含義的「為什麼」 |
| `TopicRouter.swift` | 問題 → 宮位（感情 5+7、錢財 2+8……） |
| `BaZi.swift` / `BaZiReading.swift` | 八字排盤。解讀涵蓋：十神、月令格局、身強弱、喜忌、沖合刑害、神煞、流年（為什麼好／壞）、流月、流日、大運、主題（感情／錢財／事業／健康／學業／家庭）、合婚 |
| `ZiWei.swift` / `ZiWeiReading.swift` | 紫微排盤。解讀涵蓋：命身宮、主星、本命四化、三方四正、格局、十二宮、大限、流年命宮、流年四化、流月（斗君）、宮位主題 |
| `ManticReader.swift` | 八字／紫微問句的路由。句子裡帶生日就用那個生日排盤；補時辰；「為什麼／怎麼辦」；輸出**要上網查的組合** |
| `EchoEngine.swift` | 總路由、ProfileParser（中文數字時間「早上七點半」）、`infoQuestion`（知識題 → 上網） |
| `ios/NineSun/Services/WebAgent.swift` | **上網思路**：理解問題 → 規劃關鍵字 → 搜尋 → 打開網頁讀內容 → 交叉比對（多個來源都提到的詞）→ 回答附思路、把握程度、來源 → `WebMemory` 記住 |
| `ios/NineSun/Services/WebSearch.swift` | 免費搜尋：DuckDuckGo 即時答案與網頁結果、Bing、維基百科（不需要金鑰） |
| `ios/NineSun/App/ChatViewModel.swift` | App 狀態。收到 `webQuery` 就跑 WebAgent；收到 `webAugment` 就先顯示盤面解讀，再上網對照。「重新查…」會忘掉舊答案重查 |
| `ai/knowledge_data.py` | 產生 `knowledge_zh.json`（236 條，含格局、組合、神煞、紫微格局） |

---

## 4. 測試

- `ios/EchoCore/Tests/EchoCoreTests/EchoCoreTests.swift`
  - `testUserPhrasings`：模擬真實使用者的 140 多句問法，最後印出 `USER-PHRASINGS: N ok, M failed`。
  - `testPrintSampleReplies`：把範例回覆印到 stderr，方便檢查語氣。
- 改功能時，把新的問法加進 `testUserPhrasings` 的 `cases`。

---

## 5. 沒有 GitHub Actions 額度時怎麼編譯

1. **把倉庫改成 Public**：公開倉庫的 GitHub Actions（包含 macOS）是免費、不限分鐘的。改完 push 一次，就會自動測試並出 IPA。這是最省事的方法。
2. **等下個月額度重置**。
3. **用自己的 Mac**：
   ```sh
   cd ios/EchoCore && swift test          # 測試
   brew install xcodegen && cd .. && xcodegen generate
   xcodebuild -project NineSun.xcodeproj -scheme NineSun -configuration Release \
     -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
     CODE_SIGNING_ALLOWED=NO build
   mkdir Payload && cp -R build/Build/Products/Release-iphoneos/NineSun.app Payload/ && zip -qry NineSun.ipa Payload
   ```
4. 安裝：用 Sideloadly、AltStore 或 TrollStore 以自己的 Apple ID 簽名。免費 Apple ID 簽的每 7 天要重簽一次。

---

## 6. 建議的下一步

1. 先編譯驗證 `ff88c7c` 以後的 commit（第 1 節），修掉錯誤，出新 IPA。
2. 在真機上測試 WebAgent。
   - DuckDuckGo 有時會回驗證頁；那時會自動改用 Bing 和維基百科。
   - 如果某個來源一直失敗，可以在 `WebSearch.search` 調整順序。
3. 簡體 → 繁體轉換：網路結果有時是簡體，可以加一個轉換表。
4. 八字／紫微的網路對照目前只查第一個組合（`webAugment.first`），可以擴充成查兩個再合併。
5. 可以把 WebMemory 查過的答案餵回本地資料庫，讓它越用越聰明。

---

## 7. 限制（對使用者要誠實）

- 神經網路只有約 400 萬參數，**不是**大型語言模型。它的聰明來自：
  - 精確的命理引擎（數字不會亂編）；
  - 寫好的解讀思路；
  - 上網搜尋後的整理與比對。
- 上網回答是「挑出並整理網頁上最相關的句子」，不是自己生成新的文章。來源少或說法不一時，它會說把握程度低。


---

## 8. 上網查資料的思考方式（2026-09-29 重寫）

程式在 `ios/EchoCore/Sources/EchoCore/Web/`（已搬進 EchoCore，可以在 CI 上真的連網測試）：

| 檔案 | 作用 |
|---|---|
| `WebSearch.swift` | 免費來源：Bing（RSS＋網頁）、DuckDuckGo、Yahoo 奇摩、維基百科（台灣正體）、Google 新聞 RSS、Open-Meteo 天氣、open.er-api 匯率、Yahoo Finance 指數。讀網頁支援 Big5／GBK |
| `WebAgent.swift` | 思考流程（見下），每次即時上網，**不再存舊答案**（WebMemory 已刪除，舊檔開 App 時自動清掉） |
| `WebStrategy.swift` | 各類問題的「解題步驟」：健康、法律、是什麼、怎麼做、為什麼、比較、人物、推薦；口語簡稱 → 正式名稱（甲減 → 甲狀腺機能低下症）；簡體 → 繁體 |
| `WebFortune.swift` | 命理：網路說法逐句對照使用者的盤（喜用／忌神、身強弱、命宮主星、化忌宮位），標出適用／不適用，再給綜合判斷 |

**思考流程**：
1. 釐清：哪一類問題、真正要問的主題；口語換正式名稱。
2. 拆解：疾病 → 是什麼／症狀／原因／治療／飲食照顧；法律 → 規定／後果／怎麼做／權益；命理 → 含義性格／喜忌／感情／事業財運／健康。
3. 蒐集：一次最多兩組關鍵字（太密集會被搜尋引擎當成機器人，回一堆無關結果）。
4. 閱讀：打開最相關的網頁，只留下在回答該小問題的句子；跟主題無關的結果丟掉。
5. 查證：官方、醫院、法院、百科優先；多個來源都提到的才可信。
6. 反思：哪部分沒查到、有沒有官方來源，老實說把握程度。
7. 回答：結論 → 分段 → 來源；健康提醒看哪一科，法律提醒法扶 412-8518。

**路由**（`EchoEngine`）：明確說「上網查／搜尋」、知識／新聞／天氣／匯率／股市、疾病與法律問題、問句形式的一般問題 → 上網；問自己的運勢、命盤、心情、跟 NineSun 聊天 → 本地。八字／紫微解讀完會自動上網對照。

**測試**：`WebTests.swift`。`WebRoutingTests` 每次跑；`WebLiveTests` 只在 CI 的「Live web search check」步驟用 `NINESUN_LIVE=1` 真的連網（GitHub 的機器 IP 問太多題會被限流，後面的題目查不到是正常的）。
