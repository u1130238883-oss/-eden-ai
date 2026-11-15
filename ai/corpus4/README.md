# 四語翻譯測試語料（中文｜English｜Español｜Italiano）

- `w*.txt`：單字，一行「中文|English|Español|Italiano」，同一格用 / 分開其他說法。`#` 開頭是分類註解。
- `numwords.py`：0–999 的數字四語（演算法產生）。
- `nouns.py`：做短語、句子用的名詞（含西班牙文、義大利文的陰陽性、複數、冠詞）、形容詞（含變化）、動詞變化。
- `build.py`：組出 5000 單字、5000 短語、5000 句子 → `ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_corpus.json`。
語料全部人工撰寫或用規則組合，不是從翻譯引擎抓的。
