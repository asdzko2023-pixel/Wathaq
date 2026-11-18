// Builds ./public (the deployable site) from sources. Usage: node app/build.mjs
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, rmSync, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const here = dirname(fileURLToPath(import.meta.url)), root = join(here, '..'), out = join(root, 'public');
const rd = (p) => readFileSync(p, 'utf8');
rmSync(out, { recursive: true, force: true });
for (const d of ['', 'assets', 'icons']) mkdirSync(join(out, d), { recursive: true });
const css = [rd(join(root, 'packages/design-tokens/tokens.css')), rd(join(root, 'packages/ui/components.css')), rd(join(here, 'src/app.css'))].join('\n');
const js = rd(join(here, 'src/app.mjs'));
if (js.includes('</script')) throw new Error('app.mjs must not contain a closing script tag');
const html = rd(join(here, 'src/template.html')).replace('/*CSS*/', () => css).replace('/*JS*/', () => js);
writeFileSync(join(out, 'index.html'), html);
for (const f of ['config.js', 'sw.js', 'manifest.webmanifest']) copyFileSync(join(here, f), join(out, f));
const brand = join(root, 'assets/brand');
copyFileSync(join(brand, 'logo-mark-transparent.png'), join(out, 'assets/mark.png'));
copyFileSync(join(brand, 'logo-horizontal-transparent.png'), join(out, 'assets/logo.png'));
for (const f of ['icon-192.png', 'icon-512.png', 'maskable-512.png']) copyFileSync(join(here, 'icons', f), join(out, 'icons', f));
// Sub-apps deployed under /staff/ and /merchant/. Each loads the shared ../config.js.
for (const page of ['staff', 'merchant']) {
  const src = join(here, page), dst = join(out, page);
  mkdirSync(dst, { recursive: true });
  for (const f of readdirSync(src)) if (/\.(html|mjs)$/.test(f)) copyFileSync(join(src, f), join(dst, f));
}
writeFileSync(join(out, '.nojekyll'), '');
console.log('built public/index.html', html.length, 'bytes');
