const { chromium } = require('playwright');
const fs=require('fs'),path=require('path');
const [src,out]=process.argv.slice(2);
(async()=>{
 const b=await chromium.launch({proxy:{server:process.env.HTTPS_PROXY}});
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:3,ignoreHTTPSErrors:false});
 const files=fs.readdirSync(src).filter(f=>f.endsWith('.dc.html'));
 for(const f of files){
  let h=fs.readFileSync(path.join(src,f),'utf8');
  const m=h.match(/"accent":\{"editor":"color","default":"(#[0-9A-Fa-f]+)"/);
  h=h.replace(/\{\{accent\}\}/g,m?m[1]:'#E8FF3A')
     .replace(/<script src="\.\/support\.js"><\/script>/,'')
     .replace(/<script type="text\/x-dc"[\s\S]*?<\/script>/,'')
     .replace(/<x-dc>\s*<helmet>/,'').replace(/<\/helmet>/,'').replace(/<\/x-dc>/,'');
  const p=await ctx.newPage();
  await p.setContent(h,{waitUntil:'networkidle'});
  await p.evaluate(()=>document.fonts.ready);
  const fam=await p.evaluate(()=>[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family));
  await p.waitForTimeout(300);
  await p.screenshot({path:path.join(out,f.replace('.dc.html','.png')),clip:{x:0,y:0,width:390,height:844}});
  console.log(f,[...new Set(fam)].join(','));
  await p.close();
 }
 await b.close();
})();
