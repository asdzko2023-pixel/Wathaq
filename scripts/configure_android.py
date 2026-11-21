#!/usr/bin/env python3
from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit("AndroidManifest.xml was not generated")

xml = manifest.read_text(encoding="utf-8")

# Release builds need INTERNET in the main manifest. The generated Flutter
# debug/profile manifests may include it only for non-release variants.
internet_permission = '<uses-permission android:name="android.permission.INTERNET" />'
if "android.permission.INTERNET" not in xml:
    xml, count = re.subn(
        r'(<manifest\\b[^>]*>)',
        r'\\1\\n    ' + internet_permission,
        xml,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not add INTERNET permission to AndroidManifest.xml")
    print("Added INTERNET permission to main Android manifest")
else:
    print("INTERNET permission already present")

# Ensure the OAuth callback intent filter exists.
if 'android:scheme="com.wathaq.app"' not in xml:
    intent_filter = """
            <intent-filter android:label="wathaq_auth_callback">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.wathaq.app" android:host="auth" android:path="/callback" />
            </intent-filter>
"""
    pattern = r'(<activity\\b(?=[^>]*android:name="[^"]*MainActivity")[\\s\\S]*?)(\\s*</activity>)'
    xml, count = re.subn(
        pattern,
        lambda match: match.group(1) + intent_filter + match.group(2),
        xml,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not find the generated MainActivity to register OAuth callback")
    print("Registered com.wathaq.app://auth/callback")
else:
    print("WATHAQ auth deep link already configured")

manifest.write_text(xml, encoding="utf-8")
