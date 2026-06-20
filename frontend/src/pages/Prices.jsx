import React, { useEffect, useState } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';
import { api } from '../api.js';
import { t } from '../i18n.js';
import { displayText } from '../text.js';

const HINDI_CROP_NAMES = {
  Wheat: 'गेहूँ', Rice: 'चावल', Maize: 'मक्का', Bajra: 'बाजरा',
  Jowar: 'ज्वार', Sugarcane: 'गन्ना', Cotton: 'कपास', Soybean: 'सोयाबीन',
  Groundnut: 'मूँगफली', Mustard: 'सरसों', Gram: 'चना', Lentil: 'मसूर',
  Barley: 'जौ', Potato: 'आलू', Onion: 'प्याज', Tomato: 'टमाटर',
  Watermelon: 'तरबूज', Cucumber: 'खीरा', Moong: 'मूँग', Turmeric: 'हल्दी',
};

function cropName(row, lang) {
  if (lang !== 'hi') return row.crop_name;
  const fallback = HINDI_CROP_NAMES[row.crop_name] || row.crop_name;
  const name = row.crop_name_hindi || fallback;
  return displayText(name, fallback);
}

export default function Prices({ lang }) {
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [selected, setSelected] = useState(null); // { crop_id, crop_name, mandi_name }
  const [history, setHistory] = useState(null);
  const [histLoading, setHistLoading] = useState(false);

  useEffect(() => {
    api.get('/mandi-prices')
      .then((d) => setItems(d.items))
      .catch((e) => setError(e.message));
  }, []);

  async function loadHistory(row) {
    setSelected(row);
    setHistory(null);
    setHistLoading(true);
    try {
      const data = await api.get(
        `/mandi-prices/history?crop_id=${row.crop_id}&mandi=${encodeURIComponent(row.mandi_name)}&days=30`,
      );
      setHistory(data.items.map((h) => ({
        date: String(h.recorded_date).slice(0, 10),
        price: Number(h.price_per_qtl),
      })).reverse());
    } catch {
      setHistory([]);
    } finally {
      setHistLoading(false);
    }
  }

  if (error) return <p className="error">{error}</p>;
  if (!items) return <p>{t('loading', lang)}</p>;
  if (items.length === 0) return <p>{t('none', lang)}</p>;

  return (
    <section className="card">
      <h2>{t('nav_prices', lang)}</h2>

      {selected && (
        <div className="chart-box">
          <div className="chart-title">
            {cropName(selected, lang)} — {selected.mandi_name}
            <button className="btn-link chart-close" onClick={() => setSelected(null)}>✕</button>
          </div>
          {histLoading && <p>{t('loading', lang)}</p>}
          {history && history.length > 1 && (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={history} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e0e7e0" />
                <XAxis
                  dataKey="date"
                  tick={{ fontSize: 10 }}
                  tickFormatter={(v) => v.slice(5)}
                />
                <YAxis
                  tick={{ fontSize: 10 }}
                  tickFormatter={(v) => `₹${v}`}
                  width={52}
                />
                <Tooltip
                  formatter={(v) => [`₹${v.toLocaleString('en-IN')}`, lang === 'hi' ? 'भाव' : 'Price']}
                  labelFormatter={(l) => l}
                />
                <Line
                  type="monotone"
                  dataKey="price"
                  stroke="#2e7d32"
                  strokeWidth={2}
                  dot={false}
                  activeDot={{ r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
          {history && history.length <= 1 && (
            <p className="chart-nodata">
              {lang === 'hi' ? 'पर्याप्त डेटा नहीं है।' : 'Not enough data for chart yet.'}
            </p>
          )}
        </div>
      )}

      <table>
        <thead>
          <tr>
            <th>{t('crop', lang)}</th>
            <th>{t('mandi', lang)}</th>
            <th>{t('price', lang)}</th>
            <th>{t('date', lang)}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {items.map((r) => (
            <tr key={r.price_id}>
              <td>{cropName(r, lang)}</td>
              <td>{r.mandi_name}</td>
              <td>₹{Number(r.price_per_qtl).toLocaleString('en-IN')}</td>
              <td>{String(r.recorded_date).slice(0, 10)}</td>
              <td>
                <button
                  className="chart-btn"
                  onClick={() => loadHistory(r)}
                  title={lang === 'hi' ? 'चार्ट देखें' : 'View chart'}
                >
                  📈
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
