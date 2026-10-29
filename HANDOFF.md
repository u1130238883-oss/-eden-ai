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

## 分兩步想（`Web/MultiStep.swift`，2026-10-22）
- 「A比B高多少」「A和B哪個高」「A是B的幾倍」「A和B相差多少」：拆成兩個小問題（「A有多高」「B有多高」）同時查，換成同一個單位再相減／比大小／算倍數；回答會列出每一步（①②③）。問「A比B高多少」但其實 A 比較矮時照實講。
- 名單：`Understanding.countedList`——句子自己說「這五個國家」、列出的數目也對得上，直接用（修正北歐漏掉瑞典、挪威）。

## 大腦 v5 試訓（2026-10-22，沒有採用）
- 多加 XQuAD 中文版（1,190 題）＋ C3 答案在原文裡的題目（3,769 題，含「為什麼」題）接著 v4 練，跑到約 120 分鐘被背景時間上限停掉。
- 最好的一次：f1 0.731、pick_mix 0.895；v4 是 0.747、0.903 → v5 比較差，App 繼續用 v4。可能是 C3 的對話體、翻譯腔和考試用的 DRCD 差太多。
- 進度存在 scratchpad 的 v5/quiz.ckpt，`v5/go.sh` 可以接著練。

## 安慰（`Solace.swift`、`ai/solace.py`，2026-10-22）
- 說心情（累、難過、失戀、壓力、焦慮、失眠、孤單、迷茫、生氣、自我懷疑、工作、家裡、錢、朋友、身體）時，安全檢查之後最先由它接。
- 用生日看此刻四層：這幾年（大運）、今年（流年）、這個月（流月）、今天白天的日宮／今晚的夜宮；照九型十二宮 App 的讀法說「起因 → 場域 → 呈現出來的樣子」，挑最貼近這個心情的那一層細說。
- 再看：這十年大運十二方面的那一方面（感情 7、工作 10、家 4、錢 2、朋友 11、身體 8）、本命盤裡這件事是敏感處（壞）還是力量（好）。
- 心裡的痛用西方星盤同一宮的角度；壓力、焦慮、自我懷疑用九型文件裡「壓力時／安定時走向第幾型」。最後是什麼時候會鬆開（下一個好的流月、明年、大運結束）、今天的一件小事、陪伴的話。很重的話加 1925 安心專線。
- 九型十二宮把生日化成年、月、日三個 1–9：729 種組合，年月對調本命相同 → 405 種本命盤；大運、流年因實際出生年不同。`scratchpad/solace_eval.py` 把 729 種 × 不同出生年 × 不同時間 × 不同心情全部跑過，檢查溫柔用詞、沒有代號、長度、有沒有講什麼時候會好。
- Swift 與 Python 逐字一致：`python3 ai/solace.py fixture ios/EchoCore/Tests/EchoCoreTests/Fixtures/solace.json`；詞表由 `ai/gen_solace_swift.py` 產生 `SolaceData.swift`。
- 「全部交給 AI」時，說心情的話還是由 NineSun 用命盤接（AI 看不到你的大運流年）。

## 日常問題交給 AI、NineSun 自己的個性（2026-10-22）
- 使用者要求：九型十二宮的命理、運勢、個人情緒留在 NineSun 底層；其他生活瑣事交給 API 回答，App 裡不存日常問題的固定答案（省空間）。
- 拿掉：`chat_bank.json`（腦筋急轉彎、思路庫）與 `ChatBank.swift`、`ai/chat_bank.py`、`ai/claude_playbook.py`；翻譯字典 `lexicon.tsv`（13MB）、`Lexicon.swift`、`ai/build_lexicon.py`。翻譯改成：已下載的內建翻譯 → AI → 線上翻譯。
- 留下：`knowledge_*.json`（卦、紫微、九型、五行…命理知識）、`reader.bin`（沒金鑰時自己上網讀網頁用）、`ninesun.bin`（命盤解讀的模型）。
- 路由（`ChatViewModel.staysLocal`）：有金鑰時，命理字、心情（`Solace.isFeeling`）、規則指令、「上網查」、打招呼（`Companion.isSmallTalk`）留在本地，其他都交給 AI；沒有金鑰或 AI 失敗 → NineSun 自己上網查。設定頁拿掉「全部交給 AI」「沒把握時自動問」兩個開關，改成說明。
- 個性（`AskAIs.chatSystem`）：NineSun 是會發光的小電視機器人夥伴，溫暖、真誠、有點俏皮、有自己的看法；先抓真正的需求、先講結論、用生活比喻、多想一步。`AskAIs.persona(type:)` 依使用者的九型調整說話方式。接哪一家 AI、融合時都用同一個個性。

