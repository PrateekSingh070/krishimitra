import React, { useState } from 'react';
import { t } from './i18n.js';
import Login from './pages/Login.jsx';
import Register from './pages/Register.jsx';
import Admin from './pages/Admin.jsx';
import DiseaseScan from './pages/DiseaseScan.jsx';
import Weather from './pages/Weather.jsx';
import Prices from './pages/Prices.jsx';
import Schemes from './pages/Schemes.jsx';
import Alerts from './pages/Alerts.jsx';
import Profile from './pages/Profile.jsx';

// Decode JWT payload to check roles (no verification needed on client).
function getTokenRoles() {
  try {
    const tok = localStorage.getItem('km_token');
    if (!tok) return [];
    const payload = JSON.parse(atob(tok.split('.')[1]));
    return payload.roles || [];
  } catch { return []; }
}

const TABS = ['scan', 'weather', 'prices', 'schemes', 'alerts', 'profile'];

// Restore session from localStorage.
function loadSession() {
  const token = localStorage.getItem('km_token');
  const farmerId = localStorage.getItem('km_farmer_id');
  const name = localStorage.getItem('km_name') || '';
  if (token && farmerId) return { farmerId: Number(farmerId), name };
  return null;
}

export default function App() {
  const [session, setSession] = useState(loadSession);
  const [lang, setLang] = useState(() => localStorage.getItem('km_lang') || 'hi');
  const [tab, setTab] = useState('scan');
  const [showRegister, setShowRegister] = useState(false);

  function handleLogin({ farmerId, name, lang: farmerLang }) {
    const preferredLang = farmerLang || lang;
    setLang(preferredLang);
    localStorage.setItem('km_lang', preferredLang);
    setSession({ farmerId, name });
  }

  function handleLogout() {
    localStorage.removeItem('km_token');
    localStorage.removeItem('km_farmer_id');
    localStorage.removeItem('km_name');
    setSession(null);
    setTab('scan');
  }

  function toggleLang() {
    const next = lang === 'hi' ? 'en' : 'hi';
    setLang(next);
    localStorage.setItem('km_lang', next);
  }

  if (!session) {
    if (showRegister) {
      return <Register lang={lang} onBack={() => setShowRegister(false)} />;
    }
    return <Login lang={lang} onLogin={handleLogin} onRegister={() => setShowRegister(true)} />;
  }

  const ctx = { lang, farmerId: session.farmerId };
  const isAdmin = getTokenRoles().includes('admin');
  const visibleTabs = isAdmin ? [...TABS, 'admin'] : TABS;

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="logo">🌾</span>
          <div>
            <h1>{t('appName', lang)}</h1>
            <small>{t('tagline', lang)}</small>
          </div>
        </div>
        <div className="controls">
          <span className="user-name">
            {lang === 'hi' ? 'नमस्ते,' : 'Hi,'} {session.name}
          </span>
          <button className="lang" onClick={toggleLang}>
            {lang === 'hi' ? 'EN' : 'हिं'}
          </button>
          <button className="lang logout" onClick={handleLogout} title="Logout">
            ⏻
          </button>
        </div>
      </header>

      <nav className="tabs">
        {visibleTabs.map((key) => (
          <button
            key={key}
            className={tab === key ? 'active' : ''}
            onClick={() => setTab(key)}
          >
            {t(`nav_${key}`, lang)}
          </button>
        ))}
      </nav>

      <main className="content">
        {tab === 'scan' && <DiseaseScan {...ctx} />}
        {tab === 'weather' && <Weather {...ctx} />}
        {tab === 'prices' && <Prices {...ctx} />}
        {tab === 'schemes' && <Schemes {...ctx} />}
        {tab === 'alerts' && <Alerts {...ctx} />}
        {tab === 'profile' && <Profile {...ctx} />}
        {tab === 'admin' && <Admin {...ctx} />}
      </main>
    </div>
  );
}
