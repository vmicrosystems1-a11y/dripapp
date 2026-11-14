from pathlib import Path
import sys

root = Path(sys.argv[1])
app = root / 'android/app/build.gradle.kts'
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not app.is_file() or not manifest.is_file():
    raise SystemExit('Flutter Android project missing')

# Flutter creates this package from --org and --project-name.
expected = 'com.vmicrosystems.drip_irrigation2'
gradle = app.read_text()
if f'applicationId = "{expected}"' not in gradle:
    raise SystemExit(f'Expected Android applicationId {expected}; inspect Flutter create output')
app.write_text(gradle)

xml = manifest.read_text()
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if permission not in xml:
    xml = xml.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                      '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission, 1)
# Change the visible Android launcher label.
import re
xml, count = re.subn(r'android:label="[^"]*"', 'android:label="Drip Irrigation 2"', xml, count=1)
if count != 1:
    raise SystemExit('Could not set Android launcher label')
manifest.write_text(xml)
