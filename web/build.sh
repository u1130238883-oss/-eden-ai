#!/bin/sh
# 建置 NineSun 網頁測試版：EchoCore → WebAssembly → 去掉除錯資訊 → gzip → 切成 <10MB 的小檔
# 需要 SwiftWasm 6.0.3 工具鏈（SWIFT_BIN 指到它的 usr/bin）
set -e
cd "$(dirname "$0")"
SWIFT_BIN=${SWIFT_BIN:-/opt/swiftwasm/swift-wasm-6.0.3-RELEASE/usr/bin}
export PATH="$SWIFT_BIN:$PATH"
(cd NineSunWeb && swift build --triple wasm32-unknown-wasi -c release --static-swift-stdlib)
OUT=site/dist
rm -rf "$OUT" && mkdir -p "$OUT"
python3 tools/strip.py NineSunWeb/.build/wasm32-unknown-wasi/release/NineSunWeb.wasm "$OUT/ns.wasm"
gzip -9 -c "$OUT/ns.wasm" > "$OUT/ns.wasm.gz" && rm "$OUT/ns.wasm"
gzip -9 -c ../ios/NineSun/Resources/ninesun.bin > "$OUT/model.gz"
split -b 9500000 -d -a 1 "$OUT/ns.wasm.gz" "$OUT/engine-" && rm "$OUT/ns.wasm.gz"
split -b 9500000 -d -a 1 "$OUT/model.gz" "$OUT/model-" && rm "$OUT/model.gz"
for f in "$OUT"/engine-* "$OUT"/model-*; do mv "$f" "$f.wasm"; done
# 其他資料檔合成一個 JSON（檔名 → 內容字串）
python3 - <<'PY'
import json
R = "../ios/NineSun/Resources/"
names = ["ninesun.json", "i18n.json", "chat_bank.json", "palace_lexicon.json",
         "knowledge_zh.json", "knowledge_en.json", "knowledge_es.json", "knowledge_it.json"]
json.dump({n: open(R + n, encoding="utf-8").read() for n in names}, open("site/dist/data.json", "w", encoding="utf-8"), ensure_ascii=False)
PY
ls -la "$OUT"
