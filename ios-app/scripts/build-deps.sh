#!/bin/bash
# 在 macOS 上編譯 iOS 用的 OpenSSL（靜態庫）和 zsign，輸出到 build-deps/lib。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/build-deps"
OPENSSL_VERSION=3.0.15
ZSIGN_REF=9299685bab7ef99827e06e5dfda93af747386590
MIN_IOS=16.0
JOBS="$(sysctl -n hw.ncpu)"

mkdir -p "$DEPS/lib" "$DEPS/src"

# ---------- OpenSSL ----------
if [ ! -f "$DEPS/openssl/lib/libcrypto.a" ]; then
	cd "$DEPS/src"
	curl -fsSL "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" | tar xz
	cd "openssl-$OPENSSL_VERSION"
	# no-module：把 legacy provider 編進 libcrypto，舊版 p12（RC2 加密）才能打開
	./Configure ios64-xcrun no-shared no-module no-tests no-engine no-ui-console \
		--prefix="$DEPS/openssl" -mios-version-min=$MIN_IOS
	make -j"$JOBS" build_libs > /dev/null
	make install_dev > /dev/null
fi
cp "$DEPS/openssl/lib/libcrypto.a" "$DEPS/lib/"

# ---------- zsign ----------
cd "$DEPS/src"
rm -rf zsign
git clone -q https://github.com/zhlynn/zsign.git
cd zsign
git checkout -q "$ZSIGN_REF"

# iOS 不允許啟動子進程：去掉 csreq 調試輸出裡的 popen 調用
perl -0pi -e 's/ZFile::IsFileExists\("\/usr\/bin\/csreq"\)/false/; s/FILE\* cmd = popen\(strCommand\.c_str\(\), "r"\);/FILE* cmd = NULL;/; s/pclose\(cmd\);//' src/signing.cpp
grep -q 'FILE\* cmd = NULL;' src/signing.cpp

SDK_CC="xcrun -sdk iphoneos clang -arch arm64 -mios-version-min=$MIN_IOS -O2 -Wno-unused-result"
INC="-Isrc -Isrc/common -Isrc/third-party/zlib -I$DEPS/openssl/include -I$ROOT/bridge"
OBJ="$DEPS/obj"
rm -rf "$OBJ"
mkdir -p "$OBJ"

for f in src/*.cpp src/common/*.cpp "$ROOT/bridge/zsign_bridge.cpp"; do
	[ "$(basename "$f")" = "zsign.cpp" ] && continue   # 命令行入口，不需要
	name="$(basename "${f%.*}")"
	$SDK_CC -x c++ -std=c++11 $INC -c "$f" -o "$OBJ/cxx_$name.o" &
done
for f in src/third-party/zlib/*.c src/third-party/minizip/ioapi.c src/third-party/minizip/zip.c src/third-party/minizip/unzip.c; do
	name="$(basename "${f%.*}")"
	$SDK_CC -x c -Isrc/third-party/zlib -c "$f" -o "$OBJ/c_$name.o" &
done
wait

# 確認全部編譯成功
expected=$(( $(ls src/*.cpp src/common/*.cpp | grep -vc '/zsign.cpp$') + 1 + $(ls src/third-party/zlib/*.c | wc -l) + 3 ))
actual=$(ls "$OBJ"/*.o | wc -l)
if [ "$expected" -ne "$actual" ]; then
	echo "編譯失敗：期望 $expected 個目標文件，實際 $actual 個" >&2
	exit 1
fi

rm -f "$DEPS/lib/libzsign.a"
libtool -static -o "$DEPS/lib/libzsign.a" "$OBJ"/*.o
echo ">>> deps OK"
ls -la "$DEPS/lib"
