import React, { useEffect, useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

export default function Alerts({ lang, farmerId }) {
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    setItems(null);
    api
      .get(`/alerts?farmer_id=${farmerId}`)
      .then((d) => setItems(d.items))
      .catch((e) => setError(e.message));
  }, [farmerId]);

  if (error) return <p className="error">{error}</p>;
  if (!items) return <p>{t('loading', lang)}</p>;
  if (items.length === 0) return <p>{t('none', lang)}</p>;

  return (
    <section className="card">
      <h2>{t('nav_alerts', lang)}</h2>
      <ul className="alerts">
        {items.map((a) => (
          <li key={a.alert_id} className={`sev-border sev-${a.severity}`}>
            <div className="alert-head">
              <span className={`sev sev-${a.severity}`}>{a.severity}</span>
              <span className="alert-type">{a.alert_type}</span>
              <span className="alert-date">{String(a.created_at).slice(0, 10)}</span>
            </div>
            <p>{lang === 'hi' ? a.message_hi || a.message_en : a.message_en}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}
