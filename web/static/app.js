"use strict";
/* 前端只負責畫面。所有推算都在伺服器上，這裡拿到的已經是算好的結果。 */

/* 第一次來的人，先照瀏覽器的語言；之後以他自己選的為準。 */
function detectLang() {
  const saved = localStorage.getItem("nt.lang");
  if (saved) return saved;
  for (const raw of (navigator.languages || [navigator.language || "en"])) {
    const c = String(raw).toLowerCase();
    if (c.startsWith("zh")) return "zh";
    if (c.startsWith("es")) return "es";
    if (c.startsWith("it")) return "it";
    if (c.startsWith("en")) return "en";
  }
  return "zh";
}

const S = {
  lang: detectLang(),
  tab: "today",
  me: null,
  birth: JSON.parse(localStorage.getItem("nt.birth") || "null"),
  other: JSON.parse(localStorage.getItem("nt.other") || "null"),
  plan: "p10",
  order: null,
};

const LANGS = [
  ["zh", "繁中"], ["en", "EN"], ["es", "ES"], ["it", "IT"],
];

const T = {
  today:   { zh: "今日", en: "Today", es: "Hoy", it: "Oggi" },
  chart:   { zh: "命盤", en: "Chart", es: "Carta", it: "Carta" },
  fortune: { zh: "運程", en: "Fortune", es: "Destino", it: "Sorte" },
  synastry:{ zh: "合盤", en: "Synastry", es: "Sinastría", it: "Sinastria" },
  member:  { zh: "會員", en: "Member", es: "Miembro", it: "Membro" },
  appName: { zh: "九型十二宮", en: "Nine & Twelve", es: "Nueve y Doce", it: "Nove e Dodici" },
  birthday:{ zh: "出生日期", en: "Date of birth", es: "Fecha de nacimiento", it: "Data di nascita" },
  year:    { zh: "年", en: "Year", es: "Año", it: "Anno" },
  month:   { zh: "月", en: "Month", es: "Mes", it: "Mese" },
  day:     { zh: "日", en: "Day", es: "Día", it: "Giorno" },
  save:    { zh: "查看", en: "View", es: "Ver", it: "Vedi" },
  daytime: { zh: "白天", en: "Daytime", es: "De día", it: "Di giorno" },
  night:   { zh: "晚上", en: "Night", es: "De noche", it: "Di notte" },
  lifeNo:  { zh: "靈數", en: "Life Number", es: "Número de Vida", it: "Numero di Vita" },
  lifePal: { zh: "命宮", en: "Life Palace", es: "Palacio de Vida", it: "Palazzo della Vita" },
  pillars: { zh: "本命三柱", en: "The three pillars", es: "Los tres pilares", it: "I tre pilastri" },
  twelve:  { zh: "十二宮盤", en: "The twelve palaces", es: "Los doce palacios", it: "I dodici palazzi" },
  enne:    { zh: "九型人格", en: "Enneagram", es: "Eneagrama", it: "Enneagramma" },
  annual:  { zh: "流年", en: "Annual", es: "Anual", it: "Annuale" },
  luck:    { zh: "大運", en: "Major cycles", es: "Ciclos mayores", it: "Cicli maggiori" },
  aspects: { zh: "大運十二方面", en: "Twelve aspects",
             es: "Los doce aspectos", it: "I dodici aspetti" },
  monthly: { zh: "月運", en: "Monthly", es: "Mensual", it: "Mensile" },
  targetY: { zh: "查看年份", en: "Year to view", es: "Año a consultar", it: "Anno da vedere" },
  personA: { zh: "本人", en: "You", es: "Tú", it: "Tu" },
  personB: { zh: "對方", en: "The other person", es: "La otra persona", it: "L'altra persona" },
  compare: { zh: "合盤", en: "Compare", es: "Comparar", it: "Confronta" },
  needMem: { zh: "這一頁需要會員", en: "This page needs a membership",
             es: "Esta página requiere membresía", it: "Questa pagina richiede l'abbonamento" },
  freeNote:{ zh: "今日永遠免費，其餘三頁需要會員。",
             en: "Today is always free; the other three pages need a membership.",
             es: "Hoy es siempre gratis; las otras tres páginas requieren membresía.",
             it: "Oggi è sempre gratis; le altre tre pagine richiedono l'abbonamento." },
  goMember:{ zh: "去開通會員", en: "Get a membership", es: "Obtener membresía", it: "Attiva l'abbonamento" },
  active:  { zh: "會員生效中", en: "Membership active", es: "Membresía activa", it: "Abbonamento attivo" },
  daysLeft:{ zh: "剩餘天數", en: "Days left", es: "Días restantes", it: "Giorni rimasti" },
  noMem:   { zh: "尚未開通", en: "Not a member yet", es: "Aún no eres miembro", it: "Non ancora abbonato" },
  pickPlan:{ zh: "選擇方案", en: "Choose a plan", es: "Elige un plan", it: "Scegli un piano" },
  days:    { zh: "天", en: "days", es: "días", it: "giorni" },
  yuan:    { zh: "元", en: "CNY", es: "CNY", it: "CNY" },
  buy:     { zh: "產生付款編號", en: "Get a payment reference",
             es: "Generar referencia de pago", it: "Genera riferimento di pagamento" },
  payStep: { zh: "付款步驟", en: "How to pay", es: "Cómo pagar", it: "Come pagare" },
  step1:   { zh: "用微信或支付寶掃下面的碼，付款",
             en: "Scan one of the codes below with WeChat or Alipay and pay",
             es: "Escanea uno de los códigos con WeChat o Alipay y paga",
             it: "Scansiona uno dei codici con WeChat o Alipay e paga" },
  step2:   { zh: "付款時，備註欄一定要填下面這組編號",
             en: "In the payment note, you must type the reference below",
             es: "En la nota del pago, escribe la referencia de abajo",
             it: "Nella nota di pagamento, scrivi il riferimento qui sotto" },
  step3:   { zh: "付完回到這一頁按「我付好了」，稍等我確認後就會開通",
             en: "Then come back, tap “I have paid”, and it opens once confirmed",
             es: "Vuelve, toca «Ya pagué» y se activará tras la confirmación",
             it: "Torna qui, tocca «Ho pagato» e si attiverà dopo la conferma" },
  paid:    { zh: "我付好了", en: "I have paid", es: "Ya pagué", it: "Ho pagato" },
  checking:{ zh: "查詢中…", en: "Checking…", es: "Comprobando…", it: "Controllo…" },
  waitConf:{ zh: "已收到，等待確認。確認後這一頁會自動開通。",
             en: "Received. Waiting for confirmation; this page unlocks automatically.",
             es: "Recibido. Esperando confirmación; se desbloqueará automáticamente.",
             it: "Ricevuto. In attesa di conferma; si sbloccherà automaticamente." },
  wechat:  { zh: "微信支付", en: "WeChat Pay", es: "WeChat Pay", it: "WeChat Pay" },
  alipay:  { zh: "支付寶", en: "Alipay", es: "Alipay", it: "Alipay" },
  haveCode:{ zh: "有啟用碼？", en: "Have an activation code?",
             es: "¿Tienes un código?", it: "Hai un codice?" },
  redeem:  { zh: "啟用", en: "Redeem", es: "Canjear", it: "Riscatta" },
  restore: { zh: "換裝置？用會員憑證恢復",
             en: "Changed device? Restore with your member key",
             es: "¿Cambiaste de dispositivo? Restaura con tu clave",
             it: "Cambiato dispositivo? Ripristina con la tua chiave" },
  myKey:   { zh: "你的會員憑證（換手機時要用，請自己存好）",
             en: "Your member key (keep it — you need it on a new device)",
             es: "Tu clave de miembro (guárdala para otro dispositivo)",
             it: "La tua chiave (conservala per un altro dispositivo)" },
  restoreBtn:{ zh: "恢復", en: "Restore", es: "Restaurar", it: "Ripristina" },
  enterBirth:{ zh: "先填出生日期", en: "Enter a date of birth first",
               es: "Introduce primero la fecha de nacimiento",
               it: "Inserisci prima la data di nascita" },
  tapRow:  { zh: "點任一列看完整含義。", en: "Tap any row for the full meaning.",
             es: "Toca una fila para ver el significado completo.",
             it: "Tocca una riga per il significato completo." },
  close:   { zh: "關閉", en: "Close", es: "Cerrar", it: "Chiudi" },
};

