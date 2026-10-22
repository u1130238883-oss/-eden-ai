#!/usr/bin/env python3
"""對 project.pbxproj 做結構檢查：括號配對、ID 定義／參照一致、檔案確實存在。"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "ios", "NineTwelve.xcodeproj", "project.pbxproj")
IOS = os.path.join(ROOT, "ios")

errors = []


def fail(msg):
    errors.append(msg)


text = open(PROJ, encoding="utf-8").read()

# 1. 括號配對（先移除註解與字串）
# 順序重要：先把字串換掉，否則字串裡的 /* 會被當成註解開頭
stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
stripped = re.sub(r"/\*.*?\*/", "", stripped, flags=re.S)
for open_c, close_c in (("{", "}"), ("(", ")")):
    if stripped.count(open_c) != stripped.count(close_c):
        fail(f"括號不配對 {open_c}{close_c}: "
             f"{stripped.count(open_c)} vs {stripped.count(close_c)}")

# 2. 收集定義的 ID（行首的 <ID> = {isa = ...）
defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", text, flags=re.M))
if not defined:
    fail("找不到任何物件定義")

# 3. 收集所有出現的 ID，確認都有定義
referenced = set(re.findall(r"\b([0-9A-F]{24})\b", stripped))
missing = referenced - defined
if missing:
    fail(f"參照到未定義的 ID: {sorted(missing)}")

unused = defined - referenced
# rootObject 之外每個物件都該被參照到
if unused:
    fail(f"定義後未被參照的 ID: {sorted(unused)}")

# 4. isa 一定要有
for oid in defined:
    m = re.search(re.escape(oid) + r"[^=]*= \{\s*(?:\n\t+)?isa = (\w+)", text)
    if not m:
        fail(f"{oid} 缺少 isa")

# 5. 每個 PBXFileReference 的檔案要真的存在（依群組路徑推算）
#    這裡直接比對來源目錄裡的 .swift 數量
refs = re.findall(r"isa = PBXFileReference;.*?path = \"?([^\";]+)\"?;", text)
swift_refs = sorted(r for r in refs if r.endswith(".swift"))
actual = []
for base, dirs, files in os.walk(IOS):
    dirs[:] = [d for d in dirs if not d.endswith((".xcodeproj", ".xcassets"))]
    actual += [f for f in files if f.endswith(".swift")]
actual = sorted(actual)
if swift_refs != actual:
    fail(f"檔案參照與磁碟不符\n  pbxproj: {swift_refs}\n  磁碟   : {actual}")

# 6. 必要欄位
for key in ("rootObject", "objectVersion", "mainGroup", "productRefGroup"):
    if key not in text:
        fail(f"缺少 {key}")

# 7. 兩個 target 都在
for t in ("com.apple.product-type.application", "com.apple.product-type.bundle.unit-test"):
    if t not in text:
        fail(f"缺少 target 類型 {t}")

# 8. scheme 存在且指向正確的 target id
scheme_path = os.path.join(IOS, "NineTwelve.xcodeproj", "xcshareddata",
                           "xcschemes", "NineTwelve.xcscheme")
if not os.path.exists(scheme_path):
    fail("缺少 shared scheme")
else:
    scheme = open(scheme_path, encoding="utf-8").read()
    for bid in re.findall(r'BlueprintIdentifier = "([0-9A-F]{24})"', scheme):
        if bid not in defined:
            fail(f"scheme 指向不存在的 target {bid}")

print(f"物件數: {len(defined)}   Swift 檔: {len(swift_refs)}")
if errors:
    print("\n檢查未通過：")
    for e in errors:
        print("  ✗ " + e)
    sys.exit(1)
print("pbxproj 結構檢查通過")
