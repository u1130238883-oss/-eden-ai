#!/usr/bin/env python3
"""
由 ios/NineTwelve 與 ios/NineTwelveTests 的檔案列表產生 NineTwelve.xcodeproj。

pbxproj 手寫容易出錯，改由這支腳本生成；新增檔案後重新執行即可：

    python3 tools/gen_xcodeproj.py
"""
import hashlib
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(ROOT, "ios")
APP = "NineTwelve"
TESTS = "NineTwelveTests"
BUNDLE_ID = "com.ninetwelve.fortune"
DEPLOYMENT_TARGET = "16.0"
SWIFT_VERSION = "5.0"
DISPLAY_NAME = "Nine & Twelve"

# 主畫面上的 App 名稱要跟著手機的系統語言走，靠 <語言>.lproj/InfoPlist.strings。
# 四種語言都放在專案裡，但一次建置只收其中兩種 —— 另外兩種用
# EXCLUDED_SOURCE_FILE_NAMES 排掉，否則西/義版裝在中文手機上會顯示中文名。
LOCALIZATIONS = ["zh-Hant", "en", "es", "it"]
CJK_LANGS = ["zh-Hant", "en"]
LATIN_LANGS = ["es", "it"]


# 打包後只留下這個版本該有的語言包。
#
# 試過 EXCLUDED_SOURCE_FILE_NAMES，但它不會排除本地化資源（實測四個 .lproj
# 還是全部進了 .app），所以改成資源階段之後跑一個腳本把多的刪掉。
# 這樣不只 CI，用 Xcode 直接 Archive 也一樣生效。
PRUNE_SCRIPT = r"""set -e
APP="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
KEEP="${NINETWELVE_LANGS}"
[ -n "$KEEP" ] || { echo "error: NINETWELVE_LANGS 未設定"; exit 1; }
for dir in "$APP"/*.lproj; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir" .lproj)
  case " $KEEP " in
    *" $name "*) ;;
    *) rm -rf "$dir" ;;
  esac
done
echo "保留的語言包: $KEEP"
"""

_ids = {}       # key -> id
_taken = {}     # id -> key


def oid(key):
    """由字串產生穩定的 24 位十六進位 ID；同一個 key 永遠得到同一個 ID。"""
    if key in _ids:
        return _ids[key]
    salt = key
    h = hashlib.md5(salt.encode("utf-8")).hexdigest()[:24].upper()
    while h in _taken:          # 只在不同 key 真的雜湊碰撞時才加鹽
        salt += "!"
        h = hashlib.md5(salt.encode("utf-8")).hexdigest()[:24].upper()
    _ids[key] = h
    _taken[h] = key
    return h


BARE_OK = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./")


def quote(s):
    """
    pbxproj 字串：必要時加引號。

    只有純 ASCII 的英數與 _ . / 可以不加引號 —— 注意不能用 str.isalnum()，
    中文字元也會回傳 True，會產生 Xcode 無法解析的裸字串。
    """
    if s and all(c in BARE_OK for c in s):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def collect(root, exts=(".swift",)):
    """回傳 (相對於 ios/ 的路徑) 列表，已排序。"""
    out = []
    for base, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".")
                         and not d.endswith(".xcassets"))
        for f in sorted(files):
            if f.endswith(exts):
                out.append(os.path.relpath(os.path.join(base, f), IOS))
    return sorted(out)


