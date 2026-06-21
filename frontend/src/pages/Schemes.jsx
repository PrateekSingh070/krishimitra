import React, { useCallback, useEffect, useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';
import { displayText } from '../text.js';

export default function Schemes({ lang, farmerId }) {
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api
      .get(`/schemes/farmer/${farmerId}`)
      .then((d) => setItems(d.items))
      .catch((e) => setError(e.message));
  }, [farmerId]);

  useEffect(() => {
    load();
  }, [load]);

  async function recompute() {
    setBusy(true);
    try {
      await api.post(`/schemes/farmer/${farmerId}/match`, {});
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card">
      <h2>{t('nav_schemes', lang)}</h2>
      <p className="hint">
        {lang === 'hi'
          ? 'सभी सक्रिय योजनाएँ दिखाई गई हैं। मिलान प्रतिशत आपकी प्रोफ़ाइल के आधार पर है।'
          : 'All active schemes are shown. Match percentage is based on your profile.'}
      </p>
      <button onClick={recompute} disabled={busy}>
        {busy ? t('loading', lang) : t('recompute', lang)}
      </button>
      {error && <p className="error">{error}</p>}
      {!items ? (
        <p>{t('loading', lang)}</p>
      ) : items.length === 0 ? (
        <p>{t('none', lang)}</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>{t('scheme', lang)}</th>
              <th>{t('ministry', lang)}</th>
              <th>{t('benefit', lang)}</th>
              <th>{t('match', lang)}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {items.map((r) => (
              <tr key={r.scheme_id}>
                <td>{lang === 'hi' ? displayText(r.scheme_name_hi, r.scheme_name) : r.scheme_name}</td>
                <td>{r.ministry}</td>
                <td>{Number(r.benefit_amount) ? `₹${Number(r.benefit_amount).toLocaleString('en-IN')}` : '—'}</td>
                <td>{r.match_score != null ? `${r.match_score}%` : '—'}</td>
                <td>
                  {r.apply_url && (
                    <a href={r.apply_url} target="_blank" rel="noreferrer">
                      {t('apply', lang)}
                    </a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
