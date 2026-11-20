# WATHAQ Android application foundation

## Identity
- Display name: WATHAQ (وِثاق)
- Android application ID: `com.wathaq.app`
- Web source: `web/`
- Capacitor web output: `public/`
- Backend: WATHAQ-CORE Supabase project only.

## Local Android build prerequisites
- Node.js 22 LTS
- npm
- Android Studio with Android SDK and a supported JDK
- A physical Android device or emulator for verification

## Initialize and build
```bash
npm install
npm run web:build
npx cap add android
npx cap sync android
npx cap open android
```

Build the debug APK from Android Studio (Build > Build Bundle(s) / APK(s) > Build APK(s)).
Do not commit signing keys, keystores, local.properties, service-role keys, or OAuth client secrets.

## Google OAuth status
The web app currently starts Google OAuth through Supabase and returns to its current browser URL. This is suitable for the hosted web/PWA flow after the hosted origin is allow-listed in Supabase Auth URL Configuration.

The native Android callback is **not yet enabled**. Before adding a custom-scheme callback, implement and test the Capacitor Browser + App URL-open flow, register the exact deep-link intent filter in the Android manifest, and allow only the exact callback URL in Supabase Redirect URLs. Do not guess or add a callback URL in Supabase before that implementation exists.

## Release gates
- Implement native OAuth callback/session handoff and verify token handling.
- Test Google sign-in on a real Android device.
- Verify camera permissions and QR scanning in Android WebView.
- Validate app lifecycle, keyboard, safe areas, and offline behavior.
- Configure production signing and backup/recovery procedures.
- Do not publish an APK until the release-readiness checklist is complete.
