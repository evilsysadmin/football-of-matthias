import {handle,HOST,ISSUER} from './edge/identity-gate.mjs';
const origin='https://'+HOST;
const assert=(value,message)=>{if(!value)throw Error(message);};
const env={SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL:'soc1_'+'A'.repeat(43),ASSETS:{fetch:async()=>new Response('authenticated game')}};
const setup=async(mode='')=>(await fetch(ISSUER+'/__fixture/setup?redirect='+mode)).json();
const exchange=token=>handle(new Request(origin+'/api/football/session',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:JSON.stringify({token})}),env);
export default {async test(){
 assert((await handle(new Request(origin+'/'),env)).status===401,'anonymous game denied');
 const fixture=await setup();
 const session=await exchange(fixture.token);
 assert(session.status===200,'real workerd Ed25519/session exchange must succeed');
 assert((await session.json()).subject===fixture.subject,'server-confirmed UUID');
 const cookie=session.headers.get('Set-Cookie');
 assert(cookie.includes('Secure; HttpOnly; SameSite=Lax')&&!cookie.includes('Domain='),'host-only protected cookie');
 const protectedRequest=()=>new Request(origin+'/',{headers:{Cookie:cookie.split(';')[0]}});
 assert((await handle(protectedRequest(),env)).status===200,'authenticated game served');
 await fetch(ISSUER+'/__fixture/revoke');
 assert((await handle(protectedRequest(),env)).status===401,'still-unexpired token denied after revocation');
 for(const mode of ['keys','freshness']){
  const fixture=await setup(mode);const denied=await exchange(fixture.token);
  assert(denied.status===503,'redirected authority denied');
  assert((await (await fetch(ISSUER+'/__fixture/status')).json()).redirectTouches===0,'no redirect follows or service proof forwarding');
 }
 assert((await handle(new Request('https://football-staging-aha.pages.dev/'),env)).status===404,'Pages alias denied');
 console.log('FOOTBALL_WORKERD_IDENTITY_OK crypto=true revocation=true redirects_denied=true');
}};