class Project:
    def __init__(self):
        self.sources = collect(os.path.join(IOS, APP))
        self.test_sources = collect(os.path.join(IOS, TESTS))
        self.variant = os.path.join(APP, "Resources", "InfoPlist.strings")
        self.resources = [os.path.join(APP, "Resources", "Assets.xcassets"), self.variant]

        self.file_refs = {}     # 相對路徑 -> id
        self.build_files = {}   # (相對路徑, target) -> id
        self.groups = {}        # 群組路徑 -> id

        self.app_target = oid("target.app")
        self.test_target = oid("target.tests")
        self.project_id = oid("project")
        self.main_group = oid("group.main")
        self.products_group = oid("group.products")
        self.app_product = oid("product.app")
        self.test_product = oid("product.tests")

    # ---------------- 章節 ----------------

    def section_build_files(self):
        lines = []
        for path in self.sources:
            i = oid("bf.app." + path)
            self.build_files[(path, "app")] = i
            lines.append(f"\t\t{i} /* {os.path.basename(path)} in Sources */ = "
                         f"{{isa = PBXBuildFile; fileRef = {self.ref(path)}; }};")
        for path in self.resources:
            i = oid("bf.res." + path)
            self.build_files[(path, "res")] = i
            lines.append(f"\t\t{i} /* {os.path.basename(path)} in Resources */ = "
                         f"{{isa = PBXBuildFile; fileRef = {self.ref(path)}; }};")
        for path in self.test_sources:
            i = oid("bf.test." + path)
            self.build_files[(path, "test")] = i
            lines.append(f"\t\t{i} /* {os.path.basename(path)} in Sources */ = "
                         f"{{isa = PBXBuildFile; fileRef = {self.ref(path)}; }};")
        return self.wrap("PBXBuildFile", lines)

    def ref(self, path):
        if path not in self.file_refs:
            self.file_refs[path] = oid("fr." + path)
        return self.file_refs[path]

    def section_file_refs(self):
        lines = []
        for path in self.sources + self.test_sources:
            lines.append(
                f"\t\t{self.ref(path)} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = sourcecode.swift; path = {quote(os.path.basename(path))}; "
                f"sourceTree = \"<group>\"; }};")
        for path in self.resources:
            if path == self.variant:
                # 本體是 PBXVariantGroup，這裡只出各語言的檔案
                for lang in LOCALIZATIONS:
                    lines.append(
                        f"\t\t{self.lang_ref(lang)} /* {lang} */ = {{isa = PBXFileReference; "
                        f"lastKnownFileType = text.plist.strings; name = {quote(lang)}; "
                        f"path = {quote(lang + '.lproj/InfoPlist.strings')}; "
                        f"sourceTree = \"<group>\"; }};")
                continue
            lines.append(
                f"\t\t{self.ref(path)} /* Assets.xcassets */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; "
                f"sourceTree = \"<group>\"; }};")
        lines.append(
            f"\t\t{self.app_product} /* {APP}.app */ = {{isa = PBXFileReference; "
            f"explicitFileType = wrapper.application; includeInIndex = 0; "
            f"path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
        lines.append(
            f"\t\t{self.test_product} /* {TESTS}.xctest */ = {{isa = PBXFileReference; "
            f"explicitFileType = wrapper.cfbundle; includeInIndex = 0; "
            f"path = {TESTS}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
        return self.wrap("PBXFileReference", lines)

    def lang_ref(self, lang):
        return oid("fr.lproj." + lang)

    def section_variant_groups(self):
        body = "".join(f"\n\t\t\t\t{self.lang_ref(l)} /* {l} */," for l in LOCALIZATIONS)
        return self.wrap("PBXVariantGroup", [
            f"\t\t{self.ref(self.variant)} /* InfoPlist.strings */ = {{\n"
            f"\t\t\tisa = PBXVariantGroup;\n"
            f"\t\t\tchildren = ({body}\n\t\t\t);\n"
            f"\t\t\tname = InfoPlist.strings;\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};"
        ])

    def build_tree(self):
        """由檔案路徑建出巢狀群組。"""
        tree = {}
        for path in self.sources + self.resources + self.test_sources:
            parts = path.split(os.sep)
            node = tree
            for p in parts[:-1]:
                node = node.setdefault(p, {})
            node.setdefault("__files__", []).append(path)
        return tree

    def section_groups(self):
        tree = self.build_tree()
        lines = []

        def emit(node, gpath):
            gid = oid("group." + gpath)
            children = []
            for name in sorted(k for k in node if k != "__files__"):
                children.append((name, emit(node[name], gpath + "/" + name)))
            for f in sorted(node.get("__files__", [])):
                children.append((os.path.basename(f), self.ref(f)))
            body = "".join(f"\n\t\t\t\t{cid} /* {name} */," for name, cid in children)
            name = gpath.rsplit("/", 1)[-1]
            lines.append(
                f"\t\t{gid} /* {name} */ = {{\n"
                f"\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = ({body}\n\t\t\t);\n"
                f"\t\t\tpath = {quote(name)};\n"
                f"\t\t\tsourceTree = \"<group>\";\n"
                f"\t\t}};")
            return gid

        top = []
        for name in sorted(k for k in tree if k != "__files__"):
            top.append((name, emit(tree[name], name)))

        lines.append(
            f"\t\t{self.products_group} /* Products */ = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n"
            f"\t\t\t\t{self.app_product} /* {APP}.app */,\n"
            f"\t\t\t\t{self.test_product} /* {TESTS}.xctest */,\n"
            f"\t\t\t);\n"
            f"\t\t\tname = Products;\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};")

        body = "".join(f"\n\t\t\t\t{cid} /* {name} */," for name, cid in top)
        lines.append(
            f"\t\t{self.main_group} = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = ({body}\n"
            f"\t\t\t\t{self.products_group} /* Products */,\n"
            f"\t\t\t);\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};")
        return self.wrap("PBXGroup", lines)

    def section_phases(self):
        app_src = oid("phase.app.sources")
        app_res = oid("phase.app.resources")
        app_fw = oid("phase.app.frameworks")
        app_prune = oid("phase.app.prune")
        test_src = oid("phase.test.sources")
        test_fw = oid("phase.test.frameworks")
        self.phases = dict(app_src=app_src, app_res=app_res, app_fw=app_fw,
                           app_prune=app_prune, test_src=test_src, test_fw=test_fw)

        def phase(pid, isa, items, label):
            body = "".join(f"\n\t\t\t\t{i} /* {n} */," for i, n in items)
            return (f"\t\t{pid} /* {label} */ = {{\n"
                    f"\t\t\tisa = {isa};\n"
                    f"\t\t\tbuildActionMask = 2147483647;\n"
                    f"\t\t\tfiles = ({body}\n\t\t\t);\n"
                    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
                    f"\t\t}};")

        src_lines = [phase(app_src, "PBXSourcesBuildPhase",
                           [(self.build_files[(p, "app")], os.path.basename(p)) for p in self.sources],
                           "Sources"),
                     phase(test_src, "PBXSourcesBuildPhase",
                           [(self.build_files[(p, "test")], os.path.basename(p)) for p in self.test_sources],
                           "Sources")]
        res_lines = [phase(app_res, "PBXResourcesBuildPhase",
                           [(self.build_files[(p, "res")], os.path.basename(p))
                            for p in self.resources],
                           "Resources")]
        fw_lines = [phase(app_fw, "PBXFrameworksBuildPhase", [], "Frameworks"),
                    phase(test_fw, "PBXFrameworksBuildPhase", [], "Frameworks")]

        script = PRUNE_SCRIPT.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        prune_lines = [
            f"\t\t{app_prune} /* 只留這一版的語言包 */ = {{\n"
            f"\t\t\tisa = PBXShellScriptBuildPhase;\n"
            f"\t\t\talwaysOutOfDate = 1;\n"
            f"\t\t\tbuildActionMask = 2147483647;\n"
            f"\t\t\tfiles = (\n\t\t\t);\n"
            f"\t\t\tinputPaths = (\n\t\t\t);\n"
            f"\t\t\tname = \"只留這一版的語言包\";\n"
            f"\t\t\toutputPaths = (\n\t\t\t);\n"
            f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            f"\t\t\tshellPath = /bin/sh;\n"
            f"\t\t\tshellScript = \"{script}\";\n"
            f"\t\t}};"
        ]

        return (self.wrap("PBXSourcesBuildPhase", src_lines)
                + self.wrap("PBXResourcesBuildPhase", res_lines)
                + self.wrap("PBXShellScriptBuildPhase", prune_lines)
                + self.wrap("PBXFrameworksBuildPhase", fw_lines))

    def section_targets(self):
        dep = oid("dep.test->app")
        proxy = oid("proxy.test->app")

        proxy_section = self.wrap("PBXContainerItemProxy", [
            f"\t\t{proxy} /* PBXContainerItemProxy */ = {{\n"
            f"\t\t\tisa = PBXContainerItemProxy;\n"
            f"\t\t\tcontainerPortal = {self.project_id} /* Project object */;\n"
            f"\t\t\tproxyType = 1;\n"
            f"\t\t\tremoteGlobalIDString = {self.app_target};\n"
            f"\t\t\tremoteInfo = {APP};\n"
            f"\t\t}};"])

        dep_section = self.wrap("PBXTargetDependency", [
            f"\t\t{dep} /* PBXTargetDependency */ = {{\n"
            f"\t\t\tisa = PBXTargetDependency;\n"
            f"\t\t\ttarget = {self.app_target} /* {APP} */;\n"
            f"\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;\n"
            f"\t\t}};"])

        app = (
            f"\t\t{self.app_target} /* {APP} */ = {{\n"
            f"\t\t\tisa = PBXNativeTarget;\n"
            f"\t\t\tbuildConfigurationList = {oid('cfglist.app')} /* Build configuration list for PBXNativeTarget \"{APP}\" */;\n"
            f"\t\t\tbuildPhases = (\n"
            f"\t\t\t\t{self.phases['app_src']} /* Sources */,\n"
            f"\t\t\t\t{self.phases['app_fw']} /* Frameworks */,\n"
            f"\t\t\t\t{self.phases['app_res']} /* Resources */,\n"
            f"\t\t\t\t{self.phases['app_prune']} /* 只留這一版的語言包 */,\n"
            f"\t\t\t);\n"
            f"\t\t\tbuildRules = (\n\t\t\t);\n"
            f"\t\t\tdependencies = (\n\t\t\t);\n"
            f"\t\t\tname = {APP};\n"
            f"\t\t\tproductName = {APP};\n"
            f"\t\t\tproductReference = {self.app_product} /* {APP}.app */;\n"
            f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
            f"\t\t}};")

        tests = (
            f"\t\t{self.test_target} /* {TESTS} */ = {{\n"
            f"\t\t\tisa = PBXNativeTarget;\n"
            f"\t\t\tbuildConfigurationList = {oid('cfglist.tests')} /* Build configuration list for PBXNativeTarget \"{TESTS}\" */;\n"
            f"\t\t\tbuildPhases = (\n"
            f"\t\t\t\t{self.phases['test_src']} /* Sources */,\n"
            f"\t\t\t\t{self.phases['test_fw']} /* Frameworks */,\n"
            f"\t\t\t);\n"
            f"\t\t\tbuildRules = (\n\t\t\t);\n"
            f"\t\t\tdependencies = (\n"
            f"\t\t\t\t{dep} /* PBXTargetDependency */,\n"
            f"\t\t\t);\n"
            f"\t\t\tname = {TESTS};\n"
            f"\t\t\tproductName = {TESTS};\n"
            f"\t\t\tproductReference = {self.test_product} /* {TESTS}.xctest */;\n"
            f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";\n"
            f"\t\t}};")

        return proxy_section + dep_section + self.wrap("PBXNativeTarget", [app, tests])

    def section_project(self):
        body = (
            f"\t\t{self.project_id} /* Project object */ = {{\n"
            f"\t\t\tisa = PBXProject;\n"
            f"\t\t\tattributes = {{\n"
            f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
            f"\t\t\t\tLastSwiftUpdateCheck = 1600;\n"
            f"\t\t\t\tLastUpgradeCheck = 1600;\n"
            f"\t\t\t\tTargetAttributes = {{\n"
            f"\t\t\t\t\t{self.app_target} = {{ CreatedOnToolsVersion = 16.0; }};\n"
            f"\t\t\t\t\t{self.test_target} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {self.app_target}; }};\n"
            f"\t\t\t\t}};\n"
            f"\t\t\t}};\n"
            f"\t\t\tbuildConfigurationList = {oid('cfglist.project')} /* Build configuration list for PBXProject \"{APP}\" */;\n"
            f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
            f"\t\t\tdevelopmentRegion = \"zh-Hant\";\n"
            f"\t\t\thasScannedForEncodings = 0;\n"
            f"\t\t\tknownRegions = (\n"
            + "".join(f"\t\t\t\t{quote(r)},\n" for r in LOCALIZATIONS)
            + f"\t\t\t\tBase,\n\t\t\t);\n"
            f"\t\t\tmainGroup = {self.main_group};\n"
            f"\t\t\tproductRefGroup = {self.products_group} /* Products */;\n"
            f"\t\t\tprojectDirPath = \"\";\n"
            f"\t\t\tprojectRoot = \"\";\n"
            f"\t\t\ttargets = (\n"
            f"\t\t\t\t{self.app_target} /* {APP} */,\n"
            f"\t\t\t\t{self.test_target} /* {TESTS} */,\n"
            f"\t\t\t);\n"
            f"\t\t}};")
        return self.wrap("PBXProject", [body])

    # ---------------- 建置設定 ----------------

    def section_configs(self):
        def cfg(cid, name, settings):
            body = "".join(f"\n\t\t\t\t{k} = {v};" for k, v in settings)
            return (f"\t\t{cid} /* {name} */ = {{\n"
                    f"\t\t\tisa = XCBuildConfiguration;\n"
                    f"\t\t\tbuildSettings = {{{body}\n\t\t\t}};\n"
                    f"\t\t\tname = {name};\n"
                    f"\t\t}};")

        common = [
            ("ALWAYS_SEARCH_USER_PATHS", "NO"),
            ("CLANG_ENABLE_MODULES", "YES"),
            ("CLANG_ENABLE_OBJC_ARC", "YES"),
            ("COPY_PHASE_STRIP", "NO"),
            ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
            ("ENABLE_USER_SCRIPT_SANDBOXING", "NO"),
            ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
            ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
            ("SDKROOT", "iphoneos"),
            ("SWIFT_VERSION", SWIFT_VERSION),
        ]
        debug = common + [
            ("DEBUG_INFORMATION_FORMAT", "dwarf"),
            ("ENABLE_TESTABILITY", "YES"),
            ("GCC_OPTIMIZATION_LEVEL", "0"),
            ("GCC_PREPROCESSOR_DEFINITIONS", '"DEBUG=1 $(inherited)"'),
            ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
            ("ONLY_ACTIVE_ARCH", "YES"),
            ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", '"DEBUG $(inherited)"'),
            ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
        ]
        release = common + [
            ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
            ("ENABLE_NS_ASSERTIONS", "NO"),
            ("MTL_ENABLE_DEBUG_INFO", "NO"),
            ("SWIFT_COMPILATION_MODE", "wholemodule"),
            ("SWIFT_OPTIMIZATION_LEVEL", '"-O"'),
            ("VALIDATE_PRODUCT", "YES"),
        ]

        app_common = [
            ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
            ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
            ("CODE_SIGN_STYLE", "Automatic"),
            ("CURRENT_PROJECT_VERSION", "1"),
            ("ENABLE_PREVIEWS", "YES"),
            ("NINETWELVE_LANGS", quote(" ".join(CJK_LANGS))),
            ("GENERATE_INFOPLIST_FILE", "YES"),
            ("INFOPLIST_KEY_CFBundleDisplayName", quote(DISPLAY_NAME)),
            ("INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "YES"),
            ("INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents", "YES"),
            ("INFOPLIST_KEY_UILaunchScreen_Generation", "YES"),
            ("INFOPLIST_KEY_UIStatusBarStyle", "UIStatusBarStyleDefault"),
            ("INFOPLIST_KEY_UISupportedInterfaceOrientations",
             '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
            ("LD_RUNPATH_SEARCH_PATHS",
             '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
            ("MARKETING_VERSION", "1.0"),
            ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
            ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
            ("SWIFT_EMIT_LOC_STRINGS", "YES"),
            ("TARGETED_DEVICE_FAMILY", '"1,2"'),
        ]
        test_common = [
            ("BUNDLE_LOADER", '"$(TEST_HOST)"'),
            ("CODE_SIGN_STYLE", "Automatic"),
            ("CURRENT_PROJECT_VERSION", "1"),
            ("GENERATE_INFOPLIST_FILE", "YES"),
            ("MARKETING_VERSION", "1.0"),
            ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID + ".tests"),
            ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
            ("TARGETED_DEVICE_FAMILY", '"1,2"'),
            ("TEST_HOST",
             f'"$(BUILT_PRODUCTS_DIR)/{APP}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP}"'),
        ]

        lines = [
            cfg(oid("cfg.project.debug"), "Debug", debug),
            cfg(oid("cfg.project.release"), "Release", release),
            cfg(oid("cfg.app.debug"), "Debug", app_common),
            cfg(oid("cfg.app.release"), "Release", app_common),
            cfg(oid("cfg.tests.debug"), "Debug", test_common),
            cfg(oid("cfg.tests.release"), "Release", test_common),
        ]
        out = self.wrap("XCBuildConfiguration", lines)

        def cfglist(lid, label, debug_id, release_id):
            return (f"\t\t{lid} /* {label} */ = {{\n"
                    f"\t\t\tisa = XCConfigurationList;\n"
                    f"\t\t\tbuildConfigurations = (\n"
                    f"\t\t\t\t{debug_id} /* Debug */,\n"
                    f"\t\t\t\t{release_id} /* Release */,\n"
                    f"\t\t\t);\n"
                    f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
                    f"\t\t\tdefaultConfigurationName = Release;\n"
                    f"\t\t}};")

        out += self.wrap("XCConfigurationList", [
            cfglist(oid("cfglist.project"), f'Build configuration list for PBXProject "{APP}"',
                    oid("cfg.project.debug"), oid("cfg.project.release")),
            cfglist(oid("cfglist.app"), f'Build configuration list for PBXNativeTarget "{APP}"',
                    oid("cfg.app.debug"), oid("cfg.app.release")),
            cfglist(oid("cfglist.tests"), f'Build configuration list for PBXNativeTarget "{TESTS}"',
                    oid("cfg.tests.debug"), oid("cfg.tests.release")),
        ])
        return out

    @staticmethod
    def wrap(name, lines):
        if not lines:
            return ""
        return (f"\n/* Begin {name} section */\n"
                + "\n".join(lines)
                + f"\n/* End {name} section */\n")

    # ---------------- 輸出 ----------------

    def render(self):
        # 順序重要：build files 需要 file refs 先註冊
        refs = self.section_file_refs()
        bfs = self.section_build_files()
        groups = self.section_groups() + self.section_variant_groups()
        phases = self.section_phases()
        targets = self.section_targets()
        project = self.section_project()
        configs = self.section_configs()

        return ("// !$*UTF8*$!\n"
                "{\n"
                "\tarchiveVersion = 1;\n"
                "\tclasses = {\n\t};\n"
                "\tobjectVersion = 56;\n"
                "\tobjects = {\n"
                + bfs + self.container_placeholder(targets)
                + refs + groups + phases + project + configs
                + "\t};\n"
                f"\trootObject = {self.project_id} /* Project object */;\n"
                "}\n")

    @staticmethod
    def container_placeholder(targets):
        return targets

    def scheme(self):
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{self.app_target}"
               BuildableName = "{APP}.app"
               BlueprintName = "{APP}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{self.test_target}"
               BuildableName = "{TESTS}.xctest"
               BlueprintName = "{TESTS}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{self.app_target}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{self.app_target}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
"""


def main():
    p = Project()
    proj_dir = os.path.join(IOS, f"{APP}.xcodeproj")
    if os.path.isdir(proj_dir):
        shutil.rmtree(proj_dir)
    os.makedirs(os.path.join(proj_dir, "xcshareddata", "xcschemes"), exist_ok=True)

    with open(os.path.join(proj_dir, "project.pbxproj"), "w", encoding="utf-8") as f:
        f.write(p.render())
    with open(os.path.join(proj_dir, "xcshareddata", "xcschemes", f"{APP}.xcscheme"),
              "w", encoding="utf-8") as f:
        f.write(p.scheme())

    print(f"generated {proj_dir}")
    print(f"  app sources : {len(p.sources)}")
    print(f"  test sources: {len(p.test_sources)}")


if __name__ == "__main__":
    main()
