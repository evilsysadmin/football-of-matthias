import {createServer} from 'node:http';
import {readFileSync,existsSync,mkdirSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {handle,HOST} from '../edge/identity-gate.mjs';
const root=resolve('frontend/dist'),out=resolve('.artifacts/standalone');mkdirSync(out,{recursive:true});
const server=createServer(async(req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/__auth_preview'||pathname==='/_shadowops/session.js'){const response=await handle(new Request('https://'+HOST+(pathname==='/__auth_preview'?'/':pathname)),{});res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());return;}
 if(pathname==='/api/football/session'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({subject:'11111111-1111-4111-8111-111111111111',expires_at:Math.floor(Date.now()/1000)+120}));return;}
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
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.route('https://id-staging.shadowops.dpdns.org/api/identity/token',route=>route.fulfill({status:401,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:'+server.address().port,'Access-Control-Allow-Credentials':'true','Content-Type':'application/json'},body:'{}'}));
  await page.goto('http://127.0.0.1:'+server.address().port+'/__auth_preview');
  await page.getByRole('link',{name:'Entrar con ShadowOps ID'}).waitFor();
  assert.equal(await page.locator('.chess-football-entry').count(),0);
  await page.screenshot({path:resolve(out,viewport.width+'-login.png')});
  await page.goto('http://127.0.0.1:'+server.address().port+'/');
  await page.getByRole('button',{name:/Modo mánager/}).waitFor();
  await page.screenshot({path:resolve(out,viewport.width+'-welcome.png')});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.getByRole('button',{name:/Modo mánager/}).click();
  await page.screenshot({path:resolve(out,viewport.width+'-manager.png')});
  assert.equal(errors.length,0,errors.join('\n'));await page.close();
 }
 console.log('FOOTBALL_STANDALONE_DESKTOP_MOBILE_OK');
}finally{await browser.close();await new Promise(ok=>server.close(ok));}
