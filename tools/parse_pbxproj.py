#!/usr/bin/env python3
"""
用 NeXTSTEP／OpenStep 舊式 plist 文法真正解析 project.pbxproj，
確認 Xcode 能讀得懂，並對解析出來的物件圖做語意檢查。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "ios", "NineTwelve.xcodeproj", "project.pbxproj")


class Parser:
    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        col = self.i - self.s.rfind("\n", 0, self.i)
        raise SyntaxError(f"{msg}（第 {line} 行第 {col} 欄）")

    def skip(self):
        while self.i < self.n:
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif self.s.startswith("//", self.i):
                j = self.s.find("\n", self.i)
                self.i = self.n if j < 0 else j + 1
            elif self.s.startswith("/*", self.i):
                j = self.s.find("*/", self.i + 2)
                if j < 0:
                    self.error("註解未結束")
                self.i = j + 2
            else:
                return

    def parse(self):
        # 檔頭
        if self.s.startswith("// !$*UTF8*$!"):
            self.i = self.s.find("\n") + 1
        self.skip()
        value = self.parse_value()
        self.skip()
        if self.i != self.n:
            self.error(f"檔尾有多餘內容: {self.s[self.i:self.i+40]!r}")
        return value

    def parse_value(self):
        self.skip()
        if self.i >= self.n:
            self.error("內容意外結束")
        c = self.s[self.i]
        if c == "{":
            return self.parse_dict()
        if c == "(":
            return self.parse_array()
        if c == '"':
            return self.parse_quoted()
        return self.parse_bare()

    def parse_dict(self):
        self.i += 1                     # {
        out = {}
        while True:
            self.skip()
            if self.i >= self.n:
                self.error("字典未以 } 結束")
            if self.s[self.i] == "}":
                self.i += 1
                return out
            key = self.parse_value()
            self.skip()
            if self.i >= self.n or self.s[self.i] != "=":
                self.error(f"鍵 {key!r} 之後應為 =")
            self.i += 1
            val = self.parse_value()
            self.skip()
            if self.i >= self.n or self.s[self.i] != ";":
                self.error(f"鍵 {key!r} 的值之後應為 ;")
            self.i += 1
            if key in out:
                self.error(f"字典中有重複的鍵 {key!r}")
            out[key] = val

    def parse_array(self):
        self.i += 1                     # (
        out = []
        while True:
            self.skip()
            if self.i >= self.n:
                self.error("陣列未以 ) 結束")
            if self.s[self.i] == ")":
                self.i += 1
                return out
            out.append(self.parse_value())
            self.skip()
            if self.i < self.n and self.s[self.i] == ",":
                self.i += 1
            elif self.i < self.n and self.s[self.i] == ")":
                self.i += 1
                return out
            else:
                self.error("陣列元素之後應為 , 或 )")

    def parse_quoted(self):
        self.i += 1
        buf = []
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                buf.append(self.s[self.i + 1])
                self.i += 2
            elif c == '"':
                self.i += 1
                return "".join(buf)
            else:
                buf.append(c)
                self.i += 1
        self.error("字串未結束")

    # Xcode 的裸字串只接受這些字元。特別注意不能用 str.isalnum()——
    # 中文等非 ASCII 字元也會回傳 True，會放過 Xcode 其實無法解析的內容。
    BARE = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$/.-")

    def parse_bare(self):
        start = self.i
        while self.i < self.n and self.s[self.i] in self.BARE:
            self.i += 1
        if self.i == start:
            c = self.s[self.i]
            if not c.isascii():
                self.error(f"非 ASCII 字元 {c!r} 未加引號（Xcode 會判定專案檔損毀）")
            self.error(f"無法解析的字元 {c!r}")
        return self.s[start:self.i]


def main():
    text = open(PROJ, encoding="utf-8").read()
    try:
        root = Parser(text).parse()
    except SyntaxError as e:
        print(f"✗ pbxproj 語法錯誤：{e}")
        return 1

    objects = root["objects"]
    print(f"解析成功：{len(objects)} 個物件，objectVersion={root['objectVersion']}")

    problems = []

    # rootObject 必須是 PBXProject
    proj = objects.get(root["rootObject"])
    if not proj or proj.get("isa") != "PBXProject":
        problems.append("rootObject 不是 PBXProject")

    # 每個 ID 參照都要指到存在的物件
    def walk(v, path):
        if isinstance(v, dict):
            for k, sub in v.items():
                walk(sub, f"{path}.{k}")
        elif isinstance(v, list):
            for idx, sub in enumerate(v):
                walk(sub, f"{path}[{idx}]")
        elif isinstance(v, str) and len(v) == 24 and all(c in "0123456789ABCDEF" for c in v):
            if v not in objects:
                problems.append(f"{path} 指向不存在的物件 {v}")

    walk(objects, "objects")

    # 目標檢查
    targets = [objects[t] for t in proj.get("targets", [])]
    names = sorted(t.get("name") for t in targets)
    if names != ["NineTwelve", "NineTwelveTests"]:
        problems.append(f"target 名稱不符: {names}")

    app = next((t for t in targets if t["name"] == "NineTwelve"), None)
    tests = next((t for t in targets if t["name"] == "NineTwelveTests"), None)

    if app:
        phases = [objects[p]["isa"] for p in app["buildPhases"]]
        if "PBXSourcesBuildPhase" not in phases:
            problems.append("app target 缺少 Sources phase")
        if "PBXResourcesBuildPhase" not in phases:
            problems.append("app target 缺少 Resources phase")
        src = next(objects[p] for p in app["buildPhases"]
                   if objects[p]["isa"] == "PBXSourcesBuildPhase")
        print(f"  app 編譯 {len(src['files'])} 個檔案")
        if len(src["files"]) < 10:
            problems.append("app 來源檔數量異常")

        cfgs = objects[app["buildConfigurationList"]]["buildConfigurations"]
        for c in cfgs:
            s = objects[c]["buildSettings"]
            for key in ("PRODUCT_BUNDLE_IDENTIFIER", "GENERATE_INFOPLIST_FILE",
                        "ASSETCATALOG_COMPILER_APPICON_NAME", "SWIFT_VERSION",
                        "IPHONEOS_DEPLOYMENT_TARGET"):
                # SWIFT_VERSION / deployment target 繼承自 project 層
                if key in ("SWIFT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET"):
                    continue
                if key not in s:
                    problems.append(f"app {objects[c]['name']} 設定缺少 {key}")

    if tests:
        cfgs = objects[tests["buildConfigurationList"]]["buildConfigurations"]
        for c in cfgs:
            s = objects[c]["buildSettings"]
            if "TEST_HOST" not in s or "BUNDLE_LOADER" not in s:
                problems.append("test target 缺少 TEST_HOST / BUNDLE_LOADER")
        if not tests.get("dependencies"):
            problems.append("test target 沒有相依於 app target")

    # 專案層設定
    pcfgs = objects[proj["buildConfigurationList"]]["buildConfigurations"]
    for c in pcfgs:
        s = objects[c]["buildSettings"]
        for key in ("SDKROOT", "SWIFT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET"):
            if key not in s:
                problems.append(f"專案 {objects[c]['name']} 設定缺少 {key}")

    # 群組樹可走訪且檔案存在
    base = os.path.join(ROOT, "ios")
    seen_files = []

    def walk_group(gid, prefix):
        g = objects[gid]
        path = g.get("path", "")
        cur = os.path.join(prefix, path) if path else prefix
        for child in g["children"]:
            o = objects[child]
            if o["isa"] in ("PBXGroup", "PBXVariantGroup"):
                # PBXVariantGroup（本地化檔案）沒有 path，子檔案沿用父群組的目錄
                walk_group(child, cur)
            elif o["isa"] == "PBXFileReference":
                if o.get("sourceTree") == "BUILT_PRODUCTS_DIR":
                    continue
                full = os.path.join(cur, o["path"])
                seen_files.append(full)
                if not os.path.exists(full):
                    problems.append(f"檔案不存在: {os.path.relpath(full, ROOT)}")

    walk_group(proj["mainGroup"], base)
    print(f"  群組樹中 {len(seen_files)} 個檔案全部可對應到磁碟"
          if not any("檔案不存在" in p for p in problems) else "")

    if problems:
        print("\n語意檢查未通過：")
        for p in problems:
            print("  ✗ " + p)
        return 1
    print("pbxproj 語法與語意檢查全部通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
