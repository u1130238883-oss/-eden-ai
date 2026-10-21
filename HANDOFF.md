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

---

## 附：思路庫與網頁測試版（2026-09-30 合併）

- `ai/claude_playbook.py`：使用者常問的問題，用 Claude 的思路寫好答案（前提 → 原因 → 做法 → 下一步），`python3 ai/chat_bank.py` 會併進 `chat_bank.json`。有關鍵詞比對，換句話說也接得住（`PARAPHRASE_TESTS`）。
- 路由：問句如果命中思路庫，先給寫好的思路答案，**再上網查**最新資料補充；沒命中就照原本的直接上網查。沒有要算運勢的實用問題（「老闆不給我加薪怎麼辦」）不會被 10宮主題搶走。
- 本機也能編譯測試了：SwiftWasm 6.0.3 工具鏈（`github.com/swiftwasm/swift/releases`）在 Linux 上可以直接 `swift test`（`--skip testLiveSearch`）。
- `web/`：把 EchoCore 編成 WebAssembly 的網頁測試版（`web/build.sh`）。網頁不能連外網，所以只能測本地功能。EchoCore 加了 `Web/`（URLSession）之後，要編網頁版得先把 `Web/` 排除在 WASI 之外。

## Understanding questions before searching (Web/Understanding.swift)

Factual questions are no longer answered from hand-written entries. The flow is:
1. `Understanding.frame(question)` works out the subject and the kind of answer wanted: number (with the right units), list, reason, steps, person, place, time, definition, comparison, or open.
2. The frame decides the searches (list → "X列表" plus the Wikipedia list page; distance → "X 距離"; recipe → "X 做法").
3. `WebAgent.solve` keeps only evidence of that shape: numbers with units (voted per website), lists from table first columns / "、" enumerations / short-line runs, sentences with a cause, ordered steps.
4. If nothing answers the question, one retry round with `frame.retry` (and more Wikipedia pages); if still nothing, it says so instead of padding with unrelated text.
5. "我的思路" shows ① 理解 (the restated question) and ⑥ 檢查 (whether the evidence answered it).

The chat bank keeps only things a search cannot answer: crisis safety, riddles, ethics/philosophy views, and questions about NineSun itself. Unit tests: `Tests/EchoCoreTests/UnderstandingTests.swift`.

## Thinking habits and self-upgrade (Web/Mind.swift, Web/SelfTuning.swift)

- Every web answer is organised as: main answer → 次要・補充 (only sentences about the topic) → 換個角度 (disputes, misconceptions, "但是…" sentences) → 🧭 我的看法 (which source it trusts and why, and when it would change its mind) → 💬 你可能還想知道 (next step the asker probably wants) → confidence.
- Values used in judging (Mind.values): evidence over claims, official/encyclopedia/majority sources first, say "not sure" when unsure, answer the question first.
- Correction: "不對／錯了／答錯…" right after a web answer → the hosts used last time are penalised and avoided, the retry wording is used first, and the reply starts with 🔁 反思.
- Self-upgrade stores no answers: SelfTuning keeps small counters per question type — which websites actually contained the answer, whether the first search round worked — and 👍/👎 on web answers adjust them. Saved in ninesun-selftuning.json (capped).

## 大腦（閱讀理解模型）— 2026-09-30 訓練完成

- 權重：`ios/NineSun/Resources/reader.bin`（float16，約 3 百萬參數）＋ `reader.json`。App 啟動時 `Brain.shared = try? Brain(bundle: .main)` 載入；上網查到的每一段文字都由它判斷有沒有在回答、答案是哪幾個字（`Web/Think.swift`）。
- 訓練：`python3 ai/train_reader.py --data DIR --out DIR --pretrain-min 60 --finetune-min 150`（PyTorch，CPU）。
  1. 讀書：遮 15% 的字讓它猜（前面放一句同篇或別篇的句子，學會對照著找）。
  2. 閱讀測驗：DRCD（繁體）＋ CMRC 2018（轉繁體）共 44,792 題；段落切法跟 App 讀網頁一樣（兩三句一段），約一半是「同一篇裡沒在回答」的段落。
  - 教材只有公開資料集，不含任何 AI 產生的文字。
