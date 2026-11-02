// Ephemeral local/CI credentials only. Never a real Identity account or key.
import {webcrypto} from 'node:crypto';
export const SUBJECT='11111111-1111-4111-8111-111111111111';
export async function identityFixture(){
 const pair=await webcrypto.subtle.generateKey({name:'Ed25519'},true,['sign','verify']);
 const jwk={...await webcrypto.subtle.exportKey('jwk',pair.publicKey),kid:'fixture-key',use:'sig',alg:'EdDSA'};
 const now=Math.floor(Date.now()/1000);
 const claims={iss:'https://id-staging.shadowops.dpdns.org',aud:'football',sub:SUBJECT,iat:now,nbf:now,exp:now+120,sv:1,jti:'fixture-session-token'};
 const encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
 async function sign(changes={},headerChanges={}){
  const content=encode({alg:'EdDSA',kid:'fixture-key',typ:'JWT',...headerChanges})+'.'+encode({...claims,...changes});
  return content+'.'+Buffer.from(await webcrypto.subtle.sign('Ed25519',pair.privateKey,Buffer.from(content))).toString('base64url');
 }
 const proof='soc1_'+'F'.repeat(43);
 let active=true;
 async function request(url,options={}){
  if(url===claims.iss+'/api/identity/jwks')return Response.json({keys:[jwk]});
  if(url===claims.iss+'/api/identity/freshness'){
   const input=JSON.parse(options.body);
   if(!active||options.headers.Authorization!=='Bearer '+proof)return new Response('',{status:401});
   return Response.json({issuer:claims.iss,audience:'football',subject:input.subject,session_version:input.session_version,token_jti:input.token_jti,checked_at:Math.floor(Date.now()/1000),account_active:true,session_active:true,token_active:true});
  }
  throw Error('Unexpected fixture network request');
 }
 return {claims,sign,proof,request,jwk,revoke:()=>{active=false;},subtle:webcrypto.subtle};
}
