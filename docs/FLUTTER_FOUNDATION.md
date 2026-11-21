# WATHAQ Native Flutter Foundation

## 1. Migration decision
The existing Capacitor web application remains intact as a reference and rollback path. This branch introduces a separate native Flutter application. Supabase project, schema, existing loyalty tables, and RPC contracts are preserved; no database migration is applied by this foundation.

## 2. Stack
- Flutter / Dart
- Riverpod for state management
- go_router for navigation
- supabase_flutter for Auth and data
- intl for consistent number and date formatting
- cached_network_image for remote merchant imagery
- Tajawal variable font bundled into the APK by scripts/download_fonts.sh

## 3. Current foundation
- Design tokens are centralized in WathaqTokens ThemeExtension.
- Light and dark themes share the same semantic token names.
- Arabic RTL is applied at the app boundary.
- Reusable points, tier, offer, activity, buttons, badge, and skeleton components are provided.
- Home screen uses native Material navigation and a primary scan action.
- Current sample values are presentation placeholders only; live repositories and auth are added in the next implementation stage.

## 4. Build
Run:
```sh
flutter create . --platforms=android
sh scripts/download_fonts.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Pass Supabase configuration using compile-time defines:
```sh
flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
Never place service_role keys in the client application.
