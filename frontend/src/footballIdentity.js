const ORIGIN='https://id-staging.shadowops.dpdns.org';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
async function request(url,options={}){
 const response=await fetch(url,{cache:'no-store',signal:AbortSignal.timeout(8000),...options});
 if(!response.ok)throw Error('ShadowOps ID session unavailable');return response;
}
function session(value){
 if(!value||!UUID.test(value.subject)||!Number.isSafeInteger(value.expires_at)||value.expires_at*1000<=Date.now())throw Error('Invalid server session');
 if(value.career_storage!==undefined&&!['mongo','local'].includes(value.career_storage))throw Error('Invalid Football career backend');
 return {subject:value.subject,expiresAt:value.expires_at,careerStorage:value.career_storage||'local'};
}
export async function currentFootballSession(){return session(await (await request('/api/football/session')).json());}
export async function renewFootballSession(){
 const response=await request(ORIGIN+'/api/identity/token',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json'},body:'{}'});
 const value=await response.json();
 return session(await (await request('/api/football/session',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:value.token})})).json());
}
export async function closeFootballSession(){
 // Only report global logout after Identity commits revocation.
 await request(ORIGIN+'/api/identity/logout',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json'},body:'{}'});
 await request('/api/football/logout',{method:'POST'});
}
export async function requireFootballLogin(){
 try{await fetch('/api/football/logout',{method:'POST'});}catch{/* Current authority is discarded locally as well. */}
 location.replace('/');
}
