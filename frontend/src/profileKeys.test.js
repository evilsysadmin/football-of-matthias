import {beforeEach,describe,it,expect} from 'vitest';
import {setFootballIdentity,footballCareerStorageKey,clearProfileProgress} from './profileKeys.js';
import {createFootballCareer,writeFootballCareer,readFootballCareer} from './footballManagerCareer.js';
import {clearStorageMemoryFallback} from './safeStorage.js';
const A='11111111-1111-4111-8111-111111111111',B='22222222-2222-4222-8222-222222222222';
describe('verified account career isolation',()=>{
 beforeEach(()=>{localStorage.clear();clearStorageMemoryFallback();});
 it('does not write or restore a career without a server-confirmed subject',()=>{
  setFootballIdentity(null);expect(footballCareerStorageKey()).toBeNull();
  expect(writeFootballCareer(createFootballCareer('fc-matthias'))).toEqual({status:'unavailable'});
  expect(readFootballCareer()).toEqual({status:'unavailable'});
 });
 it('separates two accounts and preserves the unclaimed pre-Identity journal',()=>{
  localStorage.setItem('chess-study-football-manager-career-v1','unclaimed');
  setFootballIdentity(A);writeFootballCareer(createFootballCareer('fc-matthias',17));
  setFootballIdentity(B);expect(readFootballCareer().status).toBe('empty');writeFootballCareer(createFootballCareer('fc-matthias',29));
  setFootballIdentity(A);expect(readFootballCareer().journal.seed).toBe(17);clearProfileProgress();
  setFootballIdentity(B);expect(readFootballCareer().journal.seed).toBe(29);
  expect(localStorage.getItem('chess-study-football-manager-career-v1')).toBe('unclaimed');
 });
 it('rejects aliases and malformed subjects',()=>{expect(()=>setFootballIdentity('admin')).toThrow();});
});
