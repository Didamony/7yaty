#!/bin/bash
# Installs the published APK on the running emulator, opens it and keeps
# what happened: screenshots and the crash log. Run by android-check.yml.
set -x
OUT="$1"; mkdir -p "$OUT"
adb wait-for-device
adb shell getprop ro.build.version.release > "$OUT/android-version.txt"
adb install -r hayati.apk > "$OUT/install.txt" 2>&1
adb logcat -c
adb shell am start -W -n com.didamony.hayati/.MainActivity > "$OUT/start.txt" 2>&1
for t in 5 15 30; do
  sleep $([ $t = 5 ] && echo 5 || echo $(( t == 15 ? 10 : 15 )))
  adb exec-out screencap -p > "$OUT/screen-${t}s.png"
done
adb shell pidof com.didamony.hayati > "$OUT/pid.txt" 2>&1 || echo "NOT RUNNING" >> "$OUT/pid.txt"
adb logcat -d -b crash > "$OUT/crash.txt" 2>&1
adb logcat -d '*:W' > "$OUT/warnings.txt" 2>&1
adb logcat -d -s flutter:V > "$OUT/flutter.txt" 2>&1
grep -iE "hayati|flutter|FATAL|AndroidRuntime|firebase" "$OUT/warnings.txt" | tail -300 > "$OUT/app-log.txt"
true
