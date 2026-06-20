const MOJIBAKE_RE = /[\u00c0-\u00ff]/;
const DEVANAGARI_RE = /[\u0900-\u097f]/;

export function fixMojibake(value) {
  if (typeof value !== 'string' || !MOJIBAKE_RE.test(value)) return value;

  const bytes = Uint8Array.from(Array.from(value, (char) => char.charCodeAt(0) & 0xff));
  const decoded = new TextDecoder('utf-8').decode(bytes);

  return DEVANAGARI_RE.test(decoded) ? decoded : value;
}

export function displayText(value, fallback = '') {
  return fixMojibake(value || fallback);
}
