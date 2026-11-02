import {lazy,Suspense,useEffect,useState} from 'react';
import {currentFootballSession,renewFootballSession,closeFootballSession,requireFootballLogin} from '../footballIdentity.js';
import {setFootballIdentity} from '../profileKeys.js';
const Game=lazy(()=>import('./ChessFootballEntry.jsx'));
export default function FootballIdentityApp(){
 const [player,setPlayer]=useState(null),[error,setError]=useState('');
 useEffect(()=>{
  let live=true,pending=false;setFootballIdentity(null);
  const adopt=value=>{if(live){setFootballIdentity(value.subject);setPlayer(value.subject);}};
  const deny=()=>{if(live){setFootballIdentity(null);setPlayer(null);void requireFootballLogin();}};
  currentFootballSession().then(adopt,deny);
  const check=async()=>{if(pending||document.hidden)return;pending=true;try{adopt(await renewFootballSession());}catch{deny();}finally{pending=false;}};
  const interval=setInterval(check,45000);window.addEventListener('focus',check);document.addEventListener('visibilitychange',check);
  return()=>{live=false;clearInterval(interval);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check);setFootballIdentity(null);};
 },[]);
 async function logout(){try{await closeFootballSession();setFootballIdentity(null);setPlayer(null);location.replace('/');}catch{setError('No se ha podido cerrar la sesión. Vuelve a intentarlo.');}}
 if(!player)return <main className="football-session-loading" role="status">Comprobando ShadowOps ID…</main>;
 return <><div className="football-identity-actions"><button type="button" onClick={logout}>Salir de ShadowOps ID</button>{error&&<p role="alert">{error}</p>}</div><Suspense fallback={<p role="status">Abriendo Football…</p>}><Game key={player} onExit={()=>location.assign('https://staging.shadowops.dpdns.org/')}/></Suspense></>;
}
