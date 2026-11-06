import {useState} from 'react';
import {STORAGE_LOCAL,getStorageItem} from '../safeStorage.js';
import {readFootballCareer,replayFootballCareer} from '../footballManagerCareer.js';
export default function FootballSaveTransfer({onImported,savedCareer,cloud=false}){
 const [error,setError]=useState('');
 const localBackup=readFootballCareer();
 const current=savedCareer||localBackup;
 function exportJournal(journal,name){
  const url=URL.createObjectURL(new Blob([JSON.stringify({application:'football-of-matthias',schema:1,career:journal})],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }
 function exportSave(){
  if(current.status!=='available'){setError('No hay una carrera válida para exportar.');return;}
  exportJournal(current.journal,'football-carrera.json');
 }
 function exportPreviousSave(){
  try{
   const raw=getStorageItem(STORAGE_LOCAL,'chess-study-football-manager-career-v1');if(!raw||raw.length>16000)throw Error();
   exportJournal(replayFootballCareer(JSON.parse(raw)).journal,'football-carrera-anterior.json');
  }catch{setError('No hay una carrera anterior válida para exportar. El guardado se conserva.');}
 }
 async function importJournal(journal){
  if(!['empty','available','invalid'].includes(current.status)){
   setError('Tu carrera no está disponible para importar. No se ha modificado nada.');return;
  }
  if(current.status!=='empty'&&!window.confirm(cloud?'¿Sustituir la carrera guardada en Mongo? Exporta antes una copia.':'¿Sustituir la carrera guardada en este navegador? Exporta antes una copia.'))return;
  try{
   const result=await onImported(replayFootballCareer(journal).journal);
   if(!['saved','memory','cloud'].includes(result?.status))throw Error();
   setError('');
  }catch{setError('No se ha importado: el guardado se conserva.');}
 }
 async function importSave(event){
  const file=event.target.files?.[0];event.target.value='';if(!file)return;
  try{
   if(file.size>131072)throw Error();
   const value=JSON.parse(await file.text());
   const journal=replayFootballCareer(value.application==='football-of-matthias'&&value.schema===1?value.career:value).journal;
   await importJournal(journal);
  }catch{setError('No se ha importado: el archivo no contiene una carrera válida. Tu guardado se conserva.');}
 }
 return <details className="football-transfer"><summary>Tu carrera · copias e importación</summary>
  <p>{cloud?'La carrera activa se guarda en Mongo con tu ShadowOps ID. Los datos anteriores de este navegador no se transfieren sin tu permiso.':'La carrera se guarda en este navegador. Puedes traer la copia de Football que exportaste desde Chess Studio.'}</p>
  <button type="button" onClick={exportSave}>Exportar carrera</button>
  {cloud&&localBackup.status==='available'?
    <button type="button" onClick={()=>void importJournal(localBackup.journal)}>Importar copia de este navegador a Mongo</button>:null}
  <button type="button" onClick={exportPreviousSave}>Exportar carrera anterior a ShadowOps ID</button>
  <label>Importar carrera<input aria-label="Importar carrera" type="file" accept="application/json,.json" onChange={importSave}/></label>
  {error&&<p role="alert">{error}</p>}
 </details>;
}