## 翻譯：蘋果內建優先、念出來、10000 題問法（2026-10-22）
- 設定新增「用 AI API 回答」：關掉就完全不呼叫 AI 的 API；「翻譯後念出來」（AVSpeechSynthesizer，`NineSun/App/Speaker.swift`）。
- 翻譯順序：蘋果內建翻譯（iOS 18，第一次下載語言包，之後離線）→ Google 翻譯（免金鑰的網頁介面）→ AI（開 API 時）→ MyMemory。App 不存字典。
- 聽懂問法：`Translate.understand` 拆開來想——只提到一種語言 → 找「語言那一段」（用英文說／翻成英文／的英文是什麼）且要有翻譯的意思 → 判斷內容在前面還是後面 → 去掉「請問、教我、跟他說」這些包裝。回答第一行「🧠 我理解成：把「X」從中文翻成英文」。
- 測試：`python3 ai/translate_questions.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_questions.json` 產生 10000 題（9000 題各種問法、1000 題不是翻譯的），`TranslateQuestionsTests` 逐題檢查。第一輪 7821 題對 → 第二輪 9928 → 第三輪 10000。
- 第二批 10000 題（`translate_questions2.json`，`python3 ai/translate_questions.py … 2`）：新問法（怎樣說、咋說、X（英文）、英文：X、英文的話X怎麼說、X這句話英文怎麼說、怎麼講比較道地）、開頭的包裝（那、還有、嗨、NineSun、我想知道、想問、如果要）、簡稱（中翻英、翻西、X 翻英、X翻成義文）、英西義的新說法。第一輪 6220 → 第二輪 9796 → 第三輪 10000。
- App：原文語言用手機內建的語言辨識（`NineSun/App/LangID.swift`，NaturalLanguage）；句子翻完再翻回原文核對（🔁）；單字補 Google 字典的其他說法；念的時候挑手機裡最好的聲音。

## 四語翻譯語料 15000 項、Hollow 新版（2026-10-22）
- `ai/corpus4/`：5000 單字（人工撰寫約 3900＋0–999 數字）、5000 短語（形容詞＋名詞、數量＋名詞、我的／這個／那個＋名詞、動詞＋名詞，西義陰陽性、複數、冠詞照規則變化）、5000 句子（主詞×動詞×名詞、這個很…、在哪裡、多少錢…）。`python3 ai/corpus4/build.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_corpus.json`。
- `TranslateCorpusTests`：每一項四種語言輪流當原文、包進約 20 種問法（中文、英西義），共 60000 次都要聽懂；道地說法表對到時要跟語料一致（人工看過、兩種都對的列在 reviewed）。第一輪 59259 → 第二輪 59910 → 第三輪 60000。
- 修掉的：「主要」「現在」尾巴的字被吃掉、「那輛機車」的「那」被當口頭禪、內容本身是「請問／翻譯」、內容是語言名稱（Italian 用義大利文怎麼說）、一句裡兩個語言名稱（把日文翻成英文）；道地說法表的外文單字一字多義（ojo、tranquilo、ánimo）不再查表。
- `TranslateLiveTests`（CI「Live translation check」）：抽 120 項用 Google 翻譯，跟語料比，列出不一樣的，常見又翻錯的補進 Native.swift。
- 新版 Hollow.ipa：只多了 11宮關鍵詞「貴人」，算法逐位元組相同；NineSun 四語關鍵詞、宮位感知詞表同步。
- 流年「合起來看」加上牽涉的人（起因宮的人 → 帶來好結果那幾宮的人）。

## 2026-10-23：正的意思、405 種本命盤、上網抓答案

- **正 ＝ 年宮和月宮同五行**：引擎在這時果＝日宮本身，等於把這一宮的能量放大——是「能量強」，不是平平、不是中性。
  所有寫到正的地方（FlowReading 的果宮表、PalaceLore、Reader 的判讀句、Solace、FullReading、Planner）都改成「能量很強，好壞看你怎麼用」；
  外語的 verdict 名稱（Aligned…）因為模型字表也有，暫時沒改。
