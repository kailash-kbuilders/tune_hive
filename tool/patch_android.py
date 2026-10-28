"""Adds the Android permissions, audio-service entries and the
AudioServiceActivity base class that TuneHive needs.

Run by the APK workflow after the android/ folder is generated. Safe to run
more than once: every edit is skipped when it is already present.
"""
import pathlib
import re

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

PERMISSIONS = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.WAKE_LOCK" />',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="32" />',
]

QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.MEDIA_BUTTON" />
        </intent>
        <intent>
            <action android:name="android.media.browse.MediaBrowserService" />
        </intent>
    </queries>
"""

SERVICE = """        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
"""


NOTIFICATION_ICON = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,3C7.03,3 3,7.03 3,12v6c0,1.1 0.9,2 2,2h1c0.55,0 1,-0.45 1,-1v-5c0,-0.55 -0.45,-1 -1,-1H5v-1c0,-3.87 3.13,-7 7,-7s7,3.13 7,7v1h-1c-0.55,0 -1,0.45 -1,1v5c0,0.55 0.45,1 1,1h1c1.1,0 2,-0.9 2,-2v-6c0,-4.97 -4.03,-9 -9,-9z" />
</vector>
"""


KEEP_RULE = """<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_tunehive" />
"""


def write_notification_icon() -> None:
    """A white headphones silhouette for the status bar.

    Without this the notification uses mipmap/ic_launcher, which Android
    renders as an ugly white square. The keep rule matters: the drawable is
    only referenced by name from Dart, so resource shrinking would otherwise
    delete it from the release APK.
    """
    target = pathlib.Path("android/app/src/main/res/drawable/ic_stat_tunehive.xml")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(NOTIFICATION_ICON)

    keep = pathlib.Path("android/app/src/main/res/raw/keep.xml")
    keep.parent.mkdir(parents=True, exist_ok=True)
    keep.write_text(KEEP_RULE)
    print("notification icon + keep rule written")


def patch_main_activity() -> None:
    """audio_service needs MainActivity to extend AudioServiceActivity."""
    root = pathlib.Path("android/app/src/main/kotlin")
    if not root.exists():
        root = pathlib.Path("android/app/src/main/java")
    candidates = list(root.rglob("MainActivity.kt")) + list(root.rglob("MainActivity.java"))
    if not candidates:
        print("MainActivity not found, skipping")
        return
    target = candidates[0]
    text = target.read_text()
    package = "com.example.tune_hive"
    for line in text.splitlines():
        if line.strip().startswith("package "):
            package = line.strip().split("package ", 1)[1].rstrip(";").strip()
            break
    if target.suffix == ".kt":
        target.write_text(
            "package " + package + "\n\n"
            "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
            "class MainActivity : AudioServiceActivity()\n"
        )
    else:
        target.write_text(
            "package " + package + ";\n\n"
            "import com.ryanheise.audioservice.AudioServiceActivity;\n\n"
            "public class MainActivity extends AudioServiceActivity {\n}\n"
        )
    print("rewrote", target)


def main() -> None:
    if not MANIFEST.exists():
        print("manifest not found, nothing to patch")
        return
    text = MANIFEST.read_text()

    missing = [p for p in PERMISSIONS if p.split('"')[1] not in text]
    if missing:
        block = "\n".join("    " + p for p in missing) + "\n"
        text = re.sub(r"(<manifest[^>]*>)", lambda m: m.group(1) + "\n" + block, text, count=1)

    if "<queries>" not in text:
        text = text.replace("</manifest>", QUERIES + "</manifest>")

    if "com.ryanheise.audioservice.AudioService" not in text:
        text = text.replace("    </application>", SERVICE + "    </application>")
        if "com.ryanheise.audioservice.AudioService" not in text:
            text = text.replace("</application>", SERVICE + "</application>")

    if 'android:name=".MainActivity"' in text and "singleTop" not in text:
        text = text.replace(
            'android:name=".MainActivity"',
            'android:name=".MainActivity"\n            android:launchMode="singleTop"',
        )

    text = re.sub(r'android:label="[^"]*"', 'android:label="TuneHive"', text)
    MANIFEST.write_text(text)
    print("manifest patched")
    write_notification_icon()
    patch_main_activity()


if __name__ == "__main__":
    main()
