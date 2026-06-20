/**
 * Downloads the disease classification ONNX model from Hugging Face at build
 * time. Safe to re-run — skips download if the file already exists.
 *
 * Usage: node scripts/download-model.mjs
 * Called automatically by the Render build command.
 */
import { existsSync, mkdirSync, createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import https from 'node:https';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const artifactsDir = path.resolve(__dirname, '..', 'ml-artifacts');
const modelPath = path.join(artifactsDir, 'disease_mobilenetv3.onnx');

// Primary URL (Hugging Face LFS redirect).
const MODEL_URL =
  'https://huggingface.co/Diginsa/Plant-Disease-Detection-Project/resolve/main/plant_disease_model.onnx';

if (!existsSync(artifactsDir)) mkdirSync(artifactsDir, { recursive: true });

if (existsSync(modelPath)) {
  console.log('Model already present, skipping download.');
  process.exit(0);
}

console.log('Downloading disease ONNX model (~4 MB)...');

// Use raw https.get to follow redirects manually (works in all Node versions).
function download(url, dest, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 10) return reject(new Error('Too many redirects'));
    https.get(url, { headers: { 'User-Agent': 'krishimitra-build/1.0' } }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
        res.resume();
        return resolve(download(res.headers.location, dest, redirectCount + 1));
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`Download failed: ${res.statusCode} from ${url}`));
      }
      const file = createWriteStream(dest);
      pipeline(res, file).then(resolve).catch(reject);
    }).on('error', reject);
  });
}

await download(MODEL_URL, modelPath);
console.log('Model downloaded to', modelPath);