- 考試（DRCD dev 1,000 題，從沒拿來訓練）：

  | 指標 | 大腦 | 舊方法 |
  |---|---|---|
  | 挑到真正回答的那一段 | **90.3%** | 拿開頭那段 29.2% |
  | 混進 4 篇無關文章還挑得到 | **89.9%** | 問題字詞重疊最多 86.5% |
  | 答案字詞 F1／完全答對 | 62.7%／40.9% | — |

- 對照測試：`python3 ai/brain_fixture.py ios/NineSun/Resources ios/EchoCore/Tests/EchoCoreTests/Fixtures/brain.json` 產生 fixture；`BrainTests.swift` 檢查 Swift 讀出來的答案和 Python 一樣。
- 字的比對（`match_features`）比的是字本身，不是字表編號：字表裡沒有的罕見人名、地名也對得到。
- 追問：句子開頭的「他／她／它」（「他幾歲？」）會換成上一題的主題（`EchoEngine.substituteAnaphor`）。

## 大腦 v3 與思考能力 — 2026-10-21

### 大腦 v3（`reader.bin`，6 層、約 650 萬參數）
- 從 v2（部分答對 0.654）接著練：`python3 ai/train_reader.py --data DIR --out DIR --init ios/NineSun/Resources --wiki WIKI --wiki-chars 90000000 --pretrain-min 75 --finetune-min 210 --read-lr 5e-4`
  1. 再讀 75 分鐘中文維基百科（`corpus-data` 分支的 wiki_*.txt）。
  2. 閱讀測驗＋**主次判斷**：多一個輸出（看 [CLS]），判斷這段對問題是「主要（直接回答）／次要（同一件事的補充）／無關」。
     - 主要＝答案所在段落；次要＝同一篇文章的其他段落；無關＝別篇文章（一段隨機、一段挑跟問題字詞最像的）。
  - 問題會隨機改成口語（「請問…」「欸…」「…呢」、拿掉問號）。
  - 每 5 分鐘存檔，容器重開後用同一個指令接著練。
- 考試（DRCD dev 600 題）：

  | 指標 | v3 | v2 |
  |---|---|---|
  | 答案字詞 F1／完全答對 | **0.743／0.588** | 0.654／0.478 |
  | 混進無關文章還挑得到回答的段落 | 0.902 | 0.890 |
  | 主次判斷（主要／次要／無關）答對 | 0.903 | （沒有） |

- Swift：`Brain.Span` 多了 `main`／`side`／`none`（機率）；舊版大腦沒有這個輸出時是 -1，照舊運作。
- `Think.conclude`：無關的段落不拿來湊答案；回答後面加【次要・補充】（大腦判斷為次要的段落，每個網站一段、最多兩段）。

### 思考能力（`Web/Mind.swift`、`Web/Notebook.swift`）
- **知識筆記本**：有把握的答案記下來（答案、日期、網站、查到幾次）。筆記**不直接拿來回答**，每次還是上網查；查完跟筆記對照：一樣就說「第 N 次查到同樣的答案」，不一樣就說出來並以新的為準。存在 `ninesun-notebook.json`。輸入「知識筆記」可以看。
- **知錯能改**：說「不對，是X」→ 記下這題被指正、使用者說的答案是 X；下次查同一題時對照：資料跟 X 一樣就說「你是對的」並更正筆記。
- **揣測問的人**：依使用者生日算出的九型，在「我的看法」後面加一句「🎯 給你（第N型）的重點」，同一個答案用他在意的方式交代。聽起來在擔心（擔心、害怕、好煩…）時先接住再講重點。
- **不放棄**：「繼續查」→ 換個方向把上一題再查一次；Bing、Yahoo 都沒結果時再問 Google。
- **Google**：`WebSearch.google`（基本版網頁，/url?q= 換回原網址）。Google 擋自動查詢時沒有結果，其他來源照常。

