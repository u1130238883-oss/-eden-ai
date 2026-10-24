# 理解問題的模型（NineSun 自己訓練的）

一句話 → 這句話要的是什麼（16 種題型：列出有哪些、在講什麼、有幾個、是什麼、為什麼、怎麼做、怎麼辦、比較、看法、推薦、誰、哪裡、什麼時候、多少、是不是、聊天）。

## 怎麼練
1. `gen.py`：十幾萬句問法（主題換來換去，模型才會看問法、不是看主題）；一半的句子換成問法的近義詞（差別／區別／差異……）。
2. `encode.py`：用 NineSun 自己的閱讀模型（`reader.bin`，預先讀過大量中文）把每一句讀成「意思」（512 維）。
3. `train.py`：字的片段（1～3 個字，雜湊到 32768 格）＋意思 → 一層隱藏層 → 16 種題型。防死背：dropout、權重衰減、挑最好的那一輪。
4. Swift（`EchoCore/Intent.swift`、`Brain.meaning`）用一模一樣的數學；`IntentTests` 檢查跟 Python 算的一樣。

```
python3 ai/intent/gen.py --n 120000 > train.tsv; python3 ai/intent/gen.py --holdout --n 6000 > hold.tsv; python3 ai/intent/gen.py --holdout2 --n 4000 > hold2.tsv
for f in train hold hold2; do python3 ai/intent/encode.py ios/NineSun/Resources/reader.json ios/NineSun/Resources/reader.bin $f.tsv ${f}_enc.npy; done
python3 ai/intent/train.py train.tsv hold.tsv 輸出資料夾 train_enc.npy hold_enc.npy hold2.tsv hold2_enc.npy
```

## 成績（考的都是訓練時沒看過的說法）
| 版本 | 沒看過的說法 |
|---|---|
| 只看字的片段、說法少 | 65.7% |
| 多寫很多種說法 | 80.3% |
| ＋閱讀模型讀出來的意思 | 85.6% |
| ＋問法的近義詞 | 90.8% |
| **第三組（改進過程完全沒用過的說法）** | **89.1%** |

只靠背模板學不會舉一反三（訓練 100%、沒看過的 65%）；先懂字的意思（預先讀過大量中文的閱讀模型）、知道同一個意思有很多講法，才類推得到沒看過的說法。
還會錯的：「A與B的區別是什麼」（看到「是什麼」以為是問定義）、「X會不會很難」（是不是 vs 看法）。

## App 怎麼用
`Intent.shared`：規則認不出的問法，模型有把握（≥ 0.6）是在問清單（`Think.itemsDigest`）或作品內容（`Think.aboutWork`）時照那個方式回答。
