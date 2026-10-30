"""IPA 在線簽名：上傳證書（p12 + mobileprovision）一次，之後上傳 IPA 即可簽名並在 iPhone 上直接安裝。"""
import asyncio
import hashlib
import hmac
import json
import os
import plistlib
import re
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape

from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse, Response

DATA_DIR = Path(os.environ.get("DATA_DIR", "./data")).resolve()
CERT_DIR = DATA_DIR / "cert"
APPS_DIR = DATA_DIR / "apps"
ZSIGN = os.environ.get("ZSIGN_BIN", "zsign")
ACCESS_PASSWORD = os.environ.get("ACCESS_PASSWORD", "")
PUBLIC_URL = os.environ.get("PUBLIC_URL", "").rstrip("/")
APP_ID_RE = re.compile(r"^[A-Za-z0-9_-]{16,64}$")

if not ACCESS_PASSWORD:
    raise SystemExit("請設置環境變量 ACCESS_PASSWORD（網站登錄密碼），否則任何人都能用你的證書簽名。")

for d in (CERT_DIR, APPS_DIR):
    d.mkdir(parents=True, exist_ok=True)

SESSION_TOKEN = hmac.new(ACCESS_PASSWORD.encode(), b"ipa-signer-session", hashlib.sha256).hexdigest()
STATIC = Path(__file__).parent / "static"

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
sign_lock = asyncio.Lock()


def require_login(request: Request):
    if not hmac.compare_digest(request.cookies.get("session", ""), SESSION_TOKEN):
        raise HTTPException(401, "請先登錄")


def run(cmd, input_bytes=None, timeout=60):
    return subprocess.run(cmd, input=input_bytes, capture_output=True, timeout=timeout)


def p12_cert_pem(p12: Path, password: str) -> bytes:
    """取出 p12 裡的證書（PEM）。舊版 p12 使用 RC2 加密，需要 -legacy。"""
    for extra in ([], ["-legacy"]):
        r = run(["openssl", "pkcs12", "-in", str(p12), "-passin", "stdin", "-nokeys", "-clcerts", *extra],
                input_bytes=password.encode() + b"\n")
        if r.returncode == 0 and b"BEGIN CERTIFICATE" in r.stdout:
            return r.stdout
    raise ValueError("p12 密碼錯誤，或文件不是有效的 p12")


def cert_info(pem: bytes) -> dict:
    r = run(["openssl", "x509", "-noout", "-subject", "-enddate", "-serial", "-nameopt", "utf8,sep_comma_plus"],
            input_bytes=pem)
    out = r.stdout.decode()
    cn = re.search(r"CN=([^,\n]+)", out)
    end = re.search(r"notAfter=(.+)", out)
    expires = datetime.strptime(end.group(1).strip(), "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    return {"name": cn.group(1).strip() if cn else "?", "expires": expires.isoformat(),
            "serial": re.search(r"serial=(\w+)", out).group(1)}


def profile_info(path: Path) -> dict:
    r = run(["openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in", str(path)])
    if r.returncode != 0:
        raise ValueError("mobileprovision 文件無效")
    p = plistlib.loads(r.stdout)
    devices = p.get("ProvisionedDevices") or []
    if p.get("ProvisionsAllDevices"):
        kind = "企業 (In-House)"
    elif devices:
        kind = "Ad Hoc" if not p["Entitlements"].get("get-task-allow") else "開發 (Development)"
    else:
        kind = "App Store"
    return {
        "name": p.get("Name"),
        "team": p.get("TeamName"),
        "app_id": p["Entitlements"].get("application-identifier"),
        "kind": kind,
        "expires": p["ExpirationDate"].replace(tzinfo=timezone.utc).isoformat(),
        "devices": devices,
    }


def load_cert_meta():
    meta = CERT_DIR / "meta.json"
    return json.loads(meta.read_text()) if meta.exists() else None


