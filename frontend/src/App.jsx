import React, { useState } from 'react';
import { t } from './i18n.js';
import Login from './pages/Login.jsx';
import DiseaseScan from './pages/DiseaseScan.jsx';
import Prices from './pages/Prices.jsx';
import Schemes from './pages/Schemes.jsx';
import Alerts from './pages/Alerts.jsx';
import Profile from './pages/Profile.jsx';

const TABS = ['scan', 'prices', 'schemes', 'alerts', 'profile'];

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
    return <Login lang={lang} onLogin={handleLogin} />;
  }

  const ctx = { lang, farmerId: session.farmerId };

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
        {TABS.map((key) => (
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
        {tab === 'prices' && <Prices {...ctx} />}
        {tab === 'schemes' && <Schemes {...ctx} />}
        {tab === 'alerts' && <Alerts {...ctx} />}
        {tab === 'profile' && <Profile {...ctx} />}
      </main>
    </div>
  );
}
