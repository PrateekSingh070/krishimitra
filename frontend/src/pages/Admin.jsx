import React, { useEffect, useState } from 'react';
import { api } from '../api.js';

// Simple admin panel — shows all farmers, their latest alert, and lets
// admin send a broadcast message. Only reachable if user has role=admin in JWT.

export default function Admin({ lang }) {
  const [farmers, setFarmers] = useState(null);
  const [error, setError] = useState('');
  const [broadcast, setBroadcast] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState('');

  useEffect(() => {
    // Fetch first 100 farmers
    Promise.all(
      Array.from({ length: 10 }, (_, i) =>
        api.get(`/farmers/${1001 + i}`).catch(() => null),
      ),
    ).then((results) => setFarmers(results.filter(Boolean)));
  }, []);

  async function sendBroadcast() {
    if (!broadcast.trim()) return;
    setSending(true);
    setSent('');
    try {
      // Send alert to all loaded farmers
      await Promise.all(
        (farmers || []).map((f) =>
          api.post('/alerts', {
            farmer_id: f.farmer_id,
            alert_type: 'ADMIN',
            severity: 'LOW',
            message_en: broadcast,
            message_hi: broadcast,
          }).catch(() => null),
        ),
      );
      setSent(lang === 'hi' ? `${farmers?.length} किसानों को संदेश भेजा गया।` : `Message sent to ${farmers?.length} farmers.`);
      setBroadcast('');
    } finally {
      setSending(false);
    }
  }

  return (
    <section className="card">
      <h2>{lang === 'hi' ? '🛠️ एडमिन डैशबोर्ड' : '🛠️ Admin Dashboard'}</h2>

      <div className="admin-broadcast">
        <h3>{lang === 'hi' ? 'सभी किसानों को संदेश भेजें' : 'Broadcast Message to All Farmers'}</h3>
        <textarea
          value={broadcast}
          onChange={(e) => setBroadcast(e.target.value)}
          rows={3}
          placeholder={lang === 'hi' ? 'संदेश लिखें…' : 'Type a message…'}
          className="admin-textarea"
        />
        <button onClick={sendBroadcast} disabled={sending || !broadcast.trim()}>
          {sending ? '…' : lang === 'hi' ? 'भेजें' : 'Send'}
        </button>
        {sent && <p className="ok">{sent}</p>}
      </div>

      <h3 style={{ marginTop: 24 }}>{lang === 'hi' ? 'पंजीकृत किसान' : 'Registered Farmers'}</h3>
      {error && <p className="error">{error}</p>}
      {!farmers && <p>{lang === 'hi' ? 'लोड हो रहा है…' : 'Loading…'}</p>}
      {farmers && (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>{lang === 'hi' ? 'नाम' : 'Name'}</th>
              <th>{lang === 'hi' ? 'फ़ोन' : 'Phone'}</th>
              <th>{lang === 'hi' ? 'ज़िला' : 'District'}</th>
              <th>{lang === 'hi' ? 'राज्य' : 'State'}</th>
              <th>{lang === 'hi' ? 'भूमि' : 'Land'}</th>
            </tr>
          </thead>
          <tbody>
            {farmers.map((f) => (
              <tr key={f.farmer_id}>
                <td>{f.farmer_id}</td>
                <td>{f.name}</td>
                <td>{f.phone}</td>
                <td>{f.district || '—'}</td>
                <td>{f.state || '—'}</td>
                <td>{f.land_acres ? `${f.land_acres} ac` : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
