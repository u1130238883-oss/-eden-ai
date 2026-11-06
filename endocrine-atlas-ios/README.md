# 掌上醫學百科（iOS App）

繁體中文醫學百科：16 個身體系統（含口腔牙科）、226 種常見疾病（成因、症狀、診斷、治療、重點提醒）、131 項症狀反查、71 類常用藥物、59 項檢驗數值、16 項急救步驟、台灣公費預防保健與求助專線，以及內分泌人體圖譜（20 個器官、71 種激素、9 條調節軸）與隨堂測驗。內容全部打包在 App 內，可離線使用。

## 下載 .ipa

每次推送到 `endocrine-atlas-ios` 分支，GitHub Actions 會在 macOS 上編譯，並把 `EndocrineAtlas.ipa` 附在 Releases 頁面（標籤 `medical-handbook-v5-buildN`）。

## 安裝到 iPhone

這個 .ipa **沒有簽名**（簽名需要你自己的 Apple ID），請任選一種方式：

1. **Sideloadly**（Windows／Mac，最簡單）：安裝 Sideloadly → iPhone 接上電腦 → 拖入 `EndocrineAtlas.ipa` → 輸入 Apple ID → Start。
   之後在 iPhone「設定 → 一般 → VPN 與裝置管理」信任你的 Apple ID。免費 Apple ID 每 7 天需重新簽一次。
2. **AltStore**：在電腦安裝 AltServer、iPhone 安裝 AltStore，於 AltStore 的 My Apps 點「+」選擇 .ipa。
3. **TrollStore**（僅支援特定 iOS 版本）：直接安裝，不會過期。

iOS 16 以上用側載方式安裝時，需在「設定 → 隱私權與安全性」開啟「開發者模式」。

## 本機編譯（Mac）

```sh
brew install xcodegen
cd endocrine-atlas-ios
xcodegen generate
open EndocrineAtlas.xcodeproj   # 選你的 iPhone，登入 Apple ID 後按 ▶︎
```

本 App 供學習用途，不能取代醫師診斷。
