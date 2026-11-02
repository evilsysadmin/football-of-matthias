import React from 'react';
import { createRoot } from 'react-dom/client';
import FootballIdentityApp from './components/FootballIdentityApp.jsx';
import './standalone.css';
createRoot(document.getElementById('root')).render(<React.StrictMode><FootballIdentityApp/></React.StrictMode>);
