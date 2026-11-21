#!/usr/bin/env python3
from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit("AndroidManifest.xml was not generated")

xml = manifest.read_text(encoding="utf-8")
if 'android:scheme="com.wathaq.app"' in xml:
    print("WATHAQ auth deep link already configured")
    raise SystemExit(0)

intent_filter = """
            <intent-filter android:label="wathaq_auth_callback">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.wathaq.app" android:host="auth" android:path="/callback" />
            </intent-filter>
"""
pattern = r'(<activity\b(?=[^>]*android:name="[^"]*MainActivity")[\s\S]*?)(\s*</activity>)'
updated, count = re.subn(pattern, lambda match: match.group(1) + intent_filter + match.group(2), xml, count=1)
if count != 1:
    raise SystemExit("Could not find the generated MainActivity to register OAuth callback")
manifest.write_text(updated, encoding="utf-8")
print("Registered com.wathaq.app://auth/callback")
