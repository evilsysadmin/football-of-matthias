import test from 'node:test';
import assert from 'node:assert/strict';
import {handle,HOST,verifyIdentityToken,authorize} from '../edge/identity-gate.mjs';
import {identityFixture} from './identity-fixture.mjs';
const origin='https://'+HOST;
test('anonymous and unconfigured requests cannot read the game, including Pages aliases',async()=>{
 const env={ASSETS:{fetch:()=>{throw Error('private assets reached');}}};
 for(const path of ['/','/assets/game.js','/runtime.json']){
  const response=await handle(new Request(origin+path),env);
  assert.equal(response.status,401);assert.equal(response.headers.get('Cache-Control'),'no-store');
  if(path==='/')assert.match(await response.text(),/Entrar con ShadowOps ID/);
 }
 assert.equal((await handle(new Request('https://football-staging-aha.pages.dev/'),env)).status,404);
});
test('JWT requires the exact issuer, audience, lifetime, subject, signature and algorithm',async()=>{
 const fixture=await identityFixture(),options={request:fixture.request,subtle:fixture.subtle};
 const token=await fixture.sign();assert.equal((await verifyIdentityToken(token,options)).sub,fixture.claims.sub);
 for(const change of [{aud:'chronicles'},{iss:'https://id.shadowops.dpdns.org'},{sub:'admin'},{sv:0},{exp:fixture.claims.iat+121},{exp:fixture.claims.iat-1},{nbf:fixture.claims.iat+30}]){
  await assert.rejects(verifyIdentityToken(await fixture.sign(change),options));
 }
 await assert.rejects(verifyIdentityToken(await fixture.sign({},{alg:'none'}),options));
 const parts=token.split('.');parts[1]=Buffer.from(JSON.stringify({...fixture.claims,sv:2})).toString('base64url');
 await assert.rejects(verifyIdentityToken(parts.join('.'),options));
});
test('signed JWT alone and revoked/unavailable or mismatched freshness cannot authorize',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign(),env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof};
 const options={request:fixture.request,subtle:fixture.subtle};
 await assert.rejects(authorize(token,{},options));
 assert.equal((await authorize(token,env,options)).sub,fixture.claims.sub);
 for(const wrong of [{audience:'chronicles'},{token_active:false},{session_active:false},{account_active:false},{checked_at:fixture.claims.iat-10},{subject:'22222222-2222-4222-8222-222222222222'},{session_version:2}]){
  await assert.rejects(authorize(token,env,{...options,request:async(url,args)=>{
   const response=await fixture.request(url,args);return url.endsWith('/freshness')?Response.json({...await response.json(),...wrong}):response;
  }}));
 }
 fixture.revoke();await assert.rejects(authorize(token,env,options));
 await assert.rejects(authorize(token,env,{...options,request:async()=>{throw Error('offline');}}));
});
test('session exchange sets only a host-only HttpOnly cookie; protected requests recheck revocation',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign();let reads=0;
 const env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof,ASSETS:{fetch:()=>{reads++;return new Response('private game');}}};
 const options={request:fixture.request,subtle:fixture.subtle};
 const post=new Request(origin+'/api/football/session',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:JSON.stringify({token})});
 const response=await handle(post,env,options);assert.equal(response.status,200);
 const cookie=response.headers.get('Set-Cookie');assert.match(cookie,/Secure; HttpOnly; SameSite=Lax/);assert.doesNotMatch(cookie,/Domain=/);
 assert.equal((await response.json()).subject,fixture.claims.sub);
 const req=()=>new Request(origin+'/',{headers:{Cookie:cookie.split(';')[0]}});
 assert.equal((await handle(req(),env,options)).status,200);assert.equal(reads,1);
 fixture.revoke();assert.equal((await handle(req(),env,options)).status,401);assert.equal(reads,1);
});
test('CSRF, duplicate cookies, missing proof and token-in-query fail closed',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign(),env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof};
 const options={request:fixture.request,subtle:fixture.subtle};
 for(const badOrigin of ['', 'https://staging.chess-studio.shadowops.dpdns.org']){
  const req=new Request(origin+'/api/football/session',{method:'POST',headers:{Origin:badOrigin,'Content-Type':'application/json'},body:JSON.stringify({token})});
  assert.equal((await handle(req,env,options)).status,403);
 }
 const duplicate=`__Host-football_staging=${token}; __Host-football_staging=${token}`;
 assert.equal((await handle(new Request(origin+'/',{headers:{Cookie:duplicate}}),env,options)).status,401);
 assert.equal((await handle(new Request(origin+'/?token='+token),env,options)).status,401);
});

