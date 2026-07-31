#!/usr/bin/env python3
"""Harden generated Android release builds against WorkManager/Room R8 crashes.

The Android directory is regenerated in CI, so this patch must run after
`flutter create` and after the normal Android configuration script.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
PROGUARD = ROOT / "android" / "app" / "proguard-rules.pro"

KEEP_RULES = """
# WorkManager creates its Room database implementation through reflection.
# Keep the generated database constructor and related AndroidX classes if
# code shrinking is re-enabled in a future build.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
}
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
""".strip() + "\n"


def patch_gradle() -> None:
    if not GRADLE.exists():
        raise SystemExit("Missing android/app/build.gradle.kts; run flutter create first.")

    text = GRADLE.read_text(encoding="utf-8")
    release_pattern = r"(buildTypes\s*\{\s*release\s*\{)"
    if not re.search(release_pattern, text):
        raise SystemExit("Could not locate the Android release buildType.")

    if "isMinifyEnabled = false" not in text:
        replacement = (
            r"\1\n"
            "            // WorkManager/Room uses reflective generated constructors.\n"
            "            // R8 removed WorkDatabase_Impl.<init>() on affected devices.\n"
            "            isMinifyEnabled = false\n"
            "            isShrinkResources = false\n"
            "            proguardFiles(\n"
            "                getDefaultProguardFile(\"proguard-android-optimize.txt\"),\n"
            "                \"proguard-rules.pro\",\n"
            "            )"
        )
        text = re.sub(release_pattern, replacement, text, count=1)

    GRADLE.write_text(text, encoding="utf-8")
    PROGUARD.write_text(KEEP_RULES, encoding="utf-8")

    verified = GRADLE.read_text(encoding="utf-8")
    if "isMinifyEnabled = false" not in verified:
        raise SystemExit("Release minification safety setting was not applied.")
    if "WorkDatabase_Impl" not in PROGUARD.read_text(encoding="utf-8"):
        raise SystemExit("WorkManager keep rules were not written.")


def main() -> None:
    patch_gradle()
    print("Disabled release shrinking and installed WorkManager/Room keep rules.")


if __name__ == "__main__":
    main()
