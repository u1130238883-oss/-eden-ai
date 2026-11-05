/* 將內分泌圖譜（data.js）的疾病併入醫學百科 */
(function(){if(typeof DIS==="undefined")return;
 DIS.forEach(d=>{if(MED.DIS.some(x=>x.id===d.id))return;
  MED.DIS.push({id:d.id,zh:d.zh,en:d.en,red:d.red||0,sys:"endo",def:d.cause,sx:d.sx.slice(),more:d.more,dx:d.lab,tx:d.tx,tip:"",glands:d.g.slice()})});
})();