test('unavailable upstream diagnostics contain only a fixed stage, never credentials or claims',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign();
 const env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof};
 const req=()=>new Request(origin+'/api/football/session',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:JSON.stringify({token})});
 const cases=[{env:{},request:fixture.request,stage:'edge_configuration'},
  {env,request:async()=>{throw Error('private transport detail');},stage:'identity_keys'},
  {env,request:async(url,options)=>url.endsWith('/jwks')?fixture.request(url,options):new Response('private upstream detail',{status:403}),stage:'identity_freshness'}];
 for(const item of cases){
  const response=await handle(req(),item.env,{request:item.request,subtle:fixture.subtle});
  assert.equal(response.status,503);assert.equal(response.headers.get('X-Football-Identity-Error'),item.stage);
  assert.deepEqual(await response.json(),{error:'access_unavailable'});
 }
 const denied=await handle(new Request(origin+'/api/football/session'),env,{request:fixture.request});
 assert.equal(denied.status,401);assert.equal(denied.headers.get('X-Football-Identity-Error'),null);
});

test('default transport retains the Worker global fetch receiver for keys and freshness',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign(),original=globalThis.fetch;let calls=0;
 globalThis.fetch=function(url,options){assert.equal(this,globalThis,'native Worker fetch requires its global receiver');calls++;return fixture.request(url,options);};
 try{
  const claims=await authorize(token,{SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof});
  assert.equal(claims.sub,fixture.claims.sub);assert.equal(calls,2);
 }finally{globalThis.fetch=original;}
});


test('Mongo career proxy verifies live Identity, forwards only the verified UUID and rejects CSRF',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign(),origin='https://'+HOST;
 const secret='fsc1_'+'a'.repeat(43),url='https://api-staging.football.shadowops.dpdns.org/api/career';
 const env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof,
  FOOTBALL_CAREER_SERVICE_CREDENTIAL:secret,FOOTBALL_CAREER_API_URL:url};
 const observed=[];
 const request=async(target,init)=>{
  if(target===url){
   observed.push({target,init});
   assert.equal(init.headers['X-Football-Subject'],fixture.claims.sub);
   assert.equal(init.headers.Authorization,'Bearer '+secret);
   return Response.json(init.method==='GET'?{status:'empty',revision:0}:{status:'saved',revision:1});
  }
  return fixture.request(target,init);
 };
 const opt={request,subtle:fixture.subtle};
 const cookie='__Host-football_staging='+token;
 const get=()=>new Request(origin+'/api/football/career',{headers:{Cookie:cookie}});
 let response=await handle(get(),env,opt);
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),{status:'empty',revision:0});
 const put=(requestOrigin=origin)=>new Request(origin+'/api/football/career',{method:'PUT',
  headers:{Cookie:cookie,Origin:requestOrigin,'Content-Type':'application/json'},
  body:JSON.stringify({revision:0,journal:{version:4}})});
 assert.equal((await handle(put('https://evil.example'),env,opt)).status,403);
 assert.equal(observed.length,1);
 assert.equal((await handle(put(),env,opt)).status,200);
 assert.equal(observed.length,2);
 fixture.revoke();
 assert.equal((await handle(get(),env,opt)).status,401);
 assert.equal(observed.length,2);
});
test('Mongo proxy fails closed on missing bindings or redirect, without exposing service tokens',async()=>{
 const fixture=await identityFixture(),token=await fixture.sign();
 const get=()=>new Request('https://'+HOST+'/api/football/career',{
  headers:{Cookie:'__Host-football_staging='+token}});
 const base={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:fixture.proof};
 const options={subtle:fixture.subtle,request:fixture.request};
 assert.equal((await handle(get(),base,options)).status,503);
 const env={...base,FOOTBALL_CAREER_SERVICE_CREDENTIAL:'fsc1_'+'a'.repeat(43),
  FOOTBALL_CAREER_API_URL:'https://api-staging.football.shadowops.dpdns.org/api/career'};
 const reply=await handle(get(),env,{...options,request:(url,init)=>
  url===env.FOOTBALL_CAREER_API_URL?new Response('',{status:302,headers:{Location:'https://evil.example'}}):fixture.request(url,init)});
 assert.equal(reply.status,503);
 assert.doesNotMatch(await reply.text(),/fsc1_|11111111/);
});
