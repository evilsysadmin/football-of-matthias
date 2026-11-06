// Football-only Mongo career contract. The authenticated Pages edge supplies
// the immutable subject with a separate, private service credential.
import {timingSafeEqual} from 'node:crypto';
import {replayFootballCareer,FOOTBALL_CAREER_VERSION} from '../frontend/src/footballManagerCareer.js';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const PROOF=/^fsc1_[A-Za-z0-9_-]{43}$/;
const LIMIT=16000;
const HEADERS={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
function json(value,status=200){return new Response(JSON.stringify(value),{status,headers:HEADERS});}
function authorized(request,secret){
 const token=request.headers.get('authorization')?.replace(/^Bearer /,'');
 if(!PROOF.test(secret||'')||!PROOF.test(token||''))return false;
 return timingSafeEqual(Buffer.from(secret),Buffer.from(token));
}
function normalize(document){
 if(!document)return json({status:'empty',revision:0});
 if(!Number.isSafeInteger(document.revision)||document.revision<1)return json({error:'corrupt_career'},422);
 const journal=document.journal;
 if(Number.isSafeInteger(journal?.version)&&journal.version>FOOTBALL_CAREER_VERSION){
  return json({status:'future',revision:document.revision},200);
 }
 try{return json({status:'available',revision:document.revision,journal:replayFootballCareer(journal).journal});}
 catch{return json({error:'corrupt_career'},422);}
}
export async function handleCareerRequest(request,{collection,serviceCredential}={}){
 const url=new URL(request.url);
 if(url.pathname!=='/api/career'||url.search)return json({error:'not_found'},404);
 if(!['GET','PUT'].includes(request.method))return json({error:'method_not_allowed'},405);
 if(!authorized(request,serviceCredential))return json({error:'unauthorized'},401);
 const sub=request.headers.get('x-football-subject');
 if(!sub||!UUID.test(sub))return json({error:'unauthorized'},401);
 try{
  if(request.method==='GET')return normalize(await collection.findOne({_id:sub}));
  if(request.headers.get('content-type')!=='application/json')return json({error:'invalid_request'},415);
  // The HTTP listener bounds bytes before calling this handler.
  const text=await request.text();
  if(Buffer.byteLength(text,'utf8')>20000)return json({error:'too_large'},413);
  let parsed;
  try{parsed=JSON.parse(text);}catch{return json({error:'invalid_request'},400);}
  if(!parsed||typeof parsed!=='object'||Array.isArray(parsed)
    ||Object.keys(parsed).sort().join(',')!=='journal,revision'
    ||!Number.isSafeInteger(parsed.revision)||parsed.revision<0)return json({error:'invalid_request'},400);
  if(Number.isSafeInteger(parsed.journal?.version)&&parsed.journal.version>FOOTBALL_CAREER_VERSION){
   return json({error:'future_career'},422);
  }
  let journal;
  try{journal=replayFootballCareer(parsed.journal).journal;}
  catch{return json({error:'invalid_career'},422);}
  if(Buffer.byteLength(JSON.stringify(journal),'utf8')>LIMIT)return json({error:'too_large'},413);
  const now=new Date();
  if(parsed.revision===0){
   try{
    await collection.insertOne({_id:sub,revision:1,journal,updated_at:now});
    return json({status:'saved',revision:1});
   }catch(error){if(error?.code===11000)return json({error:'revision_conflict'},409);throw error;}
  }
  // Even a caller that knows the revision cannot replace an unreadable/future
  // journal. CAS below also fences a concurrent update after this check.
  const current=await collection.findOne({_id:sub});
  if(!current||current.revision!==parsed.revision)return json({error:'revision_conflict'},409);
  if(Number.isSafeInteger(current.journal?.version)&&current.journal.version>FOOTBALL_CAREER_VERSION){
   return json({error:'protected_career'},409);
  }
  try{replayFootballCareer(current.journal);}
  catch{return json({error:'protected_career'},409);}
  const update=await collection.updateOne({_id:sub,revision:parsed.revision},
    {$set:{journal,updated_at:now},$inc:{revision:1}});
  if(update.matchedCount!==1)return json({error:'revision_conflict'},409);
  return json({status:'saved',revision:parsed.revision+1});
 }catch{return json({error:'storage_unavailable'},503);}
}