- **405 種本命盤**：出生三數（年、月、日各化成 1–9）有 9×9×9＝729 種，但年數和月數對調得到同一張盤（`read` 對年、月對稱），
  所以只有 405 種：81 種沒有雙胞胎，324 種兩兩相同（`ai/ninetwelve.py` 驗證）。
- **命宮**：①「你是誰」改成講本質（`FlowReading.whoYouAre`：命宮所在宮＝本質，判讀＝一生常出現的模式），不再寫「感情桃花這塊」。
- **解讀白話**：`FlowReading.plain`＝本宮這塊 × 果宮好壞 × 起因（「起因在工作、事業本身」）。
- **翻譯**：完全不用蘋果內建翻譯（`.translationTask` 隨時可能跳系統畫面）；道地說法表 → AI（開 API）→ Google → MyMemory。
- **上網抓答案**（`Web/Synthesize.swift`）：好幾個網站的內容拆成重點 → 丟掉標題、文章簡介（「這篇文章旨在…」）、hashtag、廣告 →
  講同一件事的分成一群、記下幾個網站都提到 → 先給結論、再列重點，用自己的話寫。
  建議題（X怎麼辦、要注意什麼、有什麼方法）理解成「做法」、直接上網（`EchoEngine.practical`），做法題不讀百科；查不到能照著做的方法就老實說。
- **搜尋來源**：加了 DuckDuckGo 輕量版、Brave、Mojeek、百度（通用的結果解析 `WebSearch.genericResults`，不靠 CSS 名稱）。
- **開著 API＋有 Gemini 金鑰**：要查資料的問題都讓 Gemini 用 Google 搜尋回答（`AskAIs.wantsSearch`），附上它讀過的網站；聊天、命盤解讀不搜尋。
- **網頁錄音帶**（`Web/WebTape.swift`、`.github/workflows/web-tape.yml`）：commit 訊息有 `[tape]` 時 CI 真的上網查
  `Fixtures/web_questions.txt` 的問題，錄下搜尋結果和網頁文字，發佈成 release `web-tape-N`；
  離線重播：`NINESUN_TAPE=web_tape.json swift test -c release -Xswiftc -enable-testing --filter WebTapeTests/testReplay`。
  注意：GitHub 的機器上 Google、Yahoo、DuckDuckGo、Mojeek 幾乎都被擋，Bing 給不相關的結果，所以錄到的網頁九成是維基百科——
  真正的效果要在手機上看。

## 2026-10-23：中文理解訓練 50,000 題、作品題、專業來源、畫面閃黑

- 中文理解訓練：見 `ai/understanding/README.md`（50,000 題訓練＋4,110 題沒看過的驗證題，兩組都 100%；錯誤類型、人會怎麼想、怎麼改都寫在裡面）。
  路由順序：拿掉客套話 → 問命（`fortuneAsk`）／說自己的心情（`selfFeeling`）／跟 NineSun 聊天 → 其他問世界上的事（`worldQuestion`）上網。
- 作品題：書名、片名裡的「煩惱」「孤獨」不是心情（`asksAboutWork`）；打錯字的書名照搜尋結果修正（`Understanding.spellFix`）。
- 專業來源：`Cite.field` 判斷領域，`Cite.proQuery` 用 site: 指定去國健署、康健、經理人、天下、博客來……找；整理重點時專業平台加分、口語扣分。
- 畫面閃黑：打字泡泡換成正式訊息時，以前先拿掉泡泡再淡入新訊息，中間空一下 → 改成同一瞬間換掉、不做動畫（`ChatViewModel.finish`）。

## 2026-10-23（晚）：十二個方面的 500,000 題訓練

每一方面都有：產生題目的程式（`ai/…/gen.py`，500,000 題）＋沒看過的驗證題（`--holdout`，20,000 題，用沒看過的詞、問法、句型）＋
Swift 測試（平常跑 20,000 題樣本＋驗證題；設環境變數跑全部 500,000 題）。錯的題目依類型分組寫到檔案，照「人會怎麼想」改通用的步驟。
各方面的錯誤和怎麼教的，寫在各自的 README。

