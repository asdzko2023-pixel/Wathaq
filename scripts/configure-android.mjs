import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const manifest = 'android/app/src/main/AndroidManifest.xml';
if (!existsSync(manifest)) {
  throw new Error('AndroidManifest.xml not found. Run npx cap add android first.');
}
let xml = readFileSync(manifest, 'utf8');
const scheme = 'com.wathaq.app';
if (xml.includes('android:scheme="' + scheme + '"')) {
  console.log('WATHAQ OAuth deep link is already registered.');
} else {
  const activityStart = xml.indexOf('<activity');
  const activityEnd = xml.indexOf('</activity>', activityStart);
  if (activityStart < 0 || activityEnd < 0) {
    throw new Error('Could not locate the main Android activity in AndroidManifest.xml.');
  }
  const intentFilter = `
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.wathaq.app" android:host="auth" android:path="/callback" />
            </intent-filter>
`;
  xml = xml.slice(0, activityEnd) + intentFilter + xml.slice(activityEnd);
  writeFileSync(manifest, xml);
  console.log('Registered WATHAQ native OAuth callback:', scheme + '://auth/callback');
}
