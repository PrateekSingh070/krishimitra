import React, { useEffect, useMemo, useState } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';
import { api } from '../api.js';
import { t } from '../i18n.js';
import { displayText } from '../text.js';
import { cropDisplayName, isVegetable } from '../cropCatalog.js';

const FILTERS = [
  { key: 'all', en: 'All', hi: 'सभी' },
  { key: 'vegetable', en: 'Vegetables', hi: 'सब्ज़ियाँ' },
  { key: 'cereal', en: 'Cereals', hi: 'अनाज' },
  { key: 'pulse', en: 'Pulses', hi: 'दालें' },
  { key: 'fruit', en: 'Fruits', hi: 'फल' },
];

function matchesFilter(row, filter) {
  if (filter === 'all') return true;
  const type = row.crop_type?.toLowerCase();
  if (filter === 'vegetable') return type === 'vegetable' || isVegetable(row);
  if (filter === 'cereal') return type === 'cereal';
  if (filter === 'pulse') return type === 'pulse';
  if (filter === 'fruit') return type === 'fruit';
  return true;
}

export default function Prices({ lang }) {
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('vegetable');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState(null);
  const [history, setHistory] = useState(null);
  const [histLoading, setHistLoading] = useState(false);

  useEffect(() => {
    api.get('/mandi-prices')
      .then((d) => setItems(d.items))
      .catch((e) => setError(e.message));
  }, []);

  const visible = useMemo(() => {
    if (!items) return [];
    const q = search.trim().toLowerCase();
    return items.filter((row) => {
      if (!matchesFilter(row, filter)) return false;
      if (!q) return true;
      const hi = cropDisplayName(row, 'hi').toLowerCase();
      return row.crop_name.toLowerCase().includes(q)
        || hi.includes(q)
        || row.mandi_name.toLowerCase().includes(q);
    });
  }, [items, filter, search]);

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

  const vegCount = items.filter((r) => isVegetable(r) || r.crop_type === 'Vegetable').length;

  return (
    <section className="card">
      <h2>{t('nav_prices', lang)}</h2>
      <p className="hint">
        {lang === 'hi'
          ? `${vegCount} सब्ज़ियों के मंडी भाव उपलब्ध हैं। नीचे फ़िल्टर और खोज का उपयोग करें।`
          : `${vegCount} vegetable price entries available. Use filter and search below.`}
      </p>

      <div className="price-toolbar">
        <div className="filter-row">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              type="button"
              className={filter === f.key ? 'filter-btn active' : 'filter-btn'}
              onClick={() => setFilter(f.key)}
            >
              {lang === 'hi' ? f.hi : f.en}
            </button>
          ))}
        </div>
        <input
          className="search-input"
          type="search"
          placeholder={lang === 'hi' ? 'सब्ज़ी या मंडी खोजें…' : 'Search vegetable or mandi…'}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {selected && (
        <div className="chart-box">
          <div className="chart-title">
            {displayText(cropDisplayName(selected, lang), selected.crop_name)} — {selected.mandi_name}
            <button className="btn-link chart-close" type="button" onClick={() => setSelected(null)}>✕</button>
          </div>
          {histLoading && <p>{t('loading', lang)}</p>}
          {history && history.length > 1 && (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={history} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e0e7e0" />
                <XAxis dataKey="date" tick={{ fontSize: 10 }} tickFormatter={(v) => v.slice(5)} />
                <YAxis tick={{ fontSize: 10 }} tickFormatter={(v) => `₹${v}`} width={52} />
                <Tooltip
                  formatter={(v) => [`₹${v.toLocaleString('en-IN')}`, lang === 'hi' ? 'भाव' : 'Price']}
                  labelFormatter={(l) => l}
                />
                <Line type="monotone" dataKey="price" stroke="#2e7d32" strokeWidth={2} dot={false} activeDot={{ r: 4 }} />
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

      {visible.length === 0 ? (
        <p>{t('none', lang)}</p>
      ) : (
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
            {visible.map((r) => (
              <tr key={r.price_id}>
                <td>{displayText(cropDisplayName(r, lang), r.crop_name)}</td>
                <td>{r.mandi_name}</td>
                <td>₹{Number(r.price_per_qtl).toLocaleString('en-IN')}</td>
                <td>{String(r.recorded_date).slice(0, 10)}</td>
                <td>
                  <button
                    className="chart-btn"
                    type="button"
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
      )}
    </section>
  );
}
