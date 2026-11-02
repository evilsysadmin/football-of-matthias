import React from 'react';
import { createRoot } from 'react-dom/client';
import ChessFootballEntry from './components/ChessFootballEntry.jsx';
import './standalone.css';
createRoot(document.getElementById('root')).render(<React.StrictMode><ChessFootballEntry onExit={()=>location.assign('https://staging.shadowops.dpdns.org/')}/></React.StrictMode>);
