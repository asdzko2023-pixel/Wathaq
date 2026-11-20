# WATHAQ Web App

This folder contains the current Arabic RTL PWA source for the customer, merchant, staff, and platform-admin experiences.

- `index.html`: application shell and dialogs.
- `styles.css`: Midnight + Gold design system.
- `app.js`: UI rendering, Supabase Google OAuth, data calls, loyalty workflows, QR generation and camera scanning.
- `config.js`: public Supabase URL and publishable key only.
- Google OAuth is initiated through Supabase Auth; provider credentials are configured in Supabase Dashboard, never in this repository. See `docs/GOOGLE_AUTH_SETUP.md`.
- `manifest.webmanifest`, `icon.svg`, `sw.js`: installability and static-shell caching.

Build the deployable bundle with:

```bash
node app/build.mjs
```

The generated `public/` directory must remain byte-for-byte aligned with the source assets. The service worker caches the static shell; online authentication and loyalty transactions still require a network connection. Camera scanning requires HTTPS, permission, and browser `BarcodeDetector` support; manual code entry remains available.
