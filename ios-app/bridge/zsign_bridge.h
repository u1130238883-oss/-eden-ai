#pragma once
// C 接口：讓 Swift 調用 zsign（C++）在手機上簽名。
#ifdef __cplusplus
extern "C" {
#endif

/// 解壓 zip / ipa 到目錄。成功返回 0。
int zs_unzip(const char *zipPath, const char *outDir);

/// 只解壓 Payload/*.app/ 頂層的 Info.plist 和 png 圖標（導入時讀名稱和圖標用，比整包解壓快很多）。
/// 成功（找到 Info.plist）返回 0。
int zs_unzip_app_meta(const char *zipPath, const char *outDir);

/// 讀取 p12 證書：成功返回 0，寫入證書名稱和到期時間（Unix 秒）；密碼錯誤返回 -1。
int zs_cert_info(const char *p12Path, const char *password,
                 char *nameOut, int nameLen, long long *notAfterOut);

/// 簽名 IPA。bundleId / displayName / version 傳空字符串表示不修改。
/// 簽名過程的日誌寫到 logPath（便於排錯）。成功返回 0。
int zs_sign_ipa(const char *p12Path, const char *password, const char *provPath,
                const char *ipaPath, const char *outIpaPath, const char *tempDir,
                const char *bundleId, const char *displayName, const char *version,
                const char *logPath);

#ifdef __cplusplus
}
#endif