const t = (k) => (T[k] && (T[k][S.lang] || T[k].en)) || k;
const el = (h) => { const d = document.createElement("div"); d.innerHTML = h.trim(); return d.firstChild; };
const esc = (s) => String(s).replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

async function api(path, body) {
  const r = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(Object.assign({ lang: S.lang }, body || {})),
  });
  let data = {};
  try { data = await r.json(); } catch (e) { /* 伺服器沒回 JSON */ }
  return { ok: r.ok, status: r.status, data };
}

/* ── 共用片段 ─────────────────────────────────────────────── */

function birthForm(which) {
  const b = (which === "other" ? S.other : S.birth) || { year: "", month: "", day: "" };
  const id = which === "other" ? "o" : "b";
  return `
    <label>${esc(which === "other" ? t("personB") : t("birthday"))}</label>
    <div class="row3">
      <input type="number" id="${id}y" placeholder="${esc(t("year"))}" value="${b.year || ""}" inputmode="numeric">
      <input type="number" id="${id}m" placeholder="${esc(t("month"))}" value="${b.month || ""}" inputmode="numeric">
      <input type="number" id="${id}d" placeholder="${esc(t("day"))}" value="${b.day || ""}" inputmode="numeric">
    </div>`;
}

function readBirth(which) {
  const id = which === "other" ? "o" : "b";
  const g = (s) => parseInt(document.getElementById(id + s).value, 10);
  const v = { year: g("y"), month: g("m"), day: g("d") };
  if (!v.year || !v.month || !v.day) return null;
  localStorage.setItem(which === "other" ? "nt.other" : "nt.birth", JSON.stringify(v));
  if (which === "other") S.other = v; else S.birth = v;
  return v;
}

