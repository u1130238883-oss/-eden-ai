#include "zsign_bridge.h"

#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <ctime>
#include <string>
#include <vector>

#include "common.h"
#include "archive.h"
#include "bundle.h"
#include "openssl.h"

#include "third-party/minizip/unzip.h"

#include <openssl/pkcs12.h>
#include <openssl/provider.h>
#include <openssl/x509.h>
#include <openssl/err.h>

// 簽名期間把 stdout/stderr 轉到日誌文件，結束後恢復。
class LogRedirect {
public:
	explicit LogRedirect(const char *path) {
		if (!path || !*path) return;
		int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
		if (fd < 0) return;
		fflush(stdout); fflush(stderr);
		m_out = dup(STDOUT_FILENO); m_err = dup(STDERR_FILENO);
		dup2(fd, STDOUT_FILENO); dup2(fd, STDERR_FILENO);
		close(fd);
	}
	~LogRedirect() {
		if (m_out < 0) return;
		fflush(stdout); fflush(stderr);
		dup2(m_out, STDOUT_FILENO); dup2(m_err, STDERR_FILENO);
		close(m_out); close(m_err);
	}
private:
	int m_out = -1, m_err = -1;
};

int zs_unzip(const char *zipPath, const char *outDir)
{
	ZFile::CreateFolder(outDir);
	return Zip::Extract(zipPath, outDir) ? 0 : -1;
}

// Payload/<名稱>.app/<文件>，只要頂層的 Info.plist 和 png
static bool IsAppMetaFile(const std::string &path, bool &isInfoPlist)
{
	isInfoPlist = false;
	if (0 != path.compare(0, 8, "Payload/") || std::string::npos != path.find("..")) {
		return false;
	}
	size_t app = path.find(".app/", 8);
	if (std::string::npos == app) {
		return false;
	}
	std::string name = path.substr(app + 5);
	if (name.empty() || std::string::npos != name.find('/')) {
		return false;
	}
	if ("Info.plist" == name) {
		isInfoPlist = true;
		return true;
	}
	return name.size() > 4 && 0 == name.compare(name.size() - 4, 4, ".png");
}

int zs_unzip_app_meta(const char *zipPath, const char *outDir)
{
	unzFile uf = unzOpen64(zipPath);
	if (NULL == uf) return -1;

	bool foundInfo = false;
	char name[4096];
	std::vector<char> buffer(256 * 1024);
	for (int r = unzGoToFirstFile(uf); UNZ_OK == r; r = unzGoToNextFile(uf)) {
		unz_file_info64 fi;
		if (UNZ_OK != unzGetCurrentFileInfo64(uf, &fi, name, sizeof(name), NULL, 0, NULL, 0)) {
			continue;
		}
		std::string path = name;
		bool isInfoPlist = false;
		if (!IsAppMetaFile(path, isInfoPlist)) {
			continue;
		}

		std::string dest = std::string(outDir) + "/" + path;
		ZFile::CreateFolder(dest.substr(0, dest.rfind('/')).c_str());
		if (UNZ_OK != unzOpenCurrentFile(uf)) {
			continue;
		}
		FILE *fp = fopen(dest.c_str(), "wb");
		bool ok = NULL != fp;
		if (fp) {
			int n;
			while ((n = unzReadCurrentFile(uf, buffer.data(), (unsigned)buffer.size())) > 0) {
				fwrite(buffer.data(), 1, (size_t)n, fp);
			}
			ok = (0 == n);
			fclose(fp);
		}
		unzCloseCurrentFile(uf);
		if (ok && isInfoPlist) foundInfo = true;
	}
	unzClose(uf);
	return foundInfo ? 0 : -2;
}

int zs_cert_info(const char *p12Path, const char *password,
                 char *nameOut, int nameLen, long long *notAfterOut)
{
	OSSL_PROVIDER_load(NULL, "legacy");
	OSSL_PROVIDER_load(NULL, "default");

	FILE *fp = fopen(p12Path, "rb");
	if (!fp) return -2;
	PKCS12 *p12 = d2i_PKCS12_fp(fp, NULL);
	fclose(fp);
	if (!p12) return -2;

	EVP_PKEY *pkey = NULL;
	X509 *cert = NULL;
	STACK_OF(X509) *ca = NULL;
	int ok = PKCS12_parse(p12, password, &pkey, &cert, &ca);
	PKCS12_free(p12);
	if (!ok || !cert) {
		ERR_clear_error();
		return -1;
	}

	X509_NAME_get_text_by_NID(X509_get_subject_name(cert), NID_commonName, nameOut, nameLen);

	struct tm tmAfter = {};
	if (ASN1_TIME_to_tm(X509_get0_notAfter(cert), &tmAfter)) {
		*notAfterOut = (long long)timegm(&tmAfter);
	}

	EVP_PKEY_free(pkey);
	X509_free(cert);
	sk_X509_pop_free(ca, X509_free);
	return 0;
}

int zs_sign_ipa(const char *p12Path, const char *password, const char *provPath,
                const char *ipaPath, const char *outIpaPath, const char *tempDir,
                const char *bundleId, const char *displayName, const char *version,
                const char *logPath)
{
	LogRedirect redirect(logPath);

	ZSignAsset zsa;
	if (!zsa.Init("", p12Path, provPath, "", password, false, false, false)) {
		ZLog::Error(">>> 證書或描述文件無效\n");
		return -1;
	}

	std::string folder = ZFile::GetRealPathV("%s/zsign_folder_%llu", tempDir, ZUtil::GetMicroSecond());
	if (!Zip::Extract(ipaPath, folder.c_str())) {
		ZLog::Error(">>> 解壓 IPA 失敗\n");
		ZFile::RemoveFolder(folder.c_str());
		return -2;
	}

	ZBundle bundle;
	std::vector<std::string> noDylibs;
	bool ok = bundle.SignFolder(&zsa, folder, bundleId, version, displayName,
	                            noDylibs, noDylibs, true, false, false);

	if (ok) {
		size_t pos = bundle.m_strAppFolder.rfind("Payload");
		if (std::string::npos == pos || 0 == pos) {
			ZLog::Error(">>> 找不到 Payload 目錄\n");
			ok = false;
		} else {
			std::string base = bundle.m_strAppFolder.substr(0, pos - 1);
			ok = Zip::Archive(base.c_str(), outIpaPath, 6);
			if (!ok) ZLog::Error(">>> 打包 IPA 失敗\n");
		}
	}

	ZFile::RemoveFolder(folder.c_str());
	return ok ? 0 : -3;
}