| 方面 | 模組 | 題目 | 測試 |
|---|---|---|---|
| 中文理解（問的是什麼） | `Web/Understanding.swift`、`EchoEngine.tidy` | `ai/understanding/gen.py --n 500000` | `UnderstandingCorpusTests`（`NINESUN_UNDERSTAND_FILE`） |
| 近義詞 | `Synonyms.swift` | `ai/lexicon/gen_tests.py` | `SynonymTests`（`NINESUN_SYN`） |
| 反義詞 | `Antonyms.swift` | `ai/lexicon/gen_antonym_tests.py` | `AntonymTests`（`NINESUN_ANT`） |
| 中英西義互譯 | `Translate/Translate.swift` | `ai/translate/gen.py` | `TranslateTrainTests`（`NINESUN_TR`） |
| 情感（聽出心情、用對語氣） | `Affect.swift` | `ai/affect/gen.py` | `AffectTests`（`NINESUN_AFF`） |
| 認知（網頁的句子能不能當答案） | `Web/Judge.swift` | `ai/cognition/gen.py` | `CognitionTests`（`NINESUN_COG`） |
| 成語：理解、近義、反義、翻譯 | `Idioms.swift`（`ai/idioms/idioms.py`，387 個成語） | `ai/idioms/gen.py {understand,near,anti,translate}` | `IdiomTests`（`NINESUN_IDIOM_DIR`） |
| 個性（405 種人） | `Voice.swift` | `ai/idioms/gen.py voice` | `VoiceTests`（`NINESUN_VOICE`） |
| 寫作：詳寫、擴寫（中英西義、至少 9 倍長）、修改 | `Writer.swift` | `ai/writing/gen.py` | `WriterTests`（`NINESUN_WR`） |
| 詞性＋仿寫 | `Grammar.swift` | `ai/grammar/gen.py` | `GrammarTests`（`NINESUN_GR`） |

- **個性**：九型十二宮的本命盤 9×9×9＝729 種，年、月互換是同一張盤 → 405 種不同的人（`Voice.all`）。
  九型的三個中心（情感 2/3/4、思考 5/6/7、本能 8/9/1）決定開口的方式；本命第一宮的好／正／壞決定能量（正＝能量強，語氣加重）；
  日的數字決定帶出成語的口頭禪；年、月的數字決定偏好哪一句成語。同一句「我好難過」，405 個人有不同的回應。
- **寫作**：先寫平淡的第一稿 → 自己檢查（字數至少 9 倍、環境、感受、觀點、比喻、成語／諺語、層次、高級詞、情緒衝突、重複）→
  一次改兩個問題 → 再檢查，直到沒有問題。回覆裡附上改了幾次、改了什麼。
- **詞性**：不認得的詞先看最確定的線索（的、地、著、了、很），再用鄰居一步一步推，最後才看字的意思。
- 引擎的順序：安全 → 規則 → 詞性／仿寫 → 寫作 → 名人命盤 → 成語 → 反義詞 → 近義詞 → 問世界上的事 → 安慰 → ……
  回答最後再由 `Affect.color` 依心情加上第一句（有生日的話用這個人的個性和成語）。

### 最後的成績（2026-10-24，全部 500,000 題＋沒看過的驗證題）

| 方面 | 訓練題 | 沒看過的題 |
|---|---|---|
| 中文理解 | 100% | 100% |
| 近義詞 | 100% | 100% |
| 反義詞 | 100% | 100% |
| 中英西義互譯 | 99.997%（500,000 題錯 14 題，都是「請問的義大利文」這種本來就有兩種讀法的） | 100% |
| 情感 | 100% | 100% |
| 認知 | 100% | 100% |
| 成語：理解、近義、反義、翻譯 | 100% | 100% |
| 個性（405 種人） | 100% | 100% |
| 寫作（20,000 題樣本） | 100% | 100% |
| 詞性＋仿寫 | 100% | 100% |

全部測試（`swift test`）：152 個，0 個失敗（7 個要上網的測試在離線時跳過）。

## 2026-10-24：不讀維基百科、作品題重寫

- 使用者回報：問「少年維特的煩惱講了什麼」，回答引了維基百科頁尾的「參見…外部連結…維基共享資源」和翻譯版本，沒有講內容。
  使用者的判斷：維基百科太長，NineSun 抓不到重點 → **全部不讀維基百科**（`WebSearch.isWiki`／`withoutWiki`：搜尋結果、即時摘要、打開網頁都過濾，鏡像站也算）。
