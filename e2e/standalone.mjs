import {createServer} from 'node:http';
import {readFileSync,existsSync,mkdirSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
const root=resolve('frontend/dist'),out=resolve('.artifacts/standalone');mkdirSync(out,{recursive:true});
const server=createServer((req,res)=>{
 const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
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
