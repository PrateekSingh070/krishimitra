// Pure, side-effect-free disease-classification logic.
// JS port of functions/disease-classifier/disease_logic.py so it can be
// unit-tested without onnxruntime. Hindi advice is PRE-TRANSLATED (no runtime
// translation in the free path).

export const SEVERITY_ORDER = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

// Class index order the ONNX model was trained on (ml/01_disease_classifier).
// Loaded from class_labels.json in production; this is the built-in fallback.
export const DEFAULT_CLASS_LABELS = [
  'Tomato___Late_blight',
  'Tomato___healthy',
  'Potato___Early_blight',
  'Wheat___Leaf_rust',
  'Rice___Blast',
  'Corn___Common_rust',
];

// Minimal built-in lookup (loaded from disease_lookup.json in production).
export const DEFAULT_LOOKUP = {
  Tomato___Late_blight: {
    disease: 'Tomato Late Blight',
    severity: 'HIGH',
    treatment:
      'Remove and destroy infected foliage. Apply a copper-based or chlorothalonil fungicide. Avoid overhead irrigation.',
    treatment_hi:
      'संक्रमित पत्तियों को हटाकर नष्ट करें। कॉपर या क्लोरोथैलोनिल फफूंदनाशक छिड़कें। ऊपर से सिंचाई से बचें।',
  },
  Tomato___healthy: {
    disease: 'Healthy',
    severity: 'LOW',
    treatment: 'No action needed.',
    treatment_hi: 'किसी कार्रवाई की आवश्यकता नहीं।',
  },
  Potato___Early_blight: {
    disease: 'Potato Early Blight',
    severity: 'MEDIUM',
    treatment: 'Apply mancozeb or chlorothalonil. Rotate crops and remove debris.',
    treatment_hi:
      'मैंकोज़ेब या क्लोरोथैलोनिल छिड़कें। फसल चक्र अपनाएं और अवशेष हटाएं।',
  },
  Wheat___Leaf_rust: {
    disease: 'Wheat Leaf Rust',
    severity: 'HIGH',
    treatment: 'Spray propiconazole at first sign. Use resistant varieties next season.',
    treatment_hi:
      'लक्षण दिखते ही प्रोपिकोनाज़ोल छिड़कें। अगले सीज़न प्रतिरोधी किस्में बोएं।',
  },
  Rice___Blast: {
    disease: 'Rice Blast',
    severity: 'CRITICAL',
    treatment:
      'Apply tricyclazole immediately. Drain field; reduce nitrogen. Consult your agriculture officer.',
    treatment_hi:
      'तुरंत ट्राइसाइक्लाज़ोल छिड़कें। खेत का पानी निकालें; नाइट्रोजन कम करें। कृषि अधिकारी से सलाह लें।',
  },
  Corn___Common_rust: {
    disease: 'Maize Common Rust',
    severity: 'MEDIUM',
    treatment: 'Apply a foliar fungicide if severe. Plant resistant hybrids.',
    treatment_hi:
      'गंभीर होने पर पत्तियों पर फफूंदनाशक छिड़कें। प्रतिरोधी संकर किस्में लगाएं।',
  },
};

// Numerically-stable softmax.
export function softmax(scores) {
  if (!scores || scores.length === 0) return [];
  const m = Math.max(...scores);
  const exps = scores.map((s) => Math.exp(s - m));
  const total = exps.reduce((a, b) => a + b, 0) || 1;
  return exps.map((e) => e / total);
}

// Turn raw model output scores into a sorted [{name, confidence}] list.
export function decodePredictions(scores, classLabels = null) {
  const labels = classLabels || DEFAULT_CLASS_LABELS;
  const probs = scores && scores.length ? softmax(Array.from(scores)) : [];
  const out = [];
  const n = Math.min(labels.length, probs.length);
  for (let i = 0; i < n; i += 1) out.push({ name: labels[i], confidence: Number(probs[i]) });
  out.sort((a, b) => b.confidence - a.confidence);
  return out;
}

export function selectTopLabel(labels) {
  if (!labels || labels.length === 0) return null;
  return labels.reduce((best, l) => (l.confidence > (best?.confidence ?? -1) ? l : best), null);
}

// Map a raw label to a disease record.
export function mapLabelToDisease(labelName, lookup = null) {
  const table = lookup || DEFAULT_LOOKUP;
  if (table[labelName]) return { ...table[labelName] };
  const pretty = labelName.replace(/___/g, ' ').replace(/_/g, ' ').trim();
  return {
    disease: pretty || 'Unknown condition',
    severity: 'MEDIUM',
    treatment:
      'Condition not in knowledge base. Please consult your agriculture officer for diagnosis.',
    treatment_hi:
      'यह स्थिति ज्ञानकोश में नहीं है। कृपया निदान के लिए अपने कृषि अधिकारी से संपर्क करें।',
  };
}

// Assemble the scan record persisted to disease_scans.
export function buildScanPayload({
  farmerId,
  imageUrl,
  labelName,
  confidence,
  treatmentHindi = null,
  visionRequestId = null,
  farmerCropId = null,
  lookup = null,
}) {
  const record = mapLabelToDisease(labelName, lookup);
  return {
    farmer_id: farmerId,
    farmer_crop_id: farmerCropId,
    image_url: imageUrl,
    disease_detected: record.disease,
    confidence_score:
      confidence <= 1
        ? Math.round(Number(confidence) * 100 * 100) / 100
        : Math.round(Number(confidence) * 100) / 100,
    severity: record.severity,
    treatment_advice: record.treatment,
    treatment_hindi: treatmentHindi || record.treatment_hi || record.treatment,
    oci_vision_req: visionRequestId,
  };
}
