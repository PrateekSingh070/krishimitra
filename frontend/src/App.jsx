import React, { useState } from 'react';
import { t } from './i18n.js';
import DiseaseScan from './pages/DiseaseScan.jsx';
import Prices from './pages/Prices.jsx';
import Schemes from './pages/Schemes.jsx';
import Alerts from './pages/Alerts.jsx';
import Profile from './pages/Profile.jsx';

const TABS = ['scan', 'prices', 'schemes', 'alerts', 'profile'];

export default function App() {
  const [lang, setLang] = useState('hi');
  const [tab, setTab] = useState('scan');
  const [farmerId, setFarmerId] = useState(1001);

  const ctx = { lang, farmerId };

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
          <label>
            {t('farmer_id', lang)}:&nbsp;
            <input
              type="number"
              min="1"
              value={farmerId}
              onChange={(e) => setFarmerId(Number(e.target.value) || 1)}
              style={{ width: 70 }}
            />
          </label>
          <button className="lang" onClick={() => setLang(lang === 'hi' ? 'en' : 'hi')}>
            {lang === 'hi' ? 'EN' : 'हिं'}
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
