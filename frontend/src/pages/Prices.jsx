import React, { useEffect, useState } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

const HINDI_CROP_NAMES = {
  Wheat: 'गेहूँ',
  Rice: 'चावल',
  Maize: 'मक्का',
  Bajra: 'बाजरा',
  Jowar: 'ज्वार',
  Sugarcane: 'गन्ना',
  Cotton: 'कपास',
  Soybean: 'सोयाबीन',
  Groundnut: 'मूँगफली',
  Mustard: 'सरसों',
  Gram: 'चना',
  Lentil: 'मसूर',
  Barley: 'जौ',
  Potato: 'आलू',
  Onion: 'प्याज',
  Tomato: 'टमाटर',
  Watermelon: 'तरबूज',
  Cucumber: 'खीरा',
  Moong: 'मूँग',
  Turmeric: 'हल्दी',
};

function cropName(row, lang) {
  if (lang !== 'hi') return row.crop_name;
  const fallback = HINDI_CROP_NAMES[row.crop_name] || row.crop_name;
  const name = row.crop_name_hindi || fallback;
  return name.includes('à') ? fallback : name;
}

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
              <td>{cropName(r, lang)}</td>
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
