// NineSun 網頁執行環境：最小的 WASI 墊片 + 引擎呼叫（瀏覽器和 Node 共用）
(function (root) {
  function makeWasi(getMem) {
    const ENOSYS = 52, EBADF = 8, OK = 0;
    const dv = () => new DataView(getMem().buffer);
    const u8 = () => new Uint8Array(getMem().buffer);
    let lineBuf = "";
    const dec = new TextDecoder();
    const nosys = () => ENOSYS;
    return {
      args_get: () => OK,
      args_sizes_get: (a, b) => { dv().setUint32(a, 0, true); dv().setUint32(b, 0, true); return OK; },
      environ_get: () => OK,
      environ_sizes_get: (a, b) => { dv().setUint32(a, 0, true); dv().setUint32(b, 0, true); return OK; },
      clock_res_get: (id, p) => { dv().setBigUint64(p, 1000n, true); return OK; },
      clock_time_get: (id, prec, p) => { dv().setBigUint64(p, BigInt(Math.round(Date.now() * 1e6)), true); return OK; },
      fd_write: (fd, iovs, n, written) => {
        const d = dv(); let total = 0;
        for (let i = 0; i < n; i++) {
          const ptr = d.getUint32(iovs + i * 8, true), len = d.getUint32(iovs + i * 8 + 4, true);
          lineBuf += dec.decode(u8().slice(ptr, ptr + len)); total += len;
        }
        const parts = lineBuf.split("\n"); lineBuf = parts.pop();
        parts.forEach((l) => console.log("[ns]", l));
        d.setUint32(written, total, true); return OK;
      },
      fd_prestat_get: () => EBADF,
      fd_prestat_dir_name: () => EBADF,
      fd_fdstat_get: (fd, p) => { if (fd > 2) return EBADF; const d = dv(); d.setUint8(p, 2); d.setUint16(p + 2, 0, true); d.setBigUint64(p + 8, 0n, true); d.setBigUint64(p + 16, 0n, true); return OK; },
      fd_close: () => OK, fd_fdstat_set_flags: nosys, fd_filestat_get: () => EBADF, fd_filestat_set_size: nosys,
      fd_pread: () => EBADF, fd_read: () => EBADF, fd_readdir: () => EBADF, fd_seek: () => EBADF, fd_sync: () => OK, fd_tell: () => EBADF,
      path_create_directory: nosys, path_filestat_get: () => 44, path_filestat_set_times: nosys, path_link: nosys,
      path_open: () => 44, path_readlink: nosys, path_remove_directory: nosys, path_rename: nosys, path_symlink: nosys,
      path_unlink_file: nosys, poll_oneoff: nosys,
      proc_exit: (c) => { throw new Error("proc_exit " + c); },
      random_get: (p, n) => { const b = u8().subarray(p, p + n); (root.crypto || require("crypto").webcrypto).getRandomValues(b); return OK; },
    };
  }

  async function boot(wasmBytes, files) {
    let inst;
    const wasi = makeWasi(() => inst.exports.memory);
    const { instance } = await WebAssembly.instantiate(wasmBytes, { wasi_snapshot_preview1: wasi });
    inst = instance;
    const ex = inst.exports;
    if (ex._initialize) ex._initialize();
    const enc = new TextEncoder(), dec = new TextDecoder();
    const put = (kind, bytes) => {
      const p = ex.ns_alloc(bytes.length);
      new Uint8Array(ex.memory.buffer, p, bytes.length).set(bytes);
      ex.ns_file(kind, p, bytes.length);
      ex.ns_free(p);
    };
    for (const [kind, bytes] of files) put(kind, bytes);
    if (!ex.ns_start()) throw new Error("引擎啟動失敗");
    return {
      send(text, profile, nowMs) {
        const b = enc.encode(JSON.stringify({ text, profile, now: nowMs }));
        const p = ex.ns_alloc(b.length);
        new Uint8Array(ex.memory.buffer, p, b.length).set(b);
        const n = ex.ns_send(p, b.length);
        ex.ns_free(p);
        const out = ex.ns_out();
        return JSON.parse(dec.decode(new Uint8Array(ex.memory.buffer, out, n)));
      },
      reset() { ex.ns_reset(); },
    };
  }
  root.NineSunRuntime = { boot };
  if (typeof module !== "undefined") module.exports = { boot };
})(typeof window !== "undefined" ? window : globalThis);
