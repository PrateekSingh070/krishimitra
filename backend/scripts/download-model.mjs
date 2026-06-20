/**
 * Ensures the disease ONNX model is present in ml-artifacts/.
 * On Render the model is committed to the repo so this is a no-op.
 * For local dev without the model file, it attempts a download from Hugging Face.
 */
import { existsSync, mkdirSync, createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import https from 'node:https';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const artifactsDir = path.resolve(__dirname, '..', 'ml-artifacts');
const modelPath = path.join(artifactsDir, 'disease_mobilenetv3.onnx');

if (!existsSync(artifactsDir)) mkdirSync(artifactsDir, { recursive: true });

if (existsSync(modelPath)) {
  console.log('Model already present at', modelPath);
  process.exit(0);
}

// Model not found — attempt download (local dev fallback only).
const MODEL_URL =
  'https://huggingface.co/Diginsa/Plant-Disease-Detection-Project/resolve/main/plant_disease_model.onnx';

console.log('Model not found, attempting download from Hugging Face...');

function download(url, dest, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 10) return reject(new Error('Too many redirects'));
    https.get(url, { headers: { 'User-Agent': 'krishimitra-build/1.0' } }, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode)) {
        res.resume();
        return resolve(download(res.headers.location, dest, redirectCount + 1));
      }
      if (res.statusCode !== 200) {
        res.resume();
        // Don't hard-fail — classifier will run without the model (returns placeholder).
        console.warn(`Download returned ${res.statusCode}. Continuing without model.`);
        return resolve();
      }
      const file = createWriteStream(dest);
      pipeline(res, file).then(resolve).catch(reject);
    }).on('error', (err) => {
      console.warn('Download error:', err.message, '— continuing without model.');
      resolve();
    });
  });
}

await download(MODEL_URL, modelPath);
if (existsSync(modelPath)) console.log('Model downloaded to', modelPath);
