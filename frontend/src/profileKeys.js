// One career authority at the dedicated origin. No Chess account/profile copy.
import {STORAGE_LOCAL,getStorageItem,setStorageItem,removeStorageItem} from './safeStorage.js';
export const FOOTBALL_STORAGE_KEY='chess-study-football-manager-career-v1';
export const profileStorageIdentityMatchesCurrentUser=()=>true;
export function setProfileStorageItem(key,value){
 if(key!==FOOTBALL_STORAGE_KEY)throw Error('Unknown Football storage key');
 if(getStorageItem(STORAGE_LOCAL,key)!==String(value))setStorageItem(STORAGE_LOCAL,key,String(value));
 return true;
}
export function clearProfileProgress(){removeStorageItem(STORAGE_LOCAL,FOOTBALL_STORAGE_KEY);return true;}
