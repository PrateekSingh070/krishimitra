/**
 * Downloads the disease classification ONNX model from Hugging Face at build
 * time. Safe to re-run — skips download if the file already exists.
 *
 * Usage: node scripts/download-model.mjs
 * Called automatically by the Render build command.
 */
import { existsSync, mkdirSync, createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const artifactsDir = path.resolve(__dirname, '..', 'ml-artifacts');
const modelPath = path.join(artifactsDir, 'disease_mobilenetv3.onnx');

const MODEL_URL =
  'https://huggingface.co/Diginsa/Plant-Disease-Detection-Project/resolve/main/plant_disease_model.onnx';

if (!existsSync(artifactsDir)) mkdirSync(artifactsDir, { recursive: true });

if (existsSync(modelPath)) {
  console.log('Model already present, skipping download.');
  process.exit(0);
}

console.log('Downloading disease ONNX model (~4 MB)...');
const resp = await fetch(MODEL_URL);
if (!resp.ok) throw new Error(`Download failed: ${resp.status} ${resp.statusText}`);
await pipeline(resp.body, createWriteStream(modelPath));
console.log('Model downloaded to', modelPath);
