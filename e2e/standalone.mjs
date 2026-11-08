import {createServer} from 'node:http';
import {readFileSync,existsSync,mkdirSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {handle,HOST} from '../edge/identity-gate.mjs';
import {createFootballCareer,replayFootballCareer} from '../frontend/src/footballManagerCareer.js';
const root=resolve('frontend/dist'),out=resolve('.artifacts/standalone');mkdirSync(out,{recursive:true});
const currentBuild=process.env.FOOTBALL_SOURCE_SHA || '';
const testVersionNotice=/^[a-f0-9]{40}$/.test(currentBuild) && !/^0+$/.test(currentBuild);
let publishedBuild=currentBuild;
let cloudMode=false,cloudUnavailable=false,cloudJournal=null,cloudRevision=0;
const server=createServer(async(req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/__auth_preview'||pathname==='/_shadowops/session.js'){const response=await handle(new Request('https://'+HOST+(pathname==='/__auth_preview'?'/':pathname)),{});res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());return;}
 if(pathname==='/api/football/session'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({subject:'11111111-1111-4111-8111-111111111111',expires_at:Math.floor(Date.now()/1000)+120,career_storage:cloudMode?'mongo':'local'}));return;}
 if(pathname==='/api/football/career'){
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  if(!cloudMode||cloudUnavailable){res.writeHead(503);res.end('{"error":"storage_unavailable"}');return;}
  if(req.method==='GET'){res.end(JSON.stringify(cloudJournal?{status:'available',revision:cloudRevision,journal:cloudJournal}:{status:'empty',revision:0}));return;}
  if(req.method==='PUT'){
   try{
    let raw='',bytes=0;
    for await(const chunk of req){bytes+=chunk.length;if(bytes>20000)throw Error('too large');raw+=chunk.toString();}
    const body=JSON.parse(raw);
    if(body.revision!==cloudRevision){res.writeHead(409);res.end('{"error":"revision_conflict"}');return;}
    cloudJournal=replayFootballCareer(body.journal).journal;
    cloudRevision++;
    res.end(JSON.stringify({status:'saved',revision:cloudRevision}));return;
   }catch{res.writeHead(422);res.end('{"error":"invalid_career"}');return;}
  }
  res.writeHead(405);res.end();return;
 }
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
 for(const viewport of [{width:1280,height:800},{width:1788,height:820},{width:390,height:844},{width:360,height:780}]){
  publishedBuild=currentBuild;
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.route('https://id-staging.shadowops.dpdns.org/api/identity/token',route=>route.fulfill({status:401,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:'+server.address().port,'Access-Control-Allow-Credentials':'true','Content-Type':'application/json'},body:'{}'}));
  await page.goto('http://127.0.0.1:'+server.address().port+'/__auth_preview');
  await page.getByRole('link',{name:'Entrar con ShadowOps ID'}).waitFor();
  assert.equal(await page.locator('.chess-football-entry').count(),0);
  await page.screenshot({path:resolve(out,viewport.width+'-login.png')});
  await page.goto('http://127.0.0.1:'+server.address().port+'/');
  await page.getByRole('button',{name:/Modo mánager/}).waitFor();
  await page.waitForFunction(() => {
    const art=document.querySelector('.chess-football-entry__welcome-art');
    return art?.complete && art.naturalWidth===1672;
  });
  assert.equal(await page.getByRole('heading',{name:'Football of Matthias'}).count(),1);
  assert.equal(await page.getByText(/El vestuario/i).count(),0,'Retired vestuario label must not return');
  assert.equal(await page.locator('.chess-football-entry__welcome-scene').count(),1);
  if(viewport.width>700){
    const art=await page.locator('.chess-football-entry__welcome-scene').boundingBox();
    assert.ok(art && art.width>=viewport.width-1 && art.height>=viewport.height-1,
      'Desktop welcome art must cover the full viewport without side bars or stretching');
    assert.ok(art.x<=1 && art.y<=1 && art.x+art.width>=viewport.width-1 && art.y+art.height>=viewport.height-1,
      'Cover artwork must reach all four viewport edges');
    const back=await page.locator('.chess-football-entry__welcome-back').boundingBox();
    assert.ok(back && back.x>=0 && back.y>=0 && back.x+back.width<=viewport.width && back.y+back.height<=viewport.height,
      'Return to ShadowOps must remain visible after cover crops the art');
    if(viewport.width/viewport.height<=1.9){
      const exit=await page.getByRole('button',{name:'Salir de ShadowOps ID',exact:true}).boundingBox();
      assert.ok(back.x<=1 && exit && exit.x+exit.width>=viewport.width-1,
        'Functional top corner controls must cover the baked labels after horizontal crop');
    }
    const transferSummary=await page.locator('.football-transfer > summary').boundingBox();
    assert.ok(transferSummary && transferSummary.y>=0 && transferSummary.y+transferSummary.height<=viewport.height+1,
      'Career transfer must stay inside the viewport on panoramic displays');
  }
  const quick=page.getByRole('button',{name:/Partida rápida/});
  const manager=page.getByRole('button',{name:/Modo mánager/});
  const quickBox=await quick.boundingBox(),managerBox=await manager.boundingBox();
  assert.ok(quickBox&&managerBox&&quickBox.width>=150&&managerBox.width>=150,'Both football modes must retain a usable hit area');
  assert.ok(viewport.width>700 ? quickBox.x+quickBox.width<=managerBox.x : quickBox.y+quickBox.height<=managerBox.y,'Home actions must not overlap in desktop columns or mobile rows');
  const quickLabelOpacity=await page.locator('.chess-football-entry__choice--quick strong').evaluate(el=>getComputedStyle(el).opacity);
  assert.equal(quickLabelOpacity,viewport.width>700?'0':'1','Desktop baked art and mobile readable labels must not duplicate');
  if(viewport.width<=700){
    const mobileArtBytes=await page.evaluate(async()=>{const r=await fetch('/matthias-angry-mobile.webp');return r.ok?(await r.arrayBuffer()).byteLength:0;});
    assert.ok(mobileArtBytes>20000,'Angry Matthias crop must be bundled for the phone hero');
  }
  const transfer=page.locator('.football-transfer > summary');
  await transfer.click();
  assert.ok(await page.getByRole('button',{name:'Exportar carrera',exact:true}).isVisible(),'Transfer remains accessible under new art');
  await transfer.click();
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
   const toast=await notice.boundingBox();
   for(const label of [/Partida rápida/,/Modo mánager/]){
    const entry=await page.getByRole('button',{name:label}).boundingBox();
    assert.ok(entry&&toast&&entry.y+entry.height<=toast.y,'version banner must not cover game entries');
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
  const kickoff=page.getByRole('button',{name:/Saltar al campo · 11v11 · Experto/});
  assert.ok(await kickoff.isVisible());
  assert.equal(await page.locator('.chess-football-entry').evaluate(el=>el.scrollWidth<=el.clientWidth),true,'Difficulty briefing must fit mobile');
  const quickTitle=await page.getByRole('heading',{name:'Elige a tu rival'}).boundingBox();
  const kickoffBox=await kickoff.boundingBox();
  const briefing=await page.locator('.chess-football-entry__quick-setup').boundingBox();
  assert.ok(briefing && briefing.x>=0 && briefing.x+briefing.width<=viewport.width+1,'Briefing must fit screen horizontally');
  assert.ok(quickTitle && quickTitle.y>=0 && quickTitle.y+quickTitle.height<viewport.height,'Match title must start on screen');
  assert.ok(kickoffBox && kickoffBox.width>=180 && kickoffBox.x>=0 && kickoffBox.x+kickoffBox.width<=viewport.width,'Kickoff must remain usable');
  if(viewport.width>=741 || viewport.height>=800){
    assert.ok(kickoffBox.y>=0 && kickoffBox.y+kickoffBox.height<=viewport.height,
      'Kickoff must be visible without scrolling on standard desktop and 390px mobile');
  }
  const masthead=await page.locator('.chess-football-entry__masthead').boundingBox();
  assert.ok(masthead && masthead.width<=2,'Prematch must not waste the first half-screen on the Home masthead');
  const quickLevels=await page.locator('.chess-football-entry__quick-level').all();
  assert.equal(quickLevels.length,4);
  assert.equal(await page.getByRole('button',{name:/^Experto\b/}).getAttribute('aria-pressed'),'true','Difficulty selection must remain stateful');
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
 // Staging cloud activation is explicitly gated by server session state.
 // Real backend credentials and Mongo are never used in this UI fixture.
 cloudMode=true;
 const backup=createFootballCareer('fc-matthias',2468);
 const backupKey='chess-study-football-manager-career-v1:11111111-1111-4111-8111-111111111111';
 const cloudPage=await browser.newPage({viewport:{width:390,height:844}});
 const cloudErrors=[];cloudPage.on('pageerror',error=>cloudErrors.push(String(error)));
 await cloudPage.addInitScript(({key,journal})=>{
  localStorage.setItem(key,JSON.stringify(journal));
 },{key:backupKey,journal:backup});
 await cloudPage.goto('http://127.0.0.1:'+server.address().port+'/');
 await cloudPage.getByRole('button',{name:/Modo mánager/}).waitFor();
 await cloudPage.locator('.football-transfer > summary').click();
 const migrate=cloudPage.getByRole('button',{name:'Importar copia de este navegador a Mongo'});
 await migrate.waitFor();
 assert.equal(cloudJournal,null,'a local backup must not auto-upload to Mongo on login');
 await migrate.click();
 await cloudPage.getByRole('button',{name:'Exportar carrera',exact:true}).waitFor();
 await cloudPage.waitForFunction(()=>document.querySelector('.chess-football-entry__career-resume'));
 assert.equal(cloudRevision,1,'explicit import must save exactly once');
 assert.equal(cloudJournal?.seed,2468);
 assert.equal(await cloudPage.evaluate(key=>localStorage.getItem(key)!==null,backupKey),true,'old local backup must survive a successful import');
 await cloudPage.reload();
 await cloudPage.getByRole('button',{name:'Continuar temporada'}).waitFor();
 await cloudPage.screenshot({path:resolve(out,'390-cloud-career.png')});
 cloudUnavailable=true;
 await cloudPage.reload();
 await cloudPage.getByText(/Mongo no está disponible/).waitFor();
 assert.equal(cloudRevision,1,'outage must not overwrite the acknowledged server journal');
 cloudUnavailable=false;cloudMode=false;
 assert.equal(cloudErrors.length,0,cloudErrors.join('\\n'));
 await cloudPage.close();

 // This is a UI contract test, not a bypass or live ShadowOps-ID session.
 // Simulate staging to prove XI is the only public quick-match format,
 // including refusal of old 5v5 handshakes on desktop and mobile.
 const stagingOrigin='https://staging.football.shadowops.dpdns.org';
 const runtimeIndex='https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/staging/releases/1234567890abcdef/index.html';
 for(const viewport of [{width:1280,height:800},{width:1500,height:788},{width:390,height:844}]){
  const page=await browser.newPage({viewport});
  const errors=[];page.on('pageerror',error=>errors.push(String(error)));
  await page.route(stagingOrigin+'/**',async route=>{
   const pathname=new URL(route.request().url()).pathname;
   if(pathname==='/api/football/session'){
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({subject:'11111111-1111-4111-8111-111111111111',expires_at:Math.floor(Date.now()/1000)+120})});return;
   }
   if(pathname==='/runtime.json'){
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({version:1,release:'1234567890abcdef',index:runtimeIndex,sourceSha:currentBuild})});return;
   }
   if(pathname==='/release.json'){
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({application:'football-of-matthias',source_sha:currentBuild})});return;
   }
   const file=resolve(root,'.'+pathname);
   if((file!==root&&!file.startsWith(root+sep))||!existsSync(file===root?resolve(root,'index.html'):file)){
    await route.fulfill({status:404,body:'not found'});return;
   }
   const resolved=file===root?resolve(root,'index.html'):file;
   await route.fulfill({status:200,contentType:({'.js':'text/javascript','.css':'text/css','.html':'text/html','.json':'application/json'})[extname(resolved)]||'application/octet-stream',body:readFileSync(resolved)});
  });
  // A tiny fake exported iframe tests the parent/ready contract. The actual
  // Godot WASM and its 22 real actors are separately checked in real-web CI.
  let legacyHandshake=false;
  await page.route('https://assets.chess-studio.shadowops.dpdns.org/**',route=>route.fulfill({
   status:200,contentType:'text/html',
   body:'<!doctype html><title>Godot handshake fixture</title><script>parent.postMessage({source:"chess-football-godot",type:"ready",team_size:'+(legacyHandshake?5:11)+'},"*")</script>',
  }));
  await page.route('https://id-staging.shadowops.dpdns.org/**',route=>route.fulfill({
   status:401,headers:{'Access-Control-Allow-Origin':stagingOrigin,'Access-Control-Allow-Credentials':'true','Content-Type':'application/json'},body:'{}',
  }));
  await page.goto(stagingOrigin+'/');
  await page.getByRole('button',{name:/Partida rápida/}).click();
  await page.getByRole('heading',{name:'Elige a tu rival'}).waitFor();
  assert.equal(await page.locator('.chess-football-entry__quick-team-size').count(),0,'no 5v5/11v11 selector');
  const matchFormat=page.locator('.chess-football-entry__quick-details');
  assert.ok(await matchFormat.getByText('11 contra 11',{exact:true}).isVisible());
  assert.ok(await matchFormat.getByText('Campo completo',{exact:true}).isVisible());
  assert.ok(await page.locator('.chess-football-entry__quick-fixture[aria-label="FC Matthias contra Real Enroque"]').isVisible());
  await page.getByRole('button',{name:/^Difícil\b/}).click();
  assert.ok(await page.getByRole('button',{name:'Saltar al campo · 11v11 · Difícil'}).isVisible());
  assert.ok(await page.locator('.chess-football-entry').evaluate(el=>el.scrollWidth<=el.clientWidth),'XI-only setup must not overflow viewport');
  await page.screenshot({path:resolve(out,viewport.width+'-staging-xi-setup.png')});
  await page.getByRole('button',{name:'Saltar al campo · 11v11 · Difícil'}).click();
  const frame=page.locator('iframe.chess-football-godot-host__frame');
  await frame.waitFor();
  assert.equal(await frame.getAttribute('src'),runtimeIndex+'#football-difficulty=hard&football-team-size=11');
  assert.equal(await frame.getAttribute('referrerpolicy'),'origin');
  await page.waitForFunction(()=>document.querySelector('.chess-football-godot-host')?.dataset.runtimeReady==='true');
  assert.equal(await page.locator('.chess-football-godot-host__fallback').count(),0);
  // The outer full-screen shell contains an independent, cross-origin
  // Web canvas. Verify its IFRAME fits the browser exactly, including
  // the user's real 1500x788 viewport. Godot WASM coverage tests the
  // actual canvas separately (not this mocked ready handshake).
  const hostBox=await page.locator('.chess-football-godot-host').boundingBox();
  const frameBox=await frame.boundingBox();
  assert.ok(hostBox && frameBox && [hostBox,frameBox].every(box=>
    Math.abs(box.x)<=1 && Math.abs(box.y)<=1 &&
    Math.abs(box.width-viewport.width)<=1 &&
    Math.abs(box.height-viewport.height)<=1
  ),'XI Web iframe and immersive host must fill the viewport without clipping');
  assert.ok(await page.evaluate(()=>
    document.documentElement.scrollWidth<=innerWidth+1 &&
    document.documentElement.scrollHeight<=innerHeight+1
  ),'XI immersive host must not add a scrollable cropped edge');
  if(viewport.width===1500){
   const exitBox=await page.getByRole('button',{name:'Salir de Chess Football'}).boundingBox();
   assert.ok(exitBox && exitBox.x>=0 && exitBox.y>=0 &&
    exitBox.x+exitBox.width<=viewport.width+1 &&
    exitBox.y+exitBox.height<=viewport.height+1,
    'Exit button must remain reachable at the user's 1500x788 resolution');
   await page.screenshot({path:resolve(out,'1500-xi-iframe-host.png')});
  }
  await page.getByRole('button',{name:'Salir de Chess Football'}).click();
  await page.getByRole('button',{name:/Partida rápida/}).click();
  await page.getByRole('button',{name:/^Difícil\b/}).click();
  assert.equal(await page.locator('.chess-football-entry__quick-team-size').count(),0);
  // Stale Godot runtimes that claim five players per side cannot start.
  legacyHandshake=true;
  await page.getByRole('button',{name:'Saltar al campo · 11v11 · Difícil'}).click();
  await page.getByRole('alert').getByRole('heading',{name:'Chess Football no ha arrancado'}).waitFor();
  assert.equal(await page.locator('.chess-football-godot-host').getAttribute('data-runtime-ready'),'false');
  legacyHandshake=false;
  await page.getByRole('button',{name:'Reintentar'}).click();
  await page.waitForFunction(()=>document.querySelector('.chess-football-godot-host')?.dataset.runtimeReady==='true');
  assert.equal(await page.locator('iframe.chess-football-godot-host__frame').getAttribute('src'),runtimeIndex+'#football-difficulty=hard&football-team-size=11');
  assert.equal(errors.length,0,errors.join('\n'));
  await page.close();
 }
 console.log('FOOTBALL_STAGING_XI_ONLY_BROWSER_OK players=22 viewports=1280+1500x788+390 iframe_fills_viewport=1 legacy_5v5_rejected=1');
 console.log('FOOTBALL_STANDALONE_DESKTOP_MOBILE_OK');
}finally{await browser.close();await new Promise(ok=>server.close(ok));}
