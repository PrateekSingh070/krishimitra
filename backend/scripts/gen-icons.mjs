import sharp from 'sharp';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(__dirname, '../../frontend/public');

const svg = (size, rx) => Buffer.from(
  `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">` +
  `<rect width="${size}" height="${size}" rx="${rx}" fill="#2e7d32"/>` +
  `<text x="${size / 2}" y="${size * 0.72}" font-size="${size * 0.57}" text-anchor="middle">🌾</text>` +
  `</svg>`
);

await sharp(svg(192, 32)).png().toFile(path.join(out, 'icon-192.png'));
await sharp(svg(512, 80)).png().toFile(path.join(out, 'icon-512.png'));
console.log('PWA icons generated → frontend/public/');
