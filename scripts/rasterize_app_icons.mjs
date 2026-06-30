#!/usr/bin/env node
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const { Resvg } = await import(pathToFileURL(join(__dirname, 'node_modules/@resvg/resvg-js/index.js')).href);

const OUT_DIR = join(__dirname, '..', 'assets', 'icon', 'v3');
const SIZE = 1024;

for (const file of readdirSync(OUT_DIR).filter((f) => /_(flat|premium)\.svg$/.test(f))) {
  const svg = readFileSync(join(OUT_DIR, file), 'utf8');
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: SIZE } }).render().asPng();
  const base = file.replace(/_(flat|premium)\.svg$/, '');
  const style = file.includes('_flat.') ? 'flat' : 'premium';
  const outName = style === 'flat' ? `${base}_1024_flat.png` : `${base}_1024.png`;
  const outPath = join(OUT_DIR, outName);
  writeFileSync(outPath, png);
  console.log(`Wrote ${outPath}`);
}