### 融合新版 Hollow（miro 倉庫編出的 Hollow.ipa）
- 新版只多了一個算法：**本命宮引動的本命宮**（`Destiny.triggeredByNatal(p)`／`ninetwelve.py` 的 `triggered_by_natal`）。
  - 點本命 P 宮 → 其他本命宮中果或因為 P 的；P 宮自己不算。由反組譯 `Triggers.natal(Destiny, PalaceRow)` 確認（跳過 palace == P，果或因等於 P 的列入）。
  - 例：2006-01-14 生，本命 5 宮引動 4宮「壞10因5」、10宮「好10因5」、6宮「正5因7」。
- 本命盤解讀（命宮引動的本命宮）與主題解讀（每一宮的「本命宮引動的本命宮」一行）都用上了。

## 請其他 AI 幫忙（`Web/AskAIs.swift`）— 2026-10-21

使用者要的流程：**先自己上網查 → 沒把握或要推理的題目，自動同時問其他 AI → 答案直接出現在 NineSun 裡：各家重點、哪裡一致、哪裡不同、NineSun 查證後的結論**。

- **只用正式 API**（各家都禁止用程式自動操作它們的網站，所以不做網頁自動化）。
  - 預設 **OpenRouter**：一把金鑰；沒指定模型時，從 `openrouter.ai/api/v1/models` 自動挑三個不同家的免費模型（`:free`，DeepSeek、Qwen、Llama 優先，推理型和看圖的不選），一天更新一次；抓不到就用備用名單。帳戶儲值後可以在設定裡指定 Claude、Grok 等付費模型。
  - **Gemini 金鑰選用**：能調的安全過濾都設成 `BLOCK_NONE`；模型先試 `gemini-flash-latest`，找不到再試 `gemini-2.5-flash`。
  - 金鑰存在鑰匙圈（`NineSun/App/KeyStore.swift`），只在這支手機。
- **什麼時候問**（`AskAIs.shouldAsk`）：沒查到、沒答到、把握低，或是原因／步驟／比較題。設定頁可以關掉自動問；說「問AI 問題」一定會問。
- **給每家的指示**：第一行「結論：」一句話，再最多 4 點重點；不確定就說不確定，不要編造。附上 NineSun 在網路上讀到的最相關幾句當參考。
- **整理**（`AskAIs.summarize`）：
  - 各家的結論＋重點；沒回答的寫出原因（金鑰錯、免費次數用完、被過濾）。
  - 說法一樣的分成一組（一個包含另一個、數字對得上、詞大多一樣；肯定和否定要一致）→「✅ 一致」「⚠️ 不同」。
  - **查證**：NineSun 自己有把握、有出處的答案跟所有 AI 都不同 → 以有出處的為準；否則哪一組說法有網路資料支持（數字對得上，或關鍵詞大多出現在同一句）就採用那一組，即使不是多數；都沒有證據 → 多數意見當參考，或不下結論。
- 單元測試：`Tests/EchoCoreTests/AskAIsTests.swift`（不連網、不用金鑰）。
- CI：平常只跑測試和編譯；commit 訊息有 `[ipa]` 或在 Actions 頁面手動執行時才發 IPA。

## 用實測答錯的題目修正思考（2026-10-21）

CI 的「Live web search check」會用真的網路問 40 題（`WebTests.swift` 的 `testLiveConversation`），每次看記錄挑出答錯的，把當時讀到的句子寫成測試（`Tests/EchoCoreTests/AnswerQualityTests.swift`），再改規則。

- **首都**：地名在「是日本的首都」前面時取結尾（「一般也認為東京是…」→ 東京），排除動詞、虛詞；「東京都」不會變成「京都」（`Understanding.capitalVotes`）。
- **數字**：「1億5000萬km」整個算（之前只讀到 5000萬km）；「玉山東峰（3,869公尺）」這種旁邊另一座峰的數字不算。
- **最高的山**：段落裡的「最高的…」要是同一類（山／峰），「最高的火車站」不算（`Think.superlativeFits`）。
- **不像答案的字**：「維基百科」「認為」「圈」這類不當答案（`Think.junk`）。
- **說明題**（在講什麼、怎麼辦、為什麼、怎麼做）：給整句（最多 80 字），而且：
  - 先找有「講述、描寫」「因為」「可以、建議」這類字的句子（`Think.cues`）；
  - 句子要講到問的那件事：問題切成內容詞組（「老闆不給我加薪怎麼辦」→ 老闆不給、加薪），最後一個詞組句子裡要有（加薪不能用「欠薪」回答、綠豆湯不能用「扁豆湯」）（`Think.onTopic`）；
  - 都找不到就不硬切幾個字當答案。
