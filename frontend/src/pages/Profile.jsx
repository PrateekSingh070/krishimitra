import React, { useEffect, useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

const FIELDS = ['name', 'email', 'state', 'district', 'land_acres'];

export default function Profile({ lang, farmerId }) {
  const [form, setForm] = useState(null);
  const [error, setError] = useState(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setForm(null);
    setSaved(false);
    api
      .get(`/farmers/${farmerId}`)
      .then((d) => setForm(d))
      .catch((e) => setError(e.message));
  }, [farmerId]);

  function update(k, v) {
    setForm((f) => ({ ...f, [k]: v }));
    setSaved(false);
  }

  async function save() {
    setBusy(true);
    setError(null);
    try {
      const body = {
        name: form.name,
        email: form.email || undefined,
        state: form.state || undefined,
        district: form.district || undefined,
        land_acres: form.land_acres != null ? Number(form.land_acres) : undefined,
      };
      await api.patch(`/farmers/${farmerId}`, body);
      setSaved(true);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  if (error) return <p className="error">{error}</p>;
  if (!form) return <p>{t('loading', lang)}</p>;

  return (
    <section className="card">
      <h2>{t('nav_profile', lang)}</h2>
      <div className="form">
        <label>
          {t('phone', lang)}
          <input value={form.phone || ''} disabled />
        </label>
        {FIELDS.map((k) => (
          <label key={k}>
            {t(k, lang)}
            <input value={form[k] ?? ''} onChange={(e) => update(k, e.target.value)} />
          </label>
        ))}
      </div>
      <button onClick={save} disabled={busy}>
        {busy ? t('loading', lang) : t('save', lang)}
      </button>
      {saved && <span className="ok"> ✓</span>}
    </section>
  );
}
