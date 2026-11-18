// WATHAQ service worker: caches the app shell for weak connections. Never touches Supabase API calls.
const V = 'wathaq-v0.4.0';
const SHELL = ['./', './index.html', './config.js', './manifest.webmanifest', './assets/mark.png', './assets/logo.png', './icons/icon-192.png'];
self.addEventListener('install', (e) => { e.waitUntil(caches.open(V).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', (e) => { e.waitUntil(caches.keys().then((k) => Promise.all(k.filter((x) => x !== V).map((x) => caches.delete(x)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', (e) => {
  const r = e.request; if (r.method !== 'GET') return;
  const u = new URL(r.url), same = u.origin === self.location.origin, cdn = /(^|\.)jsdelivr\.net$|^fonts\.(googleapis|gstatic)\.com$/.test(u.hostname);
  if (!same && !cdn) return; // Supabase and anything else goes straight to the network
  e.respondWith(caches.match(r).then((hit) => {
    const net = fetch(r).then((res) => { if (res.ok) { const cp = res.clone(); caches.open(V).then((c) => c.put(r, cp)); } return res; }).catch(() => hit || (r.mode === 'navigate' ? caches.match('./index.html') : undefined));
    return hit || net;
  }));
});