def ocsp_status(pem: bytes) -> str:
    """向蘋果 OCSP 查詢證書是否被吊銷：good / revoked / unknown。"""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "cert.pem").write_bytes(pem)
        text = run(["openssl", "x509", "-in", str(tmp / "cert.pem"), "-noout", "-text"]).stdout.decode()
        ca_url = re.search(r"CA Issuers - URI:(\S+)", text)
        ocsp_url = re.search(r"OCSP - URI:(\S+)", text)
        if not (ca_url and ocsp_url):
            return "unknown"
        with urllib.request.urlopen(ca_url.group(1), timeout=15) as resp:
            (tmp / "issuer.cer").write_bytes(resp.read())
        run(["openssl", "x509", "-inform", "der", "-in", str(tmp / "issuer.cer"), "-out", str(tmp / "issuer.pem")])
        r = run(["openssl", "ocsp", "-issuer", str(tmp / "issuer.pem"), "-cert", str(tmp / "cert.pem"),
                 "-url", ocsp_url.group(1), "-noverify"], timeout=30)
        out = r.stdout.decode()
        if ": good" in out:
            return "good"
        if ": revoked" in out:
            return "revoked"
        return "unknown"


def read_ipa_info(ipa: Path) -> dict:
    with zipfile.ZipFile(ipa) as z:
        name = next(n for n in z.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n))
        p = plistlib.loads(z.read(name))
    return {
        "bundle_id": p.get("CFBundleIdentifier", ""),
        "title": p.get("CFBundleDisplayName") or p.get("CFBundleName") or "App",
        "version": p.get("CFBundleShortVersionString") or p.get("CFBundleVersion") or "1.0",
    }


def base_url(request: Request) -> str:
    if PUBLIC_URL:
        return PUBLIC_URL
    proto = request.headers.get("x-forwarded-proto", request.url.scheme)
    host = request.headers.get("x-forwarded-host", request.headers.get("host"))
    return f"{proto}://{host}"


def app_entry(app_id: str, request: Request) -> dict:
    info = json.loads((APPS_DIR / app_id / "info.json").read_text())
    manifest = f"{base_url(request)}/apps/{app_id}/manifest.plist"
    return {**info, "id": app_id,
            "install_url": "itms-services://?action=download-manifest&url=" + manifest,
            "download_url": f"/apps/{app_id}/app.ipa"}


# ---------- 頁面 / 登錄 ----------

@app.get("/", response_class=HTMLResponse)
def index():
    return (STATIC / "index.html").read_text(encoding="utf-8")


@app.post("/api/login")
def login(password: str = Form(...)):
    if not hmac.compare_digest(password.encode(), ACCESS_PASSWORD.encode()):
        time.sleep(1)
        raise HTTPException(401, "密碼錯誤")
    resp = JSONResponse({"ok": True})
    resp.set_cookie("session", SESSION_TOKEN, max_age=30 * 86400, httponly=True, samesite="lax", secure=True)
    return resp


@app.post("/api/logout")
def logout():
    resp = JSONResponse({"ok": True})
    resp.delete_cookie("session")
    return resp


# ---------- 證書 ----------

@app.get("/api/cert", dependencies=[Depends(require_login)])
def get_cert():
    return {"cert": load_cert_meta()}


def unpack_cert_zip(data: bytes, password: str):
    """賣家給的證書通常是 zip：裡面有 .p12、.mobileprovision 和寫著密碼的 txt。"""
    import io
    p12 = prov = None
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            base = name.rsplit("/", 1)[-1]
            if base.startswith(".") or name.startswith("__MACOSX"):
                continue
            low = base.lower()
            if low.endswith((".p12", ".pfx")):
                p12 = z.read(name)
            elif low.endswith(".mobileprovision"):
                prov = z.read(name)
            elif low.endswith(".txt") and not password:
                text = z.read(name).decode("utf-8", errors="ignore").strip()
                password = re.split(r"[:：]", text)[-1].strip()
    if not p12 or not prov:
        raise HTTPException(400, "zip 裡沒有找到 .p12 和 .mobileprovision")
    return p12, prov, password


