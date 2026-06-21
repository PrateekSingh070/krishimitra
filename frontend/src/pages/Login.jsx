import React, { useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

export default function Login({ lang, onLogin, onRegister }) {
  const [phone, setPhone] = useState('');
  const [pin, setPin] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleLogin(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.login(phone.trim(), pin.trim());
      localStorage.setItem('km_token', res.token);
      localStorage.setItem('km_farmer_id', String(res.farmer_id));
      localStorage.setItem('km_name', res.name || '');
      onLogin({ farmerId: res.farmer_id, name: res.name, lang: res.lang || lang });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="login-header">
          <span className="login-logo">🌾</span>
          <h2>{t('appName', lang)}</h2>
          <p className="login-sub">{t('tagline', lang)}</p>
        </div>

        <form onSubmit={handleLogin} className="login-form">
          <label>{lang === 'hi' ? 'मोबाइल नंबर' : 'Mobile Number'}</label>
          <input
            type="tel"
            placeholder="10-digit mobile number"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            maxLength={15}
            required
            autoFocus
          />

          <label>{lang === 'hi' ? 'PIN' : 'PIN'}</label>
          <input
            type="password"
            inputMode="numeric"
            placeholder={lang === 'hi' ? '4-6 अंकों का PIN' : '4-6 digit PIN'}
            value={pin}
            onChange={(e) => setPin(e.target.value)}
            minLength={4}
            maxLength={6}
            required
          />

          {error && <p className="login-error">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? '…' : lang === 'hi' ? 'लॉग इन करें' : 'Log In'}
          </button>
        </form>

        <p className="login-hint">
          {lang === 'hi' ? 'नए किसान?' : 'New farmer?'}{' '}
          <button className="btn-link" style={{ display: 'inline', padding: 0 }} onClick={onRegister}>
            {lang === 'hi' ? 'यहाँ पंजीकरण करें' : 'Register here'}
          </button>
        </p>
      </div>
    </div>
  );
}
