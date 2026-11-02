// Careers are device-local, scoped by the UUID confirmed by the edge session.
import {STORAGE_LOCAL,getStorageItem,setStorageItem,removeStorageItem} from './safeStorage.js';
export const FOOTBALL_STORAGE_KEY='chess-study-football-manager-career-v1';
let subject=null;
export function setFootballIdentity(value){
 if(value!==null&&!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value))throw Error('Invalid verified Football identity');
 subject=value;
}
export const profileStorageIdentityMatchesCurrentUser=()=>Boolean(subject);
export function footballCareerStorageKey(){return subject?FOOTBALL_STORAGE_KEY+':'+subject:null;}
export function getProfileStorageItem(key){
 if(key!==FOOTBALL_STORAGE_KEY)throw Error('Unknown Football storage key');
 const scoped=footballCareerStorageKey();return scoped?getStorageItem(STORAGE_LOCAL,scoped):null;
}
export function setProfileStorageItem(key,value){
 if(key!==FOOTBALL_STORAGE_KEY)throw Error('Unknown Football storage key');
 const scoped=footballCareerStorageKey();if(!scoped)return false;
 if(getStorageItem(STORAGE_LOCAL,scoped)!==String(value))setStorageItem(STORAGE_LOCAL,scoped,String(value));
 return true;
}
export function clearProfileProgress(){const scoped=footballCareerStorageKey();if(!scoped)return false;removeStorageItem(STORAGE_LOCAL,scoped);return true;}
