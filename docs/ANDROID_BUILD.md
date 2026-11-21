# WATHAQ Android application foundation

## Identity
- Display name: WATHAQ (وِثاق)
- Android application ID: `com.wathaq.app`
- Native OAuth callback: `com.wathaq.app://auth/callback`
- Web source: `web/`
- Capacitor web output: `public/`
- Backend: WATHAQ-CORE Supabase project only.

## Build
```bash
npm install
npm run web:build
npx cap add android
node scripts/configure-android.mjs
npx cap sync android
npx cap open android
```

The Android workflow runs the same sequence and uploads a debug APK. The JavaScript build bundles Capacitor's App and Browser plugins into the WebView entry point.

## Google OAuth
- Web/PWA uses the current HTTPS origin as its Supabase redirect.
- Android uses the exact callback `com.wathaq.app://auth/callback`.
- Native sign-in opens the Supabase OAuth URL in Capacitor Browser, receives the app URL through the Android intent filter, and exchanges the PKCE authorization code for a Supabase session.
- In Supabase Auth > URL Configuration, add `com.wathaq.app://auth/callback` to Redirect URLs before testing native Google sign-in.
- Keep the Google Cloud OAuth authorized redirect URI as `https://ncfromrlnlotrwkgjenk.supabase.co/auth/v1/callback`. This provider callback is different from the app callback.
- Never place the Google Client Secret or Supabase service-role key in the Android app, web bundle, or repository.

## Release gates
- Verify Google sign-in on a real Android device after adding the exact Supabase Redirect URL.
- Verify QR camera permissions and scanning in Android WebView.
- Validate app lifecycle, keyboard, safe areas, and offline behavior.
- Configure production signing and backup/recovery procedures.
- Do not publish the debug APK as a production release.
