import React, { useState } from 'react';
import { api, fileToBase64 } from '../api.js';
import { t } from '../i18n.js';
import { displayText } from '../text.js';

export default function DiseaseScan({ lang, farmerId }) {
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [result, setResult] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  function onPick(e) {
    const f = e.target.files[0];
    setFile(f || null);
    setResult(null);
    setError(null);
    setPreview(f ? URL.createObjectURL(f) : null);
  }

  async function analyze() {
    if (!file) return;
    setBusy(true);
    setError(null);
    try {
      const image_base64 = await fileToBase64(file);
      const scan = await api.post('/disease-scans/classify', {
        farmer_id: farmerId,
        image_base64,
        content_type: file.type || 'image/jpeg',
      });
      setResult(scan);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card">
      <h2>{t('scan_title', lang)}</h2>
      <input type="file" accept="image/*" onChange={onPick} />
      {preview && <img className="preview" src={preview} alt="leaf" />}
      <button disabled={!file || busy} onClick={analyze}>
        {busy ? t('loading', lang) : t('scan_run', lang)}
      </button>

      {error && <p className="error">{error}</p>}

      {result && (
        <div className="result">
          <h3>{t('scan_result', lang)}</h3>
          <p>
            <strong>{t('disease', lang)}:</strong> {result.disease_detected}
          </p>
          <p>
            <strong>{t('severity', lang)}:</strong>{' '}
            <span className={`sev sev-${result.severity}`}>{result.severity}</span>
          </p>
          <p>
            <strong>{t('confidence', lang)}:</strong> {result.confidence_score}%
          </p>
          <p>
            <strong>{t('treatment', lang)}:</strong>{' '}
            {lang === 'hi' ? displayText(result.treatment_hindi, result.treatment_advice) : result.treatment_advice}
          </p>
        </div>
      )}
    </section>
  );
}
