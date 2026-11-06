import test from 'node:test';
import assert from 'node:assert/strict';
import {handleCareerRequest} from './career-api.mjs';
import {createFootballCareer,playFootballCareerRound} from '../frontend/src/footballManagerCareer.js';

const A='11111111-1111-4111-8111-111111111111', B='22222222-2222-4222-8222-222222222222';
const credential='fsc1_'+'a'.repeat(43);
function memoryCollection(){
 const records=new Map();
 return {
  records,
  async findOne({_id}){return records.get(_id)||null;},
  async insertOne(doc){if(records.has(doc._id)){const e=Error('duplicate');e.code=11000;throw e;}records.set(doc._id,doc);},
  async updateOne({_id,revision},update){
   const old=records.get(_id);
   if(!old||old.revision!==revision)return {matchedCount:0};
   records.set(_id,{...old,...update.$set,revision:old.revision+update.$inc.revision});
   return {matchedCount:1};
  }
 };
}
function req(sub=A,method='GET',body,proof=credential){
 return new Request('http://football-internal/api/career',{method,
  headers:{'Authorization':'Bearer '+proof,'X-Football-Subject':sub,'Content-Type':'application/json'},
  ...(body?{body:JSON.stringify(body)}:{})});
}
test('one subject owns one independently revisioned deterministic Mongo journal',async()=>{
 const collection=memoryCollection();
 const env={collection,serviceCredential:credential};
 const first=createFootballCareer('fc-matthias',2026);
 let response=await handleCareerRequest(req(),env);
 assert.deepEqual(await response.json(),{status:'empty',revision:0});
 response=await handleCareerRequest(req(A,'PUT',{revision:0,journal:first}),env);
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),{status:'saved',revision:1});
 assert.deepEqual(await (await handleCareerRequest(req(B),env)).json(),{status:'empty',revision:0});
 const played=playFootballCareerRound(first).journal;
 response=await handleCareerRequest(req(A,'PUT',{revision:1,journal:played}),env);
 assert.equal((await response.json()).revision,2);
 const restored=await (await handleCareerRequest(req(A),env)).json();
 assert.equal(restored.status,'available');
 assert.equal(restored.journal.rounds.length,1);
 assert.deepEqual(restored.journal,played);
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:1,journal:first}),env)).status,409);
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:0,journal:first}),env)).status,409);
 assert.equal(collection.records.get(A).revision,2);
});
test('rejects forged identities, missing proof and invalid or future journals without writes',async()=>{
 const collection=memoryCollection(),env={collection,serviceCredential:credential};
 const first=createFootballCareer('fc-matthias');
 for(const subject of ['admin','',null]){
  assert.equal((await handleCareerRequest(req(subject),env)).status,401);
 }
 assert.equal((await handleCareerRequest(req(A,'GET',null,'fsc1_'+'b'.repeat(43)),env)).status,401);
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:0,journal:{...first,nextTactic:'cheat'}}),env)).status,422);
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:0,journal:{...first,version:100}}),env)).status,422);
 assert.equal(collection.records.size,0);
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:0,journal:first}),env)).status,200);
 collection.records.set(A,{_id:A,revision:3,journal:{...first,version:100}});
 assert.deepEqual(await (await handleCareerRequest(req(),env)).json(),{status:'future',revision:3});
 assert.equal((await handleCareerRequest(req(A,'PUT',{revision:3,journal:{...first,nextTactic:'no'}}),env)).status,422);
 assert.equal(collection.records.get(A).revision,3);
});
test('fails closed on database error, method abuse and oversized payload',async()=>{
 const bad={findOne(){throw Error('mongodb offline');}};
 assert.equal((await handleCareerRequest(req(),{collection:bad,serviceCredential:credential})).status,503);
 const env={collection:memoryCollection(),serviceCredential:credential};
 assert.equal((await handleCareerRequest(new Request('http://football-internal/api/career',{method:'DELETE'}),env)).status,405);
 assert.equal((await handleCareerRequest(new Request('http://football-internal/api/career?sub='+B),env)).status,404);
 const oversized=new Request('http://football-internal/api/career',{method:'PUT',
  headers:{authorization:'Bearer '+credential,'x-football-subject':A,'content-type':'application/json'},
  body:'x'.repeat(20001)});
 assert.equal((await handleCareerRequest(oversized,env)).status,413);
});
