# Hollow（絕區零風格算命 App）

以《絕區零》街頭霓虹風格製作的 iOS 算命 App（SwiftUI，iOS 16+，繁體中文），介面以白話呈現，一般人一看就懂。

## 功能
推算方法完整沿用原版「九型十二宮」(Nine & Twelve)：出生年、月、日各自化約成三柱 → 三柱相加（九進制）得靈數 → 由命宮逆排十二宮，依年柱與月柱的五行生剋判讀「好／正／壞」與「果←因」。
- **今天**：今天的關鍵字、晚上留意、這個月／今年／這幾年一句話總結
- **運勢**：每月、每年、大運，以「好幾因幾／正幾因幾／壞幾因幾」標示（例如 好5因3＝果在5宮、因在3宮）
- **命盤**：你的性格（九型）與本命十二宮
- **合盤**：輸入對方生日，列出合盤十二宮與好／正／壞數量
- **我**：語言（繁體中文／English／Español／Italiano）、修改資料、十二宮含義、進階設定

依需求，畫面上不顯示年、月、日三柱的數字，只以白話顯示結果。

## 建置
推送後 GitHub Actions（`.github/workflows/build-ipa.yml`）會在 macOS 上用 XcodeGen + xcodebuild 產生**未簽名**的
`dist/Persona5Fortune.ipa`，可用 Sideloadly / AltStore / TrollStore 等工具自行簽名安裝。

本地建置：
```sh
brew install xcodegen
xcodegen generate
open Persona5Fortune.xcodeproj
```

> 粉絲向非官方作品，與 miHoYo / HoYoverse 無關。
