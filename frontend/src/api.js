// Tiny fetch client for the KrishiMitra API.
const BASE = import.meta.env.VITE_API_BASE || '';
const TOKEN = import.meta.env.VITE_API_TOKEN || '';

function headers(json = true) {
  const h = {};
  if (json) h['Content-Type'] = 'application/json';
  if (TOKEN) h.Authorization = `Bearer ${TOKEN}`;
  return h;
}

async function handle(resp) {
  const text = await resp.text();
  const data = text ? JSON.parse(text) : null;
  if (!resp.ok) {
    const msg = (data && data.error && data.error.message) || resp.statusText;
    throw new Error(msg);
  }
  return data;
}

export const api = {
  get: (path) => fetch(`${BASE}/api/v1${path}`, { headers: headers(false) }).then(handle),
  post: (path, body) =>
    fetch(`${BASE}/api/v1${path}`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(body),
    }).then(handle),
  patch: (path, body) =>
    fetch(`${BASE}/api/v1${path}`, {
      method: 'PATCH',
      headers: headers(),
      body: JSON.stringify(body),
    }).then(handle),
};

// Read a File object as a base64 string (no data: prefix).
export function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(',')[1]);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}