- 作品題（`Understanding.workTitle`、`Think.aboutWork`）：書名不從「的」切開；回答分三段——它是什麼（誰的什麼作品）→ 📖 講了什麼故事 → 💡 想表達什麼；
  改編、翻譯、出版、寫作經過、頁尾連結不算內容；找不到講內容的句子就不硬湊（`conclude` 對作品題不放寬條件）。
- `web_questions.txt` 加了 49 題作品題，`[tape]` 錄新的網頁（web-tape-19）；重播時記得維基已經被過濾，能用的網頁會變少。

## 2026-10-24（下午）：搜尋引擎的問題（使用者：「為什麼查到的都是垃圾？」）

- **探針**（`.github/workflows/search-probe.yml`＋`SearchProbeTests`，commit 訊息有 `[probe]` 時跑）：同一批問題丟給每個搜尋引擎、每種寫法，數有幾筆跟問題有關。
  在 GitHub 的機器上：Bing 給的是**別人查的東西**（問小說給股價、問失眠給披薩，有沒有 cookie 都一樣，79 筆只有 8 筆相關）；
  Google、Yahoo、Brave、Mojeek、Startpage、Yandex、Ecosia、Qwant 全被擋；**DuckDuckGo 先開首頁拿 cookie 再用 GET 查：80 筆 67 筆相關**；百度 41 筆 34 筆。
- 改法（`WebSearch`）：DuckDuckGo 用有 cookie 的連線；順序 DuckDuckGo → 百度 → Bing；整批都跟查詢無關的結果丟掉（`poisoned`）；
  網址編碼只留 ASCII（`CharacterSet.alphanumerics` 連中文都算字母）；
  **像人一樣慢慢查**（`Pace`）：每個搜尋引擎短時間只問幾次，被擋（驗證頁、429）就休息 2～3 分鐘；都在休息時老實說「被擋了，等一下再問」（`webBlocked`）。
- GitHub 的機器問十幾次就被 DuckDuckGo 封住 IP，所以完整的 185 題錄不出東西；`[tape] [focus]` 只錄 6 題、每題隔 40 秒（`web_questions_focus.txt`）。
- 作品題用真實網頁（web-tape-28）訓練：
  - `Synthesize.compose` 會把整理好的作品答案蓋成「綜合 N 個網站的重點」（讀書心得的閒聊）→ 已經照結構整理的答案（`digested`）不再被蓋、不附「換個角度」；
  - 劇情句的分數：真的在說故事（描寫、講述）＞故事裡發生的事（愛上、誤闖、自殺）＞只提到「情節」；寫作經過（源自、寫下）扣分；
  - 像人一樣往下讀：最好的劇情句後面一兩句在說後來發生的事，就接著說（「之後，維特…而自殺」）；
  - 沒提書名的句子要開頭就是「小說／故事／書中…」，有別的《書名》、清單文章介紹的別部作品不算；同一件事不說兩次。

## 2026-10-24（晚）：有主見的作品回答、自己訓練的理解問題模型、為什麼題

- **作品題**（`Think.aboutWork`＋`Web/WorkView.swift`）：它是什麼 → 📖 故事（最好的劇情句＋同一頁接下來發生的事，整理成一段話）→ 💡 主題（20 種主題，用自己的話解釋＋根據）→ 🧠 我的看法（表面的主題 vs 真正讓它成為經典的主題、適合誰）。
  用真實網頁練：web-tape-28、30（8 部），沒練過的 web-tape-40（6 部）驗證後再修通用的規則（遊戲／改編／外傳不是原作、論壇碎片、寫作經過、沒有好的劇情句就不說故事）。
- **清單題**（`Understanding.itemsAsk`、`Think.itemsDigest`）：「格林童話有什麼故事」→ 列出最常被提到的幾個、各在講什麼、看法。
- **理解問題的模型**（`ai/intent/`、`EchoCore/Intent.swift`、`Brain.meaning`）：NineSun 自己從零訓練（NumPy），字的片段＋自己的閱讀模型讀出來的意思；
  第三組沒看過的說法 89.1%（只背模板 65.7%）。規則認不出、模型有把握時決定用清單或作品的回答方式。見 `ai/intent/README.md`。