function rowsHtml(rows, highlight) {
  return `<div class="rows">` + rows.map((r, i) => `
    <div class="prow ${highlight === i ? "hl" : ""}" data-palace="${r.palace}">
      <div class="dot" style="background:${palaceColor(r.palace)}">
        <b>${r.palace}</b><i>${esc(r.element)}</i>
      </div>
      <div class="mid">
        <div class="tri">${esc(r.tripleText)}</div>
        <div class="br">${esc(r.brief)}</div>
      </div>
      <span class="verdict v${esc(r.verdict)}">${esc(r.readingText)}</span>
    </div>`).join("") + `</div>`;
}

const PALACE_COLORS = ["#b3392c", "#8e8e93", "#3f7fb8", "#3f7fb8", "#b3392c", "#3f7fb8",
                       "#8e8e93", "#b3392c", "#4e8c5a", "#a08050", "#a08050", "#4e8c5a"];
const palaceColor = (n) => PALACE_COLORS[((n - 1) % 12 + 12) % 12];

function enneCard(e) {
  return `<button class="enne" id="enneBtn">
    <div class="col">
      <div class="t">${esc(t("enne"))}</div>
      <div class="lab">${esc(e.label)}</div>
      <div class="nm">${esc(e.name)}</div>
      <div class="tag">${esc(e.tagline)}</div>
    </div>
    <div class="badge" style="background:${esc(e.color)}">${e.type}</div>
  </button>`;
}

function lockCard() {
  return `<div class="card lock">
    <div class="big">♛</div>
    <h2>${esc(t("needMem"))}</h2>
    <p class="muted">${esc(t("freeNote"))}</p>
    <button class="primary" onclick="go('member')">${esc(t("goMember"))}</button>
  </div>`;
}

/* ── 分頁 ─────────────────────────────────────────────────── */

