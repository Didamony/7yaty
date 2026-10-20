"""Turns the Firebase web config pasted into the FIREBASE_CONFIG secret
(the `const firebaseConfig = {...}` snippet from the Firebase console, as
is) into a --dart-define-from-file JSON. Without the secret the file is
empty and the app runs without accounts."""
import json
import os
import re
import sys

keys = {
    'apiKey': 'FB_API_KEY',
    'authDomain': 'FB_AUTH_DOMAIN',
    'projectId': 'FB_PROJECT_ID',
    'storageBucket': 'FB_STORAGE_BUCKET',
    'messagingSenderId': 'FB_SENDER_ID',
    'appId': 'FB_WEB_APP_ID',
}
text = os.environ.get('FIREBASE_CONFIG', '')
out = {}
for key, define in keys.items():
    m = re.search(r'["\']?%s["\']?\s*:\s*["\']([^"\']+)["\']' % key, text)
    if m:
        out[define] = m.group(1)
android = os.environ.get('FIREBASE_ANDROID_APP_ID', '').strip()
if android:
    out['FB_ANDROID_APP_ID'] = android
json.dump(out, open(sys.argv[1], 'w'))
print('Firebase:', out.get('FB_PROJECT_ID', 'not set up'))
