// Vegetable names for client-side filtering (mirrors backend/data/vegetables.js).
export const VEGETABLE_NAMES = new Set([
  'Potato', 'Onion', 'Tomato', 'Brinjal', 'Cabbage', 'Cauliflower', 'Carrot', 'Radish',
  'Beetroot', 'Bottle Gourd', 'Bitter Gourd', 'Ridge Gourd', 'Sponge Gourd', 'Pumpkin',
  'Green Peas', 'French Beans', 'Cowpea', 'Okra', 'Spinach', 'Methi', 'Coriander',
  'Green Chilli', 'Capsicum', 'Ginger', 'Garlic', 'Sweet Potato', 'Yam', 'Tinda',
  'Pointed Gourd', 'Drumstick', 'Colocasia', 'Amaranth', 'Cucumber', 'Muskmelon',
  'Cluster Beans', 'Turnip', 'Knol Khol', 'Broccoli', 'Mushroom', 'Ash Gourd',
  'Snake Gourd', 'Ivy Gourd', 'Spring Onion', 'Mint', 'Curry Leaves', 'Mustard Greens',
  'Lettuce', 'Green Beans',
]);

export const HINDI_CROP_NAMES = {
  Wheat: 'गेहूँ', Rice: 'चावल', Maize: 'मक्का', Bajra: 'बाजरा',
  Jowar: 'ज्वार', Sugarcane: 'गन्ना', Cotton: 'कपास', Soybean: 'सोयाबीन',
  Groundnut: 'मूँगफली', Mustard: 'सरसों', Gram: 'चना', Lentil: 'मसूर',
  Barley: 'जौ', Potato: 'आलू', Onion: 'प्याज', Tomato: 'टमाटर',
  Watermelon: 'तरबूज', Cucumber: 'खीरा', Moong: 'मूँग', Turmeric: 'हल्दी',
  Brinjal: 'बैंगन', Cabbage: 'पत्ता गोभी', Cauliflower: 'फूल गोभी', Carrot: 'गाजर',
  Radish: 'मूली', Beetroot: 'चुकंदर', 'Bottle Gourd': 'लौकी', 'Bitter Gourd': 'करेला',
  'Ridge Gourd': 'तोरी', 'Sponge Gourd': 'घिया', Pumpkin: 'कद्दू', 'Green Peas': 'हरा मटर',
  'French Beans': 'सेम', Cowpea: 'लोबिया', Okra: 'भिंडी', Spinach: 'पालक',
  Methi: 'मेथी', Coriander: 'धनिया', 'Green Chilli': 'हरी मिर्च', Capsicum: 'शिमला मिर्च',
  Ginger: 'अदरक', Garlic: 'लहसुन', 'Sweet Potato': 'शकरकंद', Yam: 'जिमीकंद',
  Tinda: 'टिंडा', 'Pointed Gourd': 'परवल', Drumstick: 'सहजन', Colocasia: 'अरबी',
  Amaranth: 'चौलाई', Muskmelon: 'खरबूजा', 'Cluster Beans': 'ग्वार फली', Turnip: 'शलजम',
  'Knol Khol': 'गाठ गोभी', Broccoli: 'ब्रोकली', Mushroom: 'मशरूम', 'Ash Gourd': 'पेठा',
  'Snake Gourd': 'चिचिंडा', 'Ivy Gourd': 'कुंदरु', 'Spring Onion': 'हरा प्याज',
  Mint: 'पुदीना', 'Curry Leaves': 'कड़ी पत्ता', 'Mustard Greens': 'सरसों साग',
  Lettuce: 'सलाद पत्ता', 'Green Beans': 'बीन',
};

export function isVegetable(row) {
  if (row.crop_type === 'Vegetable') return true;
  return VEGETABLE_NAMES.has(row.crop_name);
}

export function cropDisplayName(row, lang) {
  if (lang !== 'hi') return row.crop_name;
  const fallback = HINDI_CROP_NAMES[row.crop_name] || row.crop_name;
  return row.crop_name_hindi || fallback;
}