async function viewToday() {
  const main = document.getElementById("main");
  main.innerHTML = `<div class="card">
    <h2>${esc(t("birthday"))}</h2>
    ${birthForm("self")}
    <button class="primary" id="go">${esc(t("save"))}</button>
    <div id="out"></div>
  </div>
  <p class="tiny" style="text-align:center">${esc(t("freeNote"))}</p>`;

  const run = async () => {
    const b = readBirth("self");
    const out = document.getElementById("out");
    if (!b) { out.innerHTML = `<div class="err">${esc(t("enterBirth"))}</div>`; return; }
    const { data } = await api("/api/today", b);
    if (data.error) { out.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
    out.innerHTML = `
      <h3>${esc(t("lifeNo"))} ${data.lifeNumber} · ${esc(data.lifePalace)}</h3>
      <div class="rows">
        <div class="prow" data-palace="${data.day.palace}">
          <div class="dot" style="background:${palaceColor(data.day.palace)}"><b>${data.day.palace}</b></div>
          <div class="mid"><div class="tri">${esc(t("daytime"))} · ${esc(data.day.named)}</div>
          <div class="br">${esc(data.day.brief)}</div></div>
        </div>
        <div class="prow" data-palace="${data.night.palace}">
          <div class="dot" style="background:${palaceColor(data.night.palace)}"><b>${data.night.palace}</b></div>
          <div class="mid"><div class="tri">${esc(t("night"))} · ${esc(data.night.named)}</div>
          <div class="br">${esc(data.night.brief)}</div></div>
        </div>
      </div>
      <p class="tiny">${esc(t("tapRow"))}</p>`;
    bindRows(out);
  };
  document.getElementById("go").onclick = run;
  if (S.birth) run();
}

async function viewChart() {
  const main = document.getElementById("main");
  if (!S.me || !S.me.member) { main.innerHTML = lockCard(); return; }
  main.innerHTML = `<div class="card">
    <h2>${esc(t("birthday"))}</h2>
    ${birthForm("self")}
    <button class="primary" id="go">${esc(t("save"))}</button>
  </div><div id="out"></div>`;

  const run = async () => {
    const b = readBirth("self");
    const out = document.getElementById("out");
    if (!b) { out.innerHTML = `<div class="err">${esc(t("enterBirth"))}</div>`; return; }
    const { status, data } = await api("/api/natal", b);
    if (status === 402) { main.innerHTML = lockCard(); return; }
    if (data.error) { out.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
    out.innerHTML = `
      <div class="card">
        <h2>${esc(t("pillars"))}</h2>
        <div class="pillars">
          <div class="pillar"><div class="k">${esc(t("year"))}</div><div class="v">${data.triple[0]}</div></div>
          <div class="pillar"><div class="k">${esc(t("month"))}</div><div class="v">${data.triple[1]}</div></div>
          <div class="pillar"><div class="k">${esc(t("day"))}</div><div class="v">${data.triple[2]}</div></div>
        </div>
        <h3>${esc(t("lifeNo"))} ${data.lifeNumber} · ${esc(data.lifePalace)}</h3>
      </div>
      ${enneCard(data.enneagram)}
      <div class="card">
        <h2>${esc(t("twelve"))}</h2>
        ${rowsHtml(data.rows, 0)}
        <p class="tiny">${esc(t("tapRow"))}</p>
      </div>`;
    bindRows(out);
    document.getElementById("enneBtn").onclick = () => openEnne(data.enneagram.type);
  };
  document.getElementById("go").onclick = run;
  if (S.birth) run();
}

async function viewFortune() {
  const main = document.getElementById("main");
  if (!S.me || !S.me.member) { main.innerHTML = lockCard(); return; }
  const yNow = new Date().getFullYear();
  main.innerHTML = `<div class="card">
    <h2>${esc(t("birthday"))}</h2>
    ${birthForm("self")}
    <label style="margin-top:10px">${esc(t("targetY"))}</label>
    <input type="number" id="ty" value="${yNow}" inputmode="numeric">
    <button class="primary" id="go">${esc(t("save"))}</button>
  </div><div id="out"></div>`;

  const run = async () => {
    const b = readBirth("self");
    const out = document.getElementById("out");
    if (!b) { out.innerHTML = `<div class="err">${esc(t("enterBirth"))}</div>`; return; }
    b.targetYear = parseInt(document.getElementById("ty").value, 10) || yNow;
    const { status, data } = await api("/api/fortune", b);
    if (status === 402) { main.innerHTML = lockCard(); return; }
    if (data.error) { out.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
    out.innerHTML = `
      <div class="card"><h2>${esc(t("luck"))}</h2>
        <table class="mini"><tbody>${data.luck.map((p) => `
          <tr><th>${p.start}–${p.end}</th><td>${esc(p.row.palaceShort)}</td>
          <td><span class="verdict v${esc(p.row.verdict)}">${esc(p.row.readingText)}</span></td></tr>`).join("")}
        </tbody></table></div>
      <div class="card"><h2>${esc(t("aspects"))} · ${data.aspects.start}–${data.aspects.end}</h2>
        <div class="rows">${data.aspects.rows.map((r) => `
          <div class="prow" data-palace="${r.aspect}">
            <div class="dot" style="background:${palaceColor(r.aspect)}"><b>${r.aspect}</b></div>
            <div class="mid"><div class="tri">${esc(r.aspectShort)} · ${esc(r.tripleText)}</div>
            <div class="br">${esc(r.aspectBrief)}</div></div>
            <span class="verdict v${esc(r.verdict)}">${esc(r.readingText)}</span>
          </div>`).join("")}</div></div>
      <div class="card"><h2>${esc(t("annual"))}</h2>
        <div class="rows">${data.years.map((it) => `
          <div class="prow ${it.year === data.targetYear ? "hl" : ""}" data-palace="${it.row.palace}">
            <div class="dot" style="background:${palaceColor(it.row.palace)}"><b>${it.row.palace}</b></div>
            <div class="mid"><div class="tri">${it.year} · ${esc(it.row.palaceShort)}</div>
            <div class="br">${esc(it.row.brief)}</div></div>
            <span class="verdict v${esc(it.row.verdict)}">${esc(it.row.readingText)}</span>
          </div>`).join("")}</div></div>
      <div class="card"><h2>${esc(t("monthly"))} · ${data.targetYear}</h2>
        <div class="rows">${data.months.map((it) => `
          <div class="prow" data-palace="${it.row.palace}">
            <div class="dot" style="background:${palaceColor(it.row.palace)}"><b>${it.row.palace}</b></div>
            <div class="mid"><div class="tri">${esc(it.name)} · ${esc(it.row.palaceShort)}</div>
            <div class="br">${esc(it.row.brief)}</div></div>
            <span class="verdict v${esc(it.row.verdict)}">${esc(it.row.readingText)}</span>
          </div>`).join("")}</div>
        <p class="tiny">${esc(t("tapRow"))}</p></div>`;
    bindRows(out);
  };
  document.getElementById("go").onclick = run;
  if (S.birth) run();
}

async function viewSynastry() {
  const main = document.getElementById("main");
  if (!S.me || !S.me.member) { main.innerHTML = lockCard(); return; }
  main.innerHTML = `<div class="card">
    <h2>${esc(t("personA"))}</h2>${birthForm("self")}
    <h2 style="margin-top:16px">${esc(t("personB"))}</h2>${birthForm("other")}
    <button class="primary" id="go">${esc(t("compare"))}</button>
  </div><div id="out"></div>`;

  document.getElementById("go").onclick = async () => {
    const a = readBirth("self"), b = readBirth("other");
    const out = document.getElementById("out");
    if (!a || !b) { out.innerHTML = `<div class="err">${esc(t("enterBirth"))}</div>`; return; }
    const { status, data } = await api("/api/synastry", { a, b });
    if (status === 402) { main.innerHTML = lockCard(); return; }
    if (data.error) { out.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
    out.innerHTML = `
      <div class="card"><h3>${esc(t("lifeNo"))} ${data.lifeNumber} · ${esc(data.lifePalace)}</h3></div>
      ${enneCard(data.enneagram)}
      <div class="card"><h2>${esc(t("twelve"))}</h2>${rowsHtml(data.rows, 0)}
      <p class="tiny">${esc(t("tapRow"))}</p></div>`;
    bindRows(out);
    document.getElementById("enneBtn").onclick = () => openEnne(data.enneagram.type);
  };
}

/* ── 會員 ─────────────────────────────────────────────────── */

async function viewMember() {
  const main = document.getElementById("main");
  const me = S.me || {};
  const plans = me.plans || [];
  const isMem = !!me.member;

  main.innerHTML = `
    <div class="card">
      <h2>${esc(isMem ? t("active") : t("noMem"))}</h2>
      ${isMem ? `<p class="muted">${esc(t("daysLeft"))}：<b>${me.daysLeft}</b> ${esc(t("days"))}</p>` : ""}
      <p class="tiny">${esc(t("freeNote"))}</p>
    </div>

    <div class="card">
      <h2>${esc(t("pickPlan"))}</h2>
      <div class="plans">${plans.map((p) => `
        <button class="plan ${p.id === S.plan ? "on" : ""}" data-plan="${p.id}">
          <span class="amt">¥${p.amount}</span>
          <span class="d"><b>${p.days} ${esc(t("days"))}</b>
            <div class="per">¥${(p.amount / p.days).toFixed(1)} / ${esc(t("day"))}</div></span>
        </button>`).join("")}</div>
      <button class="primary" id="mkOrder">${esc(t("buy"))}</button>
      <div id="payBox"></div>
    </div>

    <div class="card">
      <h2>${esc(t("haveCode"))}</h2>
      <input type="text" id="code" placeholder="NT-XXXX-XXXX-XXXX" autocapitalize="characters">
      <button class="primary" id="doRedeem">${esc(t("redeem"))}</button>
      <div id="redeemMsg"></div>
    </div>

    <div class="card">
      <h2>${esc(t("myKey"))}</h2>
      <div class="ref" style="font-size:13px;letter-spacing:1px">${esc(me.uid || "")}</div>
      <h3>${esc(t("restore"))}</h3>
      <input type="text" id="rkey" placeholder="…">
      <button class="primary" id="doRestore">${esc(t("restoreBtn"))}</button>
      <div id="restoreMsg"></div>
    </div>`;

  main.querySelectorAll(".plan").forEach((b) => {
    b.onclick = () => { S.plan = b.dataset.plan; viewMember(); };
  });
  document.getElementById("mkOrder").onclick = makeOrder;
  document.getElementById("doRedeem").onclick = doRedeem;
  document.getElementById("doRestore").onclick = doRestore;
  if (S.order) renderPay(S.order);
}

async function makeOrder() {
  const { data } = await api("/api/order", { plan: S.plan });
  if (data.error) {
    document.getElementById("payBox").innerHTML = `<div class="err">${esc(data.error)}</div>`;
    return;
  }
  S.order = data;
  renderPay(data);
}

function renderPay(o) {
  const box = document.getElementById("payBox");
  if (!box) return;
  box.innerHTML = `
    <div class="notice">
      <b>${esc(t("payStep"))}</b>
      <ol style="margin:8px 0 0;padding-left:20px">
        <li>${esc(t("step1"))}（¥${o.amount}）</li>
        <li>${esc(t("step2"))}</li>
        <li>${esc(t("step3"))}</li>
      </ol>
    </div>
    <div class="ref">${esc(o.ref)}</div>
    <div class="qr">
      <figure><img src="/pay/wechat.png" alt="${esc(t("wechat"))}">
        <figcaption>${esc(t("wechat"))}</figcaption></figure>
      <figure><img src="/pay/alipay.png" alt="${esc(t("alipay"))}">
        <figcaption>${esc(t("alipay"))}</figcaption></figure>
    </div>
    <button class="primary" id="didPay">${esc(t("paid"))}</button>
    <div id="payMsg"></div>`;
  document.getElementById("didPay").onclick = async () => {
    const msg = document.getElementById("payMsg");
    msg.innerHTML = `<div class="muted">${esc(t("checking"))}</div>`;
    const { data } = await api("/api/order/status", { ref: o.ref });
    if (data.error) { msg.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
    if (data.status === "paid") {
      await refreshMe();
      S.order = null;
      go("member");
      return;
    }
    msg.innerHTML = `<div class="ok">${esc(t("waitConf"))}</div>`;
  };
}

async function doRedeem() {
  const msg = document.getElementById("redeemMsg");
  const { data } = await api("/api/redeem", { code: document.getElementById("code").value });
  if (data.error) { msg.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
  await refreshMe();
  go("member");
}

async function doRestore() {
  const msg = document.getElementById("restoreMsg");
  const { data } = await api("/api/restore", { uid: document.getElementById("rkey").value });
  if (data.error) { msg.innerHTML = `<div class="err">${esc(data.error)}</div>`; return; }
  S.me = data;
  go("member");
}

/* ── 詳情 ─────────────────────────────────────────────────── */

function bindRows(scope) {
  scope.querySelectorAll(".prow").forEach((r) => {
    r.onclick = () => openPalace(parseInt(r.dataset.palace, 10));
  });
}

function showSheet(html) {
  document.getElementById("sheetBody").innerHTML =
    `<button class="ghost close" onclick="document.getElementById('sheet').close()">${esc(t("close"))}</button>` + html;
  document.getElementById("sheet").showModal();
}

async function openPalace(n) {
  const { data } = await api("/api/palace", { palace: n });
  if (data.error) return;
  showSheet(`<div class="hero" style="background:${palaceColor(n)}">
      <div class="n">${esc(data.named)}</div></div>
    <div class="chips">${data.keywords.map((k) => `<span class="chip">${esc(k)}</span>`).join("")}</div>`);
}

async function openEnne(type) {
  const { data } = await api("/api/enneagram", { type });
  if (data.error) return;
  showSheet(`
    <div class="hero" style="background:${esc(data.color)}">
      <div class="l">${esc(data.label)}</div>
      <div class="n">${esc(data.name)}</div>
      <div class="g">${esc(data.tagline)}</div>
    </div>
    <p style="font-size:14px">${esc(data.summary)}</p>
    ${data.sections.map((s) => `<h3>${esc(s.title)}</h3>
      <ul>${s.lines.map((l) => `<li>${esc(l)}</li>`).join("")}</ul>`).join("")}`);
}

/* ── 外框 ─────────────────────────────────────────────────── */

async function refreshMe() {
  const { data } = await api("/api/me");
  S.me = data;
  const pill = document.getElementById("memberPill");
  pill.textContent = data.member ? `♛ ${data.daysLeft}${t("days")}` : t("noMem");
  pill.classList.toggle("on", !!data.member);
}

function go(tab) {
  S.tab = tab;
  document.querySelectorAll("nav.tabs button").forEach((b) =>
    b.classList.toggle("on", b.dataset.tab === tab));
  ({ today: viewToday, chart: viewChart, fortune: viewFortune,
     synastry: viewSynastry, member: viewMember }[tab] || viewToday)();
}
window.go = go;

function applyLang() {
  document.documentElement.lang = { zh: "zh-Hant", en: "en", es: "es", it: "it" }[S.lang];
  document.getElementById("appName").textContent = t("appName");
  document.title = t("appName");
  document.getElementById("langSel").value = S.lang;
  document.querySelectorAll("[data-t]").forEach((n) => { n.textContent = t(n.dataset.t); });
}

document.getElementById("langSel").onchange = (e) => {
  S.lang = LANGS.some((l) => l[0] === e.target.value) ? e.target.value : "zh";
  localStorage.setItem("nt.lang", S.lang);
  applyLang();
  refreshMe().then(() => go(S.tab));
};
document.getElementById("memberPill").onclick = () => go("member");
document.querySelectorAll("nav.tabs button").forEach((b) => {
  b.onclick = () => go(b.dataset.tab);
});
document.getElementById("sheet").addEventListener("click", (e) => {
  if (e.target.id === "sheet") e.target.close();
});

applyLang();
refreshMe().then(() => go("today"));
