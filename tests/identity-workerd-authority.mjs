// Only the socket-free workerd test can route to this ephemeral authority.
const issuer='https://id-staging.shadowops.dpdns.org';
const subject='11111111-1111-4111-8111-111111111111';
const proof='soc1_'+'A'.repeat(43);
let pair,jwk,claims,active=true,redirect='',redirectTouches=0;
const encode=bytes=>btoa(String.fromCharCode(...bytes)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const json=value=>encode(new TextEncoder().encode(JSON.stringify(value)));
export default {async fetch(request){
 const url=new URL(request.url);
 if(url.origin!==issuer)throw Error('Unexpected authority hostname');
 if(url.pathname==='/__fixture/setup'){
  if(!pair){pair=await crypto.subtle.generateKey('Ed25519',true,['sign','verify']);jwk={...await crypto.subtle.exportKey('jwk',pair.publicKey),kid:'runtime-fixture',use:'sig',alg:'EdDSA'};}
  const now=Math.floor(Date.now()/1000);active=true;redirect=url.searchParams.get('redirect')||'';redirectTouches=0;
  claims={iss:issuer,aud:'football',sub:subject,iat:now,nbf:now,exp:now+120,sv:1,jti:encode(crypto.getRandomValues(new Uint8Array(16)))};
  const unsigned=json({alg:'EdDSA',kid:jwk.kid})+'.'+json(claims);
  const token=unsigned+'.'+encode(new Uint8Array(await crypto.subtle.sign('Ed25519',pair.privateKey,new TextEncoder().encode(unsigned))));
  return Response.json({token,subject});
 }
 if(url.pathname==='/__fixture/revoke'){active=false;return new Response(null,{status:204});}
 if(url.pathname==='/__fixture/status')return Response.json({redirectTouches});
 if(url.pathname==='/__fixture/redirect-target'){redirectTouches++;throw Error('Redirect target must never be contacted');}
 if(url.pathname==='/api/identity/jwks'){
  if(redirect==='keys')return Response.redirect(issuer+'/__fixture/redirect-target',302);
  return Response.json({keys:[jwk]});
 }
 if(url.pathname==='/api/identity/freshness'){
  if(request.headers.has('Cookie')||request.headers.has('Origin')||request.headers.get('Authorization')!=='Bearer '+proof)throw Error('Unexpected service authority');
  if(redirect==='freshness')return Response.redirect(issuer+'/__fixture/redirect-target',307);
  const body=await request.json();
  if(!active||body.subject!==subject||body.session_version!==claims.sv||body.token_jti!==claims.jti)return new Response(null,{status:401});
  return Response.json({issuer,audience:'football',...body,checked_at:Math.floor(Date.now()/1000),account_active:true,session_active:true,token_active:true});
 }
 throw Error('Unexpected authority path');
}};
