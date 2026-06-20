import React, { useEffect, useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

export default function Prices({ lang }) {
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    api
      .get('/mandi-prices')
      .then((d) => setItems(d.items))
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="error">{error}</p>;
  if (!items) return <p>{t('loading', lang)}</p>;
  if (items.length === 0) return <p>{t('none', lang)}</p>;

  return (
    <section className="card">
      <h2>{t('nav_prices', lang)}</h2>
      <table>
        <thead>
          <tr>
            <th>{t('crop', lang)}</th>
            <th>{t('mandi', lang)}</th>
            <th>{t('price', lang)}</th>
            <th>{t('date', lang)}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r) => (
            <tr key={r.price_id}>
              <td>{lang === 'hi' ? r.crop_name_hindi || r.crop_name : r.crop_name}</td>
              <td>{r.mandi_name}</td>
              <td>₹{Number(r.price_per_qtl).toLocaleString('en-IN')}</td>
              <td>{String(r.recorded_date).slice(0, 10)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