- **為什麼題**（`Synthesize.score` 的 `.reason`）：原因句要講到問的那一點（「藍」）、真的說因果；歷史、「並無法解釋」、「依然…」（補充）不當主要原因。
- **Apple 智慧已拿掉**（2026-10-28）：手機語言是義大利語時 Apple 智慧要求 Siri 同語言才能開，使用者決定不用，要 NineSun 只用自己訓練的大腦。設定恢復成「用 AI API 回答」開關。
- **Release 被擋（403）**：大約 16:30 之後 Actions 建立 release 一直 403（token 有 contents: write）。錄音帶另外推到分支 `tapes/web-tape-N`、IPA 推到 `builds/ninesun-build-N`
  （下載：`https://github.com/u1130238883-oss/-eden-ai/raw/builds/ninesun-build-N/NineSun.ipa`）。
- 每次 push 都會跑一次 50 分鐘的建置，macOS 機器有限：一次推好幾個 commit 時，舊的建置可以取消，免得錄音帶排不到機器。

## 2026-10-28：簡單的問題自己答（使用者：「我問他一些簡單的問題，他都答不上來」）

- 先量：69 題日常簡單問題（1加1、今天星期幾、台灣的首都、鯨魚是魚嗎、怎麼煮白飯、推薦一部電影…），**幾乎全部都丟去上網**
  （連「1加1」都是，因為「問世界上的事就上網」排在計算前面），手機一查不到就答不出來。
- **Everyday.swift**（用算的）：現在幾點、今天／明天／後天幾號星期幾、農曆、今年生肖和民國年、閏年、某天星期幾、
  離聖誕節／過年／某月某日還有幾天、單位換算（長度、重量、台斤、容量、時間、面積、資料、溫度）、
  中文數字計算（「兩千五加一千五」「九十九乘九十九」「三的平方」「根號144」「五百的20%」「一百塊打八折」）。
- **Commonsense.swift＋ai/commonsense**（自己的常識，見 `ai/commonsense/README.md`）：342 筆事實（68 國、59 種動物、宇宙、自然、人體、
  54 位人物、21 項發明、24 個節日、地標、組織）、58 個「最…的」、20 種做法、10 類推薦、6 個比較題的看法。
  資料是事實不是回答：讀懂問的是哪個東西、問它的什麼，再推出答案（是不是、會不會、能不能吃、反查作者和首都、為什麼）。
  聊到某個東西（「貓咪好可愛」）就像朋友一樣接話，說一件自己知道的事（`Commonsense.react`），不再用宮位亂回。
  不該攔下來的：算命、心情（「我難過到睡不著」先陪他）、作品內容、時事、明白叫我上網查的。
- 驗證：
  - 練習用的 69 題全部答對；**沒練過的新問法**第一批 92%→修通用問題後全對，第二批 78 題全對（剩下的時事題照樣上網）。
  - 10,110 題理解語料庫：本地回答時必須是在講問題問的那個東西才算對——一開始抓到很多認錯主角的
    （「挪威的森林」→挪威、「老人與海」→人、「聖嬰現象」→大象、「曬太陽」→太陽、「發明飛機的人」→人類）→ 加上名字前後的字要合理的規則後 100%。
- 拿掉 Apple 智慧（使用者手機用義大利語，Apple 智慧要 Siri 同語言；而且要的是自己的 AI）。

## 2026-10-28（晚）：NineSun 的大腦——手機上跑的大型語言模型

- 使用者覺得還是太笨，問有沒有非常聰明的辦法。說明了光靠從零訓練（沒有 GPU）做不到真的會思考，使用者選了
  **放開源模型到手機**：完全在手機上跑、不用網路、不用 API。
- 架構（`ios/NineSun/Brain/`）：
  - `LlamaRunner.swift`：包 llama.cpp 的 C API（讀模型、切字、分批運算、取樣：重複懲罰＋top-k＋top-p＋溫度、停止字、UTF-8 完整才輸出）。
  - `LocalBrain.swift`：NineSun 的提示（個性、說話規則、今天日期、九型的說話方式）、Qwen 的 ChatML 格式（先放空的思考，不長篇思考）、
    把引擎的事實／網路資料／命盤結果當成正確的資料交給它、對話紀錄、輸出整理（去 Markdown、ICU 簡轉繁、大陸用語換台灣用語）。
  - `ModelStore.swift`：第一次用時下載模型（背景下載、可續傳、換鏡像、檢查 GGUF 開頭和空間），IPA 本身不放模型。
  - `ChatViewModel`：大腦下載好、沒開雲端 API 時——引擎先算（命盤、日期、常識）、要最新資料的先上網（`EchoEngine.needsFreshInfo`），
    再交給大腦寫回答（一邊寫一邊顯示）；時間、計算、換算、規則照引擎的；大腦讀不進來就用引擎原本的回答。
  - 設定頁「NineSun 的大腦」：下載、進度、選模型、刪除、測試（顯示速度）。
