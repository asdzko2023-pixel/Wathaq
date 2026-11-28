// Builds the Android/WebView/PWA public bundle from the WATHAQ Core UI.
// Usage: node app/build.mjs
import { copyFileSync, mkdirSync, rmSync, existsSync, writeFileSync } from 'node:fs';
import { build as bundle } from 'esbuild';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const source = join(root, 'web');
const out = join(root, 'public');
const assets = [
  'index.html',
  'styles.css',
  'config.js',
  'manifest.webmanifest',
  'icon.svg',
  'wathaq-logo.svg',
  'sw.js'
];

for (const file of assets) {
  if (!existsSync(join(source, file))) {
    throw new Error('Missing WATHAQ web asset: ' + file);
  }
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const file of assets) copyFileSync(join(source, file), join(out, file));
await bundle({
  entryPoints: [join(source, 'app.js')],
  bundle: true,
  platform: 'browser',
  format: 'esm',
  target: ['es2020'],
  outfile: join(out, 'app.js')
});
writeFileSync(join(out, '.nojekyll'), '');
console.log('WATHAQ Core public bundle built:', assets.length + 1, 'assets (including Capacitor plugins)');