@app.post("/api/cert", dependencies=[Depends(require_login)])
async def upload_cert(p12: UploadFile = File(...), password: str = Form(""),
                      profile: UploadFile | None = File(None)):
    p12_data = await p12.read()
    prov_data = await profile.read() if profile else b""
    if p12_data[:2] == b"PK":
        p12_data, prov_data, password = unpack_cert_zip(p12_data, password.strip())
    elif not prov_data:
        raise HTTPException(400, "請選擇描述文件 (.mobileprovision)，或者直接選證書 zip")
    staging = Path(tempfile.mkdtemp(dir=DATA_DIR))
    try:
        (staging / "cert.p12").write_bytes(p12_data)
        (staging / "cert.mobileprovision").write_bytes(prov_data)
        try:
            cinfo = cert_info(p12_cert_pem(staging / "cert.p12", password))
            pinfo = profile_info(staging / "cert.mobileprovision")
        except ValueError as e:
            raise HTTPException(400, str(e))
        (staging / "password").write_text(password)
        meta = {"cert": cinfo, "profile": pinfo, "ocsp": None, "uploaded": datetime.now(timezone.utc).isoformat()}
        (staging / "meta.json").write_text(json.dumps(meta, ensure_ascii=False))
        async with sign_lock:
            shutil.rmtree(CERT_DIR, ignore_errors=True)
            staging.rename(CERT_DIR)
        os.chmod(CERT_DIR, 0o700)
        return {"cert": meta}
    finally:
        shutil.rmtree(staging, ignore_errors=True)


@app.post("/api/cert/check", dependencies=[Depends(require_login)])
async def check_cert():
    meta = load_cert_meta()
    if not meta:
        raise HTTPException(400, "還沒有上傳證書")
    pem = p12_cert_pem(CERT_DIR / "cert.p12", (CERT_DIR / "password").read_text())
    try:
        status = await asyncio.to_thread(ocsp_status, pem)
    except Exception:
        raise HTTPException(502, "連接蘋果 OCSP 服務器失敗，請稍後再試")
    meta["ocsp"] = {"status": status, "checked": datetime.now(timezone.utc).isoformat()}
    (CERT_DIR / "meta.json").write_text(json.dumps(meta, ensure_ascii=False))
    return {"cert": meta}


# ---------- 簽名 ----------

async def save_upload(upload: UploadFile, dest: Path):
    with dest.open("wb") as f:
        while chunk := await upload.read(1 << 20):
            f.write(chunk)