- **「X的書都講了什麼」**：拆成兩步——先找講到他的句子裡最常出現的《作品》，再找每一部「描寫、講述…」的句子，加一句整體風格（`Think.worksDigest`）。
- **原因**：表格的一列不算；有講到主題的句子優先；大腦有把握時用它挑的句子。
- **做法**：食譜列表上別道菜的食材不算步驟；每一步完整列出；做法題先打開食譜、教學網站（百科沒有步驟）。
- **引文**：被切斷時加「…」（連「…」在內不超過 14 字），不切斷數字。
- **追問**：上一次查詢自己加的「列表」不再被當成主題。
- 每題的耗時寫在 `Result.timing`（查詢／讀網頁／思考／整理），CI 記錄裡是 `LIVE ⏱` 那行。

## 大腦 v4（2026-10-21）
- 從 v3 接著練 240 分鐘（`--pretrain-min 0 --finetune-min 240 --quiz-lr 3e-4 --ent-per-q 1`），多練「提到同一個名字、但在講別的事」的段落（別篇文章裡含有問題中最少見三字詞、又沒有答案的段落，標成次要）。
- DRCD dev 600 題：

  | 指標 | v4 | v3 |
  |---|---|---|
  | 答案 F1／完全答對 | **0.747**／0.588 | 0.743／0.588 |
  | 混進無關文章還挑得到答案 | 0.903 | 0.902 |
  | 混進「提到同一個名字」的段落還挑得到 | **0.898** | 0.894 |
  | 把這種段落誤判成主要 | **2.2%** | 4.7% |
  | 主次判斷 | 0.878 | 0.898 |
- 容器重開會中斷訓練：`scratchpad/v4/go.sh` 從 quiz.ckpt 接著練。

## 更快、不卡住（2026-10-21）
- `WebSearch.search`：各搜尋來源一起問，2.5 秒時已有 6 筆以上（或 4 秒時有任何結果）就先用，不再為了一個很慢的來源等滿 6 秒；`soon()` 幫維基、即時答案、輕量查詢設上限。
- `Understanding.voteNumber`：「瑞士8個國家共同經營」這種數字前面緊接另一個名字的「N個」不算總數。
- `Think.wholeName`：大腦框到半個名字（「文西」）時補成完整的（「達文西」）；「珠穆朗瑪峰頂峰」→「珠穆朗瑪峰」。
- 「怎麼辦」題多認得「治療、緩解、多喝、服用、補充」這類建議句。

## 翻譯（2026-10-22）
- `EchoCore/Translate/Translate.swift`：聽懂「蘋果用西班牙文怎麼說」「把X翻成英文」「翻譯：…」「gracias 是什麼意思」、英／西／義文的 translate…、cómo se dice…、come si dice…；判斷原文語言。
- `EchoCore/Translate/Lexicon.swift` ＋ `NineSun/Resources/lexicon.tsv`（`ai/build_lexicon.py` 產生）：離線字典，英文（ECDICT，MIT）、中文／西班牙文／義大利文／阿拉伯文（維基詞典，CC BY-SA 3.0，經 Vuizur/Wiktionary-Dictionaries），只收常用詞（hermitdave/FrequencyWords 詞頻，MIT）。中文附拼音、阿拉伯文附拉丁拼音、西／義動詞變化形會指回原形。三種外語之間用英文當橋樑反查。
- App：單字先查字典 → 整句用 iOS 18 內建翻譯（`AppleTranslator`，第一次會請使用者下載語言包，之後離線）→ AI 金鑰 → MyMemory 線上翻譯。`Translation` 用 weak link，iOS 16 照樣能開。
- 重新產生字典：`python3 ai/build_lexicon.py ECDICT_DIR WIKT_DIR FREQ_DIR ios/NineSun/Resources/lexicon.tsv`
