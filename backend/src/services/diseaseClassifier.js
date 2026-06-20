import fs from 'node:fs';
import path from 'node:path';
import { config } from '../config/index.js';
import { logger } from '../config/logger.js';
import {
  DEFAULT_CLASS_LABELS,
  DEFAULT_LOOKUP,
  decodePredictions,
  selectTopLabel,
  buildScanPayload,
} from './diseaseLogic.js';

// In-Node MobileNetV3 inference via onnxruntime-node + sharp preprocessing.
// Model/labels/lookup are loaded from config.ml.artifactsDir. If the model is
// absent (e.g. before training), classification gracefully falls back to a
// "needs review" result so the endpoint still works end-to-end.

let session = null;
let ort = null;
let sharp = null;
let classLabels = DEFAULT_CLASS_LABELS;
let lookup = DEFAULT_LOOKUP;
let loaded = false;
let available = false;

const IMG_SIZE = 224;
const MEAN = [0.485, 0.456, 0.406];
const STD = [0.229, 0.224, 0.225];

function artifactPath(file) {
  return path.resolve(config.ml.artifactsDir, file);
}

function loadJsonIfPresent(file, fallback) {
  try {
    const p = artifactPath(file);
    if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (err) {
    logger.warn({ err, file }, 'Failed to read artifact; using built-in default');
  }
  return fallback;
}

// Lazily initialise heavy native deps + the ONNX session (once).
export async function init() {
  if (loaded) return available;
  loaded = true;

  classLabels = loadJsonIfPresent(config.ml.labelsFile, DEFAULT_CLASS_LABELS);
  lookup = loadJsonIfPresent(config.ml.lookupFile, DEFAULT_LOOKUP);

  const modelPath = artifactPath(config.ml.modelFile);
  if (!fs.existsSync(modelPath)) {
    logger.warn({ modelPath }, 'Disease model not found; classifier runs in fallback mode');
    available = false;
    return false;
  }

  try {
    ort = (await import('onnxruntime-node')).default;
    sharp = (await import('sharp')).default;
    session = await ort.InferenceSession.create(modelPath);
    available = true;
    logger.info({ modelPath }, 'Disease ONNX model loaded');
  } catch (err) {
    logger.error({ err }, 'Failed to load ONNX model; classifier runs in fallback mode');
    available = false;
  }
  return available;
}

// Preprocess an image buffer to a normalised CHW Float32Array (1x3x224x224).
async function preprocess(buffer) {
  const { data } = await sharp(buffer)
    .resize(IMG_SIZE, IMG_SIZE, { fit: 'cover' })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const size = IMG_SIZE * IMG_SIZE;
  const out = new Float32Array(3 * size);
  for (let i = 0; i < size; i += 1) {
    for (let c = 0; c < 3; c += 1) {
      const v = data[i * 3 + c] / 255;
      out[c * size + i] = (v - MEAN[c]) / STD[c];
    }
  }
  return out;
}

// Run inference on an image buffer. Returns { labelName, confidence } or a
// fallback when the model is unavailable.
export async function classifyImage(buffer) {
  await init();
  if (!available || !session) {
    return { labelName: 'Needs_review', confidence: 0, fallback: true };
  }

  const input = await preprocess(buffer);
  const tensor = new ort.Tensor('float32', input, [1, 3, IMG_SIZE, IMG_SIZE]);
  const feeds = { [session.inputNames[0]]: tensor };
  const results = await session.run(feeds);
  const scores = Array.from(results[session.outputNames[0]].data);
  const decoded = decodePredictions(scores, classLabels);
  const top = selectTopLabel(decoded);
  return { labelName: top ? top.name : 'Needs_review', confidence: top ? top.confidence : 0 };
}

// Full classify -> scan payload for a given farmer/image.
export async function classifyToPayload({ farmerId, farmerCropId, imageUrl, buffer }) {
  const { labelName, confidence } = await classifyImage(buffer);
  return buildScanPayload({
    farmerId,
    farmerCropId,
    imageUrl,
    labelName,
    confidence,
    visionRequestId: 'onnx-local',
    lookup,
  });
}
