import React, { useState, useEffect } from 'react';
import { api } from '../api.js';
import { t } from '../i18n.js';

// WMO weather code → emoji + label
const WMO = {
  0: { icon: '☀️', en: 'Clear sky', hi: 'साफ आकाश' },
  1: { icon: '🌤️', en: 'Mainly clear', hi: 'ज़्यादातर साफ' },
  2: { icon: '⛅', en: 'Partly cloudy', hi: 'आंशिक बादल' },
  3: { icon: '☁️', en: 'Overcast', hi: 'बादल छाए' },
  45: { icon: '🌫️', en: 'Fog', hi: 'कोहरा' },
  48: { icon: '🌫️', en: 'Icy fog', hi: 'बर्फीला कोहरा' },
  51: { icon: '🌦️', en: 'Light drizzle', hi: 'हल्की बूंदाबांदी' },
  53: { icon: '🌦️', en: 'Drizzle', hi: 'बूंदाबांदी' },
  55: { icon: '🌧️', en: 'Heavy drizzle', hi: 'तेज़ बूंदाबांदी' },
  61: { icon: '🌧️', en: 'Slight rain', hi: 'हल्की बारिश' },
  63: { icon: '🌧️', en: 'Moderate rain', hi: 'मध्यम बारिश' },
  65: { icon: '🌧️', en: 'Heavy rain', hi: 'तेज़ बारिश' },
  71: { icon: '❄️', en: 'Slight snow', hi: 'हल्की बर्फ' },
  80: { icon: '🌦️', en: 'Rain showers', hi: 'बारिश की फुहार' },
  95: { icon: '⛈️', en: 'Thunderstorm', hi: 'आंधी-तूफान' },
  99: { icon: '⛈️', en: 'Heavy thunderstorm', hi: 'भारी तूफान' },
};

function wmo(code, lang) {
  const w = WMO[code] || { icon: '🌡️', en: 'Unknown', hi: 'अज्ञात' };
  return { icon: w.icon, label: lang === 'hi' ? w.hi : w.en };
}

const DAYS_HI = ['रवि', 'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि'];
const DAYS_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function dayLabel(dateStr, lang) {
  const d = new Date(dateStr);
  return lang === 'hi' ? DAYS_HI[d.getDay()] : DAYS_EN[d.getDay()];
}

export default function Weather({ lang, farmerId }) {
  const [profile, setProfile] = useState(null);
  const [weather, setWeather] = useState(null);
  const [district, setDistrict] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Load farmer profile to get district
  useEffect(() => {
    if (!farmerId) return;
    api.get(`/farmers/${farmerId}`).then((f) => {
      setProfile(f);
      const location = f.district || f.village;
      if (location) {
        setDistrict(location);
        fetchWeather(location, f.state, f.village);
      }
    }).catch(() => {});
  }, [farmerId]); // eslint-disable-line react-hooks/exhaustive-deps

  async function fetchWeather(d, stateOverride = null, fallbackLocation = null) {
    const trimmed = String(d || '').trim();
    if (!trimmed) return;
    setLoading(true);
    setError('');
    setWeather(null);
    try {
      const data = await api.get(`/weather?district=${encodeURIComponent(trimmed)}&state=${encodeURIComponent(stateOverride ?? profile?.state ?? '')}`);
      setWeather(data);
    } catch (err) {
      const fallback = String(fallbackLocation || '').trim();
      if (err.status === 404 && fallback && fallback.toLowerCase() !== trimmed.toLowerCase()) {
        try {
          const data = await api.get(`/weather?district=${encodeURIComponent(fallback)}&state=${encodeURIComponent(stateOverride ?? profile?.state ?? '')}`);
          setDistrict(fallback);
          setWeather(data);
          return;
        } catch {
          // Show the original error; it better describes the first location tried.
        }
      }
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const daily = weather?.daily;
  const weatherCodes = daily?.weathercode || daily?.weather_code || [];

  return (
    <div className="card">
      <h2>{lang === 'hi' ? '🌤️ मौसम पूर्वानुमान' : '🌤️ Weather Forecast'}</h2>

      <div className="weather-search">
        <input
          value={district}
          onChange={(e) => setDistrict(e.target.value)}
          placeholder={lang === 'hi' ? 'ज़िला दर्ज करें' : 'Enter district name'}
          onKeyDown={(e) => e.key === 'Enter' && fetchWeather(district)}
        />
        <button onClick={() => fetchWeather(district)} disabled={loading || !district}>
          {loading ? '…' : lang === 'hi' ? 'खोजें' : 'Search'}
        </button>
      </div>

      {error && <p className="error">{error}</p>}

      {weather && (
        <>
          <div className="weather-now">
            <div className="weather-now-main">
              <span className="weather-big-icon">
                {weatherCodes.length ? wmo(weatherCodes[0], lang).icon : '🌡️'}
              </span>
              <div>
                <div className="weather-temp">{weather.current.temp_celsius?.toFixed(1)}°C</div>
                <div className="weather-place">{weather.district}{weather.state ? `, ${weather.state}` : ''}</div>
                <div className="weather-cond">
                  {weatherCodes.length ? wmo(weatherCodes[0], lang).label : ''}
                </div>
              </div>
            </div>
            <div className="weather-now-meta">
              <span>💧 {weather.current.humidity_pct?.toFixed(0)}%</span>
              <span>🌧️ {weather.current.rainfall_mm?.toFixed(1)} mm</span>
              <span>💨 {weather.current.wind_speed_kmh?.toFixed(1)} km/h</span>
            </div>
          </div>

          {daily && (
            <div className="forecast-grid">
              {daily.time?.map((date, i) => {
                const { icon } = wmo(weatherCodes[i] ?? 0, lang);
                return (
                  <div key={date} className="forecast-day">
                    <div className="fc-day">{dayLabel(date, lang)}</div>
                    <div className="fc-icon">{icon}</div>
                    <div className="fc-temp">
                      <span className="fc-max">{daily.temperature_2m_max?.[i]?.toFixed(0)}°</span>
                      <span className="fc-min">{daily.temperature_2m_min?.[i]?.toFixed(0)}°</span>
                    </div>
                    <div className="fc-rain">🌧 {daily.precipitation_sum?.[i]?.toFixed(1)}mm</div>
                  </div>
                );
              })}
            </div>
          )}

          <p className="weather-source">
            {lang === 'hi'
              ? `स्रोत: Open-Meteo · अपडेट: ${new Date(weather.recorded_at).toLocaleString('hi-IN')}`
              : `Source: Open-Meteo · Updated: ${new Date(weather.recorded_at).toLocaleTimeString()}`}
          </p>
        </>
      )}
    </div>
  );
}
