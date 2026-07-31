#!/usr/bin/env python3
"""Apply Android resources after `flutter create` regenerates the platform folder."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_MAIN = ROOT / "android" / "app" / "src" / "main"
RES = ANDROID_MAIN / "res"
MANIFEST = ANDROID_MAIN / "AndroidManifest.xml"
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip() + "\n", encoding="utf-8")


def configure_icons() -> None:
    for folder in RES.glob("mipmap-*"):
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            target = folder / name
            if target.exists():
                target.unlink()

    write(
        RES / "values" / "ti_colors.xml",
        """
<resources>
    <color name="ti_launcher_background">#090A0D</color>
</resources>
""",
    )

    foreground = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFD9AA4F"
        android:pathData="M54,12 L96,54 L54,96 L12,54 Z" />
    <path
        android:fillColor="#FF11141A"
        android:pathData="M54,22 L86,54 L54,86 L22,54 Z" />
    <path
        android:fillColor="#FFD9AA4F"
        android:pathData="M30,32 L78,32 L78,43 L60,43 L60,78 L48,78 L48,43 L30,43 Z" />
    <path
        android:fillColor="#FFFFE0A0"
        android:pathData="M67,52 L83,52 L71,65 L67,65 Z" />
</vector>
"""
    write(RES / "drawable" / "ic_launcher_foreground.xml", foreground)

    legacy = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#FF090A0D" android:pathData="M0,0 L108,0 L108,108 L0,108 Z" />
    <path android:fillColor="#FFD9AA4F" android:pathData="M54,10 L98,54 L54,98 L10,54 Z" />
    <path android:fillColor="#FF11141A" android:pathData="M54,20 L88,54 L54,88 L20,54 Z" />
    <path android:fillColor="#FFD9AA4F" android:pathData="M30,32 L78,32 L78,43 L60,43 L60,78 L48,78 L48,43 L30,43 Z" />
    <path android:fillColor="#FFFFE0A0" android:pathData="M67,52 L83,52 L71,65 L67,65 Z" />
</vector>
"""
    write(RES / "mipmap-anydpi" / "ic_launcher.xml", legacy)
    write(RES / "mipmap-anydpi" / "ic_launcher_round.xml", legacy)

    adaptive = """
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ti_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
    write(RES / "mipmap-anydpi-v26" / "ic_launcher.xml", adaptive)
    write(RES / "mipmap-anydpi-v26" / "ic_launcher_round.xml", adaptive)

    notification = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,1.5 L22.5,12 L12,22.5 L1.5,12 Z" />
    <path
        android:fillColor="#00000000"
        android:pathData="M6.5,7.2 L17.5,7.2 L17.5,9.7 L13.4,9.7 L13.4,17 L10.6,17 L10.6,9.7 L6.5,9.7 Z" />
</vector>
"""
    notification = notification.replace('android:fillColor="#00000000"', 'android:fillColor="#FFFFFFFF"')
    write(RES / "drawable" / "ic_stat_ti.xml", notification)

    write(
        RES / "values" / "drawable_keep.xml",
        """
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_ti,@drawable/ic_launcher_foreground,@mipmap/ic_launcher,@mipmap/ic_launcher_round" />
""",
    )


def configure_manifest() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET" />',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
        '<uses-permission android:name="android.permission.VIBRATE" />',
    ]
    insert_at = text.find(">") + 1
    for permission in reversed(permissions):
        if permission not in text:
            text = text[:insert_at] + "\n    " + permission + text[insert_at:]

    text = re.sub(
        r'android:label="[^"]*"',
        'android:label="TI Predictions Tracker"',
        text,
        count=1,
    )
    if 'android:roundIcon=' not in text:
        text = text.replace(
            'android:icon="@mipmap/ic_launcher"',
            'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"',
            1,
        )
    MANIFEST.write_text(text, encoding="utf-8")


def configure_gradle() -> None:
    text = GRADLE.read_text(encoding="utf-8")
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = re.sub(
            r"compileOptions\s*\{",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            text,
            count=1,
        )

    if "multiDexEnabled" not in text:
        text = re.sub(
            r"defaultConfig\s*\{",
            "defaultConfig {\n        multiDexEnabled = true",
            text,
            count=1,
        )

    dependency = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
    if dependency not in text:
        if re.search(r"dependencies\s*\{", text):
            text = re.sub(
                r"dependencies\s*\{",
                f"dependencies {{\n    {dependency}",
                text,
                count=1,
            )
        else:
            text = text.rstrip() + f"\n\ndependencies {{\n    {dependency}\n}}\n"

    GRADLE.write_text(text, encoding="utf-8")


def main() -> None:
    if not ANDROID_MAIN.exists() or not GRADLE.exists():
        raise SystemExit("Run `flutter create . --platforms=android` before this script.")
    configure_icons()
    configure_manifest()
    configure_gradle()
    print("Configured launcher assets, notification assets, network permissions, and Android build settings.")


if __name__ == "__main__":
    main()
