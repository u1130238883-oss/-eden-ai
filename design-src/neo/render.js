// node render.js <dir> <outdir> : renders every *.html at 390x844 @3x (1170x2532)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const [src, out] = process.argv.slice(2);
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY } });
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3 });
  for (const f of fs.readdirSync(src).filter(f => f.endsWith('.html')).sort()) {
    const p = await ctx.newPage();
    await p.setContent(fs.readFileSync(path.join(src, f), 'utf8'), { waitUntil: 'networkidle' });
    await p.evaluate(() => document.fonts.ready);
    const fam = await p.evaluate(() => [...new Set([...document.fonts].filter(x => x.status === 'loaded').map(x => x.family))]);
    await p.waitForTimeout(300);
    await p.screenshot({ path: path.join(out, f.replace('.html', '.png')), clip: { x: 0, y: 0, width: 390, height: 844 } });
    console.log(f, fam.join(','));
    await p.close();
  }
  await b.close();
})();