- llama.cpp 版本固定在 `ios/llama-version.txt`；IPA 的建置會照這個版本編 iOS 的 framework 放進 App（`ios/Frameworks/`，不進 git）。
- 選模型（`.github/workflows/brain-eval.yml`，commit 訊息有 `[brain]`）：在 GitHub 的 Mac 上真的下載模型、用 NineSun 的提示問問題。
  - Qwen3.5 2B：中文流暢但會算錯、編地名、跟給它的事實唱反調 → 只當「輕量」選項。
  - Qwen3.5 4B（Q4_K_M，2.74 GB）和 Qwen3 4B 2507：聰明很多；3.5 4B 比較簡潔、判斷比較好 → **標準**。
  - 兩個都會編出不存在的地名店名 → 某個地方可以去哪、吃什麼的問題先上網查，再交給大腦整理。
  - GitHub 的 Mac 沒有可用的 GPU，CPU 只有每秒 0.3～1.5 個 token；手機用 Metal 會快很多。
- 還沒在真的 iPhone 上驗證速度和記憶體：4B 讀不進來（舊手機、記憶體不夠）時改用輕量的 2B。

## 2026-10-29：成人模式（18+）

- 使用者要大腦能做成人角色扮演。設定「NineSun 的大腦」底下加「成人模式（18+）」：預設關，打開時要確認「我已滿 18 歲」；
  可以自己寫角色。打開後一般聊天交給大腦照角色回答（`LocalBrain.roleplaySystem`，溫度 0.85），說想死的話還是先接住（Safety），
  問運勢、命盤照常用命理。
- 底線寫在提示裡、不會拿掉：所有角色都是成年人、彼此自願、不寫真實存在的人；危險、違法的教學也不會因為成人模式打開。
- Qwen 本身比較保守 → 使用者要露骨的模型：加了「成人模式專用」的開放版（mradermacher/Huihui-Qwen3.5-4B-abliterated-GGUF，Q4_K_M，2.71 GB），
  只在成人模式打開時才看得到、才會用；一般聊天還是標準的 Qwen3.5 4B。
- 開放版不一定遵守提示，所以「不寫未成年」寫死在程式裡（`EchoCore/AdultGuard.swift`＋`AdultGuardTests`）：使用者的話、角色設定、
  大腦寫出來的字都檢查（未成年的詞、小於 18 的年紀），碰到就停下、不顯示、改成拒絕。

## 2026-10-29：只留開放模型、加更多模型

- 使用者要拿掉有限制的模型、多加不是千問的開放模型。`ModelStore.models` 現在全部都是開放（abliterated／無審查）模型，
  不再分「一般」和「成人模式專用」：預設開放版 Qwen3.5 4B；另有開放版 Gemma 4 E2B、開放版 Gemma 3 4B（mlabonne）、
  Dolphin 3.0（Llama 3.2 3B）、無審查 Llama 3.2 3B、開放版 Phi-4 mini、開放版 SmolLM3 3B、開放版 Qwen3.5 2B（輕量）、
  （實驗）Gemma 4 E4B 角色扮演版（5.3 GB，要 12 GB 記憶體的手機）。檔名和大小都是 Hugging Face API 列出來的（`model-list.yml`）。
- 拿掉的舊模型檔（標準 Qwen3.5 4B、輕量 2B）App 打開時會自動刪掉，空出空間。
- 不同家的模型對話格式不一樣：`LlamaRunner.chatPrompt` 用模型檔裡的格式（`llama_chat_apply_template`），
  Gemma 4（`<|turn>`）llama.cpp b11969 還不會排，自己排；Qwen 這種會思考的最後放空的 `<think></think>`。
  斷詞時照模型規定加開頭記號（Gemma、Llama 要）。`LocalBrain.stops` 收各家的結束記號。
- `brain-eval.yml` 改成測這些新模型，每台機器會先印出對話格式，看排得對不對。
- AdultGuard 不變：成人模式的使用者的話、角色、大腦寫的字都檢查。
