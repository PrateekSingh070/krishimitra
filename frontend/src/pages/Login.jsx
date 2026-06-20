import React, { useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

export default function Login({ lang, onLogin, onRegister }) {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState('phone'); // 'phone' | 'otp'
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  async function handleRequestOtp(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.requestOtp(phone.trim());
      setInfo(res.message || 'OTP sent!');
      setStep('otp');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyOtp(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.verifyOtp(phone.trim(), otp.trim());
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

        {step === 'phone' ? (
          <form onSubmit={handleRequestOtp} className="login-form">
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
            {error && <p className="login-error">{error}</p>}
            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? '…' : lang === 'hi' ? 'OTP भेजें' : 'Send OTP'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp} className="login-form">
            {info && <p className="login-info">{info}</p>}
            <label>{lang === 'hi' ? '6-अंकीय OTP दर्ज करें' : 'Enter 6-digit OTP'}</label>
            <input
              type="text"
              inputMode="numeric"
              placeholder="_ _ _ _ _ _"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              maxLength={6}
              required
              autoFocus
            />
            {error && <p className="login-error">{error}</p>}
            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? '…' : lang === 'hi' ? 'लॉग इन करें' : 'Log In'}
            </button>
            <button
              type="button"
              className="btn-link"
              onClick={() => { setStep('phone'); setOtp(''); setError(''); }}
            >
              {lang === 'hi' ? '← नंबर बदलें' : '← Change number'}
            </button>
          </form>
        )}

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
