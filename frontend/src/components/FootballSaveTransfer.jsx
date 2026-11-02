import {useState} from 'react';
import {readFootballCareer,replayFootballCareer,writeFootballCareer} from '../footballManagerCareer.js';
export default function FootballSaveTransfer({onImported}){
 const [error,setError]=useState('');
 function exportSave(){
  const saved=readFootballCareer();if(saved.status!=='available'){setError('No hay una carrera válida para exportar.');return;}
  const url=URL.createObjectURL(new Blob([JSON.stringify({application:'football-of-matthias',schema:1,career:saved.journal})],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='football-carrera.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }
 async function importSave(event){
  const file=event.target.files?.[0];event.target.value='';if(!file)return;
  try{
   if(file.size>131072)throw Error();
   const value=JSON.parse(await file.text());
   const journal=replayFootballCareer(value.application==='football-of-matthias'&&value.schema===1?value.career:value).journal;
   const existing=readFootballCareer();
   if(existing.status==='future'){setError('Actualiza el juego antes de sustituir una carrera de una versión más nueva.');return;}
   if(existing.status!=='empty'&&!window.confirm('¿Sustituir la carrera guardada en este navegador? Exporta antes tu copia si quieres conservarla.'))return;
   const result=writeFootballCareer(journal);if(!['saved','memory'].includes(result.status))throw Error();
   setError('');onImported();
  }catch{setError('No se ha importado: el archivo no contiene una carrera válida. Tu guardado se conserva.');}
 }
 return <details className="football-transfer"><summary>Tu carrera · copias e importación</summary><p>La carrera se guarda en este navegador. Puedes traer la copia de Football que exportaste desde Chess Studio.</p><button type="button" onClick={exportSave}>Exportar carrera</button><label>Importar carrera<input aria-label="Importar carrera" type="file" accept="application/json,.json" onChange={importSave}/></label>{error&&<p role="alert">{error}</p>}</details>;
}