def download_ipa_url(url: str, dest: Path):
    if not url.startswith(("https://", "http://")):
        raise HTTPException(400, "IPA 網址要以 http:// 或 https:// 開頭")
    req = urllib.request.Request(url, headers={"User-Agent": "ipa-signer"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp, dest.open("wb") as f:
            shutil.copyfileobj(resp, f, 1 << 20)
    except Exception as e:
        raise HTTPException(400, f"下載 IPA 失敗：{e}")


def finish_app(app_id: str, request: Request) -> dict:
    out_dir = APPS_DIR / app_id
    info = read_ipa_info(out_dir / "app.ipa")
    info["signed"] = datetime.now(timezone.utc).isoformat()
    info["size"] = (out_dir / "app.ipa").stat().st_size
    (out_dir / "info.json").write_text(json.dumps(info, ensure_ascii=False))
    return app_entry(app_id, request)


@app.post("/api/sign", dependencies=[Depends(require_login)])
async def sign(request: Request, ipa: UploadFile | None = File(None), ipa_url: str = Form(""),
               bundle_id: str = Form(""), display_name: str = Form(""), version: str = Form("")):
    if not load_cert_meta():
        raise HTTPException(400, "請先上傳證書")
    if not ipa and not ipa_url.strip():
        raise HTTPException(400, "請選擇 IPA 文件，或者填寫 IPA 網址")
    app_id = secrets.token_urlsafe(18)
    out_dir = APPS_DIR / app_id
    out_dir.mkdir()
    src = out_dir / "source.ipa"
    try:
        if ipa:
            await save_upload(ipa, src)
        else:
            await asyncio.to_thread(download_ipa_url, ipa_url.strip(), src)
        if not zipfile.is_zipfile(src):
            raise HTTPException(400, "不是有效的 IPA 文件")
        cmd = [ZSIGN, "-k", str(CERT_DIR / "cert.p12"), "-p", (CERT_DIR / "password").read_text(),
               "-m", str(CERT_DIR / "cert.mobileprovision"), "-o", str(out_dir / "app.ipa"), "-z", "6"]
        if bundle_id.strip():
            cmd += ["-b", bundle_id.strip()]
        if display_name.strip():
            cmd += ["-n", display_name.strip()]
        if version.strip():
            cmd += ["-r", version.strip()]
        cmd.append(str(src))
        async with sign_lock:
            proc = await asyncio.create_subprocess_exec(
                *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                cwd=out_dir)
            log, _ = await proc.communicate()
        if proc.returncode != 0 or not (out_dir / "app.ipa").exists():
            tail = log.decode(errors="replace").strip().splitlines()[-8:]
            raise HTTPException(500, "簽名失敗：\n" + "\n".join(tail))
        return finish_app(app_id, request)
    except BaseException:
        shutil.rmtree(out_dir, ignore_errors=True)
        raise
    finally:
        src.unlink(missing_ok=True)


@app.post("/api/upload", dependencies=[Depends(require_login)])
async def upload_signed(request: Request, ipa: UploadFile = File(...)):
    """霓簽 App 在手機上簽好後上傳到這裡，只生成安裝鏈接，不再簽名。"""
    app_id = secrets.token_urlsafe(18)
    out_dir = APPS_DIR / app_id
    out_dir.mkdir()
    try:
        await save_upload(ipa, out_dir / "app.ipa")
        if not zipfile.is_zipfile(out_dir / "app.ipa"):
            raise HTTPException(400, "不是有效的 IPA 文件")
        return finish_app(app_id, request)
    except BaseException:
        shutil.rmtree(out_dir, ignore_errors=True)
        raise


@app.get("/api/apps", dependencies=[Depends(require_login)])
def list_apps(request: Request):
    apps = [app_entry(d.name, request) for d in APPS_DIR.iterdir() if (d / "info.json").exists()]
    return {"apps": sorted(apps, key=lambda a: a["signed"], reverse=True)}


@app.delete("/api/apps/{app_id}", dependencies=[Depends(require_login)])
def delete_app(app_id: str):
    if not APP_ID_RE.match(app_id):
        raise HTTPException(404)
    shutil.rmtree(APPS_DIR / app_id, ignore_errors=True)
    return {"ok": True}


# ---------- 安裝（iPhone 安裝時不帶 cookie，所以不需登錄；鏈接本身是隨機不可猜的） ----------

def _app_dir(app_id: str) -> Path:
    d = APPS_DIR / app_id
    if not APP_ID_RE.match(app_id) or not (d / "info.json").exists():
        raise HTTPException(404)
    return d


@app.get("/apps/{app_id}/manifest.plist")
def manifest(app_id: str, request: Request):
    info = json.loads((_app_dir(app_id) / "info.json").read_text())
    ipa_url = f"{base_url(request)}/apps/{app_id}/app.ipa"
    body = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array><dict>
<key>assets</key><array><dict><key>kind</key><string>software-package</string><key>url</key><string>{escape(ipa_url)}</string></dict></array>
<key>metadata</key><dict>
<key>bundle-identifier</key><string>{escape(info['bundle_id'])}</string>
<key>bundle-version</key><string>{escape(info['version'])}</string>
<key>kind</key><string>software</string>
<key>title</key><string>{escape(info['title'])}</string>
</dict></dict></array></dict></plist>
"""
    return Response(body, media_type="application/xml")


@app.get("/apps/{app_id}/app.ipa")
def download_ipa(app_id: str):
    d = _app_dir(app_id)
    info = json.loads((d / "info.json").read_text())
    return FileResponse(d / "app.ipa", media_type="application/octet-stream",
                        filename=f"{info['title']}-{info['version']}.ipa")
