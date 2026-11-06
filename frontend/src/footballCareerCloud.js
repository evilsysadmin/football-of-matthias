// Cloud progress is never inferred from localStorage: only an acknowledged
// Mongo API write may be presented as a synced save.
import {replayFootballCareer} from './footballManagerCareer.js';
const ENDPOINT='/api/football/career';
async function request(method,body){
 const response=await fetch(ENDPOINT,{method,cache:'no-store',credentials:'same-origin',
  headers:{Accept:'application/json',...(body?{'Content-Type':'application/json'}:{})},
  ...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(8000)});
 if(response.status===409)throw Object.assign(Error('Football cloud revision conflict'),{code:'conflict'});
 if(!response.ok)throw Error('Football cloud unavailable');
 return response.json();
}
export async function readFootballCloudCareer(){
 const saved=await request('GET');
 if(!Number.isSafeInteger(saved.revision)||saved.revision<0)throw Error('Invalid remote career revision');
 if(saved.status==='empty'&&saved.revision===0)return {status:'empty',revision:0};
 if(saved.status==='future'&&saved.revision>0)return {status:'future',revision:saved.revision};
 if(saved.status==='available'&&saved.revision>0){
  return {status:'available',revision:saved.revision,...replayFootballCareer(saved.journal)};
 }
 throw Error('Invalid remote career response');
}
export async function writeFootballCloudCareer(journal,revision){
 if(!Number.isSafeInteger(revision)||revision<0)throw Error('Missing Football remote revision');
 const next=replayFootballCareer(journal);
 const saved=await request('PUT',{revision,journal:next.journal});
 if(saved.status!=='saved'||saved.revision!==revision+1)throw Error('Invalid remote career acknowledgement');
 return {status:'cloud',revision:saved.revision};
}
