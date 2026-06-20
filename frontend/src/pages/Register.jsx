import React, { useState } from 'react';
import { t } from '../i18n.js';

const BASE = import.meta.env.VITE_API_BASE || '';

const SOIL_TYPES = ['Sandy', 'Loamy', 'Clay', 'Black', 'Silt', 'Peaty', 'Chalky'];
const SOIL_HINDI = {
  Sandy: 'बलुई', Loamy: 'दोमट', Clay: 'चिकनी', Black: 'काली',
  Silt: 'सिल्ट', Peaty: 'पीट', Chalky: 'चाक',
};

export default function Register({ lang, onBack }) {
  const [form, setForm] = useState({
    name: '', phone: '', email: '', state: '', district: '',
    village: '', land_acres: '', soil_type: '', preferred_lang: lang,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  function set(k, v) { setForm((f) => ({ ...f, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const body = { ...form };
      if (body.land_acres) body.land_acres = Number(body.land_acres);
      else delete body.land_acres;
      if (!body.email) delete body.email;
      if (!body.soil_type) delete body.soil_type;

      const resp = await fetch(`${BASE}/api/v1/farmers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await resp.json();
      if (!resp.ok) throw new Error(data?.error?.message || 'Registration failed');
      setDone(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  if (done) {
    return (
      <div className="login-wrap">
        <div className="login-card">
          <div className="login-header">
            <span className="login-logo">✅</span>
            <h2>{lang === 'hi' ? 'पंजीकरण सफल!' : 'Registration Successful!'}</h2>
            <p className="login-sub">
              {lang === 'hi'
                ? 'आपका पंजीकरण हो गया है। अब आप अपने मोबाइल नंबर से लॉग इन कर सकते हैं।'
                : 'You are registered. You can now log in with your mobile number.'}
            </p>
          </div>
          <button className="btn-primary" onClick={onBack}>
            {lang === 'hi' ? 'लॉग इन करें →' : 'Go to Login →'}
          </button>
        </div>
      </div>
    );
  }

  const F = ({ label, labelHi, children }) => (
    <div className="reg-field">
      <label>{lang === 'hi' ? labelHi : label}</label>
      {children}
    </div>
  );

  return (
    <div className="login-wrap" style={{ alignItems: 'flex-start', paddingTop: 32 }}>
      <div className="login-card" style={{ maxWidth: 480 }}>
        <div className="login-header">
          <span className="login-logo">🌾</span>
          <h2>{lang === 'hi' ? 'नया पंजीकरण' : 'New Registration'}</h2>
          <p className="login-sub">
            {lang === 'hi' ? 'KrishiMitra पर किसान के रूप में पंजीकरण करें' : 'Register as a farmer on KrishiMitra'}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="reg-form">
          <F label="Full Name *" labelHi="पूरा नाम *">
            <input value={form.name} onChange={e => set('name', e.target.value)} required />
          </F>
          <F label="Mobile Number *" labelHi="मोबाइल नंबर *">
            <input type="tel" value={form.phone} onChange={e => set('phone', e.target.value)}
              placeholder="10-digit number" maxLength={15} required />
          </F>
          <F label="State" labelHi="राज्य">
            <input value={form.state} onChange={e => set('state', e.target.value)} placeholder="e.g. Maharashtra" />
          </F>
          <F label="District" labelHi="ज़िला">
            <input value={form.district} onChange={e => set('district', e.target.value)} placeholder="e.g. Pune" />
          </F>
          <F label="Village" labelHi="गाँव">
            <input value={form.village} onChange={e => set('village', e.target.value)} />
          </F>
          <F label="Land (acres)" labelHi="भूमि (एकड़)">
            <input type="number" min="0" step="0.1" value={form.land_acres}
              onChange={e => set('land_acres', e.target.value)} />
          </F>
          <F label="Soil Type" labelHi="मिट्टी का प्रकार">
            <select value={form.soil_type} onChange={e => set('soil_type', e.target.value)}>
              <option value="">{lang === 'hi' ? '— चुनें —' : '— Select —'}</option>
              {SOIL_TYPES.map(s => (
                <option key={s} value={s}>{lang === 'hi' ? SOIL_HINDI[s] : s}</option>
              ))}
            </select>
          </F>
          <F label="Email (optional)" labelHi="ईमेल (वैकल्पिक)">
            <input type="email" value={form.email} onChange={e => set('email', e.target.value)} />
          </F>
          <F label="Preferred Language" labelHi="पसंदीदा भाषा">
            <select value={form.preferred_lang} onChange={e => set('preferred_lang', e.target.value)}>
              <option value="hi">हिंदी</option>
              <option value="en">English</option>
            </select>
          </F>

          {error && <p className="login-error">{error}</p>}

          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? '…' : lang === 'hi' ? 'पंजीकरण करें' : 'Register'}
          </button>
          <button type="button" className="btn-link" onClick={onBack}>
            {lang === 'hi' ? '← वापस लॉग इन पर' : '← Back to Login'}
          </button>
        </form>
      </div>
    </div>
  );
}
