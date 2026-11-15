#!/bin/bash
# Usage: hubsign.sh <unsigned.shortcut> <name> <out.shortcut>
# Signs a shortcut through RoutineHub's public HubSign service (no Apple ID needed).
set -u
IN="$1"; NAME="$2"; OUT="$3"
TMP=$(mktemp -d)
plutil -convert xml1 -o "$TMP/sc.xml" "$IN"
python3 - "$NAME" "$TMP/sc.xml" > "$TMP/body.json" <<'PY'
import json,sys
print(json.dumps({"shortcutName": sys.argv[1], "shortcut": open(sys.argv[2]).read()}))
PY
for try in 1 2 3; do
  code=$(curl -sS -m 60 -o "$TMP/signed.bin" -w "%{http_code}" -H "Content-Type: application/json" \
    --data-binary @"$TMP/body.json" https://hubsign.routinehub.services/sign)
  echo "HubSign [$NAME] try $try -> HTTP $code, $(wc -c <"$TMP/signed.bin") bytes, magic: $(head -c 4 "$TMP/signed.bin")"
  if [ "$code" = "200" ] && [ "$(head -c 4 "$TMP/signed.bin")" = "AEA1" ]; then
    cp "$TMP/signed.bin" "$OUT"; echo "SIGNED OK $NAME"; exit 0
  fi
  head -c 300 "$TMP/signed.bin"; echo
  sleep $((try * 3))
done
exit 1
