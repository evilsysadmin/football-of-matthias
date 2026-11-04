import {createServer} from 'node:http';
import {readFileSync,existsSync,mkdirSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {handle,HOST} from '../edge/identity-gate.mjs';
const root=resolve('frontend/dist'),out=resolve('.artifacts/standalone');mkdirSync(out,{recursive:true});
const currentBuild=process.env.FOOTBALL_SOURCE_SHA || '';
const testVersionNotice=/^[a-f0-9]{40}$/.test(currentBuild) && !/^0+$/.test(currentBuild);
let publishedBuild=currentBuild;
const server=createServer(async(req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/__auth_preview'||pathname==='/_shadowops/session.js'){const response=await handle(new Request('https://'+HOST+(pathname==='/__auth_preview'?'/':pathname)),{});res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());return;}
 if(pathname==='/api/football/session'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({subject:'11111111-1111-4111-8111-111111111111',expires_at:Math.floor(Date.now()/1000)+120}));return;}
 // Simulate an actual version A -> B deployment on the running local browser.
 if(pathname==='/release.json'&&testVersionNotice){
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  res.end(JSON.stringify({application:'football-of-matthias',source_sha:publishedBuild}));return;
 }
 const path=resolve(root,'.'+pathname);
 if(path!==root&&!path.startsWith(root+sep)){res.writeHead(403);res.end();return;}
 const file=path===root?resolve(root,'index.html'):path;
 if(!existsSync(file)){res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.html':'text/html','.json':'application/json'})[extname(file)]||'application/octet-stream');res.end(readFileSync(file));
});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
const browser=await chromium.launch({headless:true});
try{
 for(const viewport of [{width:1280,height:800},{width:390,height:844}]){
  publishedBuild=currentBuild;
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.route('https://id-staging.shadowops.dpdns.org/api/identity/token',route=>route.fulfill({status:401,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:'+server.address().port,'Access-Control-Allow-Credentials':'true','Content-Type':'application/json'},body:'{}'}));
  await page.goto('http://127.0.0.1:'+server.address().port+'/__auth_preview');
  await page.getByRole('link',{name:'Entrar con ShadowOps ID'}).waitFor();
  assert.equal(await page.locator('.chess-football-entry').count(),0);
  await page.screenshot({path:resolve(out,viewport.width+'-login.png')});
  await page.goto('http://127.0.0.1:'+server.address().port+'/');
  await page.getByRole('button',{name:/Modo mánager/}).waitFor();
  await page.getByRole('button',{name:'Salir de ShadowOps ID',exact:true}).click({trial:true});
  await page.screenshot({path:resolve(out,viewport.width+'-welcome.png')});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  if(testVersionNotice){
   assert.equal(await page.getByTestId('football-release-notice').count(),0,'same build is not an update');
   publishedBuild='b'.repeat(40)===currentBuild?'d'.repeat(40):'b'.repeat(40);
   await page.evaluate(()=>window.dispatchEvent(new Event('online')));
   const notice=page.getByTestId('football-release-notice');
   await notice.waitFor();
   assert.ok(await page.getByRole('button',{name:'Actualizar',exact:true}).isVisible());
   if(viewport.width===390){
    const entry=await page.getByRole('button',{name:/Modo mánager/}).boundingBox();
    const toast=await notice.boundingBox();
    assert.ok(entry&&toast&&entry.y+entry.height<=toast.y,'mobile version banner must not cover manager entry');
   }
   assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'update banner must not cause horizontal overflow');
   await page.screenshot({path:resolve(out,viewport.width+'-new-version-welcome.png')});
   await page.getByRole('button',{name:'Ahora no'}).click();
   assert.equal(await page.getByTestId('football-release-notice').count(),0);
  }
  await page.getByRole('button',{name:/Partida rápida/}).click();
  await page.getByRole('heading',{name:'Elige a tu rival'}).waitFor();
  assert.equal(await page.locator('.chess-football-entry__quick-level').count(),4);
  assert.equal(await page.getByRole('button',{name:/^Normal\b/}).getAttribute('aria-pressed'),'true');
  await page.getByRole('button',{name:/^Experto\b/}).click();
  assert.equal(await page.getByRole('button',{name:/^Experto\b/}).getAttribute('aria-pressed'),'true');
  assert.ok(await page.getByRole('button',{name:/Saltar al campo · Experto/}).isVisible());
  assert.equal(await page.locator('.chess-football-entry').evaluate(el=>el.scrollWidth<=el.clientWidth),true,'Difficulty briefing must fit mobile');
  await page.screenshot({path:resolve(out,viewport.width+'-quick-difficulty.png')});
  await page.getByRole('button',{name:/Volver a Football/}).click();
  await page.getByRole('button',{name:/Modo mánager/}).click();
  await page.screenshot({path:resolve(out,viewport.width+'-manager.png')});
  if(testVersionNotice){
   publishedBuild='c'.repeat(40)===currentBuild?'e'.repeat(40):'c'.repeat(40);
   await page.evaluate(()=>window.dispatchEvent(new Event('online')));
   await page.getByTestId('football-release-notice').waitFor();
   assert.equal(await page.getByRole('button',{name:'Actualizar',exact:true}).count(),0,'manager must defer reload');
   assert.ok(await page.getByRole('button',{name:'Después',exact:true}).isVisible());
   await page.screenshot({path:resolve(out,viewport.width+'-new-version-manager.png')});
   await page.getByRole('button',{name:'Después'}).click();
  }
  await page.getByRole('button',{name:'Elegir FC Matthias'}).click();
  await page.locator('.chess-football-entry__development > summary').click();
  const firstPlayer=page.locator('.chess-football-entry__player-card').first();
  await firstPlayer.locator('summary').click();
  await firstPlayer.locator('summary').evaluate(el=>el.scrollIntoView({block:'start',inline:'nearest'}));
  assert.ok(await firstPlayer.getByText('Portero de reflejos felinos',{exact:false}).isVisible());
  assert.equal(await firstPlayer.locator('.chess-football-entry__scouting dt').count(),7);
  assert.equal(await page.locator('.chess-football-entry').evaluate(el=>el.scrollWidth<=el.clientWidth),true,'Manager must not overflow horizontally');
  await page.screenshot({path:resolve(out,viewport.width+'-scouting-card.png')});
  await firstPlayer.screenshot({path:resolve(out,viewport.width+'-scouting-detail.png')});
  assert.equal(errors.length,0,errors.join('\n'));await page.close();
 }
 console.log('FOOTBALL_STANDALONE_DESKTOP_MOBILE_OK');
}finally{await browser.close();await new Promise(ok=>server.close(ok));}
