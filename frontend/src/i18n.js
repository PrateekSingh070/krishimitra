// Minimal bilingual string table (Hindi / English), mirroring apex/static.
export const STRINGS = {
  appName: { en: 'KrishiMitra', hi: 'कृषिमित्र' },
  tagline: { en: 'Farmer Advisory & Crop Intelligence', hi: 'किसान सलाह एवं फसल बुद्धिमत्ता' },
  nav_scan: { en: 'Disease Scan', hi: 'रोग जाँच' },
  nav_weather: { en: 'Weather', hi: 'मौसम' },
  nav_prices: { en: 'Market Prices', hi: 'मंडी भाव' },
  nav_schemes: { en: 'Govt Schemes', hi: 'सरकारी योजनाएँ' },
  nav_alerts: { en: 'Alerts', hi: 'सूचनाएँ' },
  nav_profile: { en: 'My Profile', hi: 'मेरी प्रोफ़ाइल' },
  nav_admin: { en: 'Admin', hi: 'एडमिन' },

  farmer_id: { en: 'Farmer ID', hi: 'किसान आईडी' },
  load: { en: 'Load', hi: 'लोड करें' },

  scan_title: { en: 'Scan a crop leaf', hi: 'फसल की पत्ती जाँचें' },
  scan_pick: { en: 'Choose a photo', hi: 'फोटो चुनें' },
  scan_run: { en: 'Analyze', hi: 'विश्लेषण करें' },
  scan_result: { en: 'Result', hi: 'परिणाम' },
  disease: { en: 'Disease', hi: 'रोग' },
  severity: { en: 'Severity', hi: 'गंभीरता' },
  confidence: { en: 'Confidence', hi: 'विश्वास' },
  treatment: { en: 'Treatment', hi: 'उपचार' },

  crop: { en: 'Crop', hi: 'फसल' },
  mandi: { en: 'Mandi', hi: 'मंडी' },
  price: { en: 'Price (/qtl)', hi: 'भाव (प्रति क्विंटल)' },
  date: { en: 'Date', hi: 'दिनांक' },

  scheme: { en: 'Scheme', hi: 'योजना' },
  ministry: { en: 'Ministry', hi: 'मंत्रालय' },
  benefit: { en: 'Benefit', hi: 'लाभ' },
  match: { en: 'Match', hi: 'मिलान' },
  apply: { en: 'Apply', hi: 'आवेदन करें' },
  recompute: { en: 'Recompute matches', hi: 'मिलान पुनः गणना' },

  message: { en: 'Message', hi: 'संदेश' },
  type: { en: 'Type', hi: 'प्रकार' },
  none: { en: 'Nothing to show yet.', hi: 'अभी कुछ नहीं।' },

  name: { en: 'Name', hi: 'नाम' },
  phone: { en: 'Phone', hi: 'फ़ोन' },
  email: { en: 'Email', hi: 'ईमेल' },
  state: { en: 'State', hi: 'राज्य' },
  district: { en: 'District', hi: 'ज़िला' },
  land_acres: { en: 'Land (acres)', hi: 'भूमि (एकड़)' },
  save: { en: 'Save', hi: 'सहेजें' },
  loading: { en: 'Loading…', hi: 'लोड हो रहा है…' },
};

export function t(key, lang) {
  const s = STRINGS[key];
  if (!s) return key;
  return s[lang] || s.en;
}
