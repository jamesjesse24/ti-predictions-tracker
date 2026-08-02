#!/usr/bin/env python3
"""Apply Android resources and native services after `flutter create`."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_MAIN = ROOT / "android" / "app" / "src" / "main"
RES = ANDROID_MAIN / "res"
MANIFEST = ANDROID_MAIN / "AndroidManifest.xml"
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
JAVA_PACKAGE = ANDROID_MAIN / "java" / "com" / "jamesjesse24" / "ti_predictions_tracker"
KOTLIN_ROOT = ANDROID_MAIN / "kotlin"


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
        android:fillColor="#FFFFFFFF"
        android:pathData="M6.5,7.2 L17.5,7.2 L17.5,9.7 L13.4,9.7 L13.4,17 L10.6,17 L10.6,9.7 L6.5,9.7 Z" />
</vector>
"""
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


def configure_native_background_worker() -> None:
    if KOTLIN_ROOT.exists():
        for source in KOTLIN_ROOT.rglob("MainActivity.kt"):
            source.unlink()

    write(
        JAVA_PACKAGE / "MainActivity.java",
        r"""
package com.jamesjesse24.ti_predictions_tracker;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class MainActivity extends FlutterActivity {
    private static final String CHANNEL =
            "com.jamesjesse24.ti_predictions_tracker/background";
    private static final String WORK_NAME =
            "ti-background-results-periodic";
    private static final String PREFS = "ti_native_result_worker";
    private static final String KEY_ENABLED = "enabled";
    private static final String KEY_SEEN = "seen_series";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler(this::handleBackgroundCall);
    }

    private void handleBackgroundCall(MethodCall call, MethodChannel.Result result) {
        try {
            if ("enable".equals(call.method)) {
                List<String> ids = call.argument("seriesIds");
                enableBackgroundChecks(ids);
                result.success(true);
            } else if ("disable".equals(call.method)) {
                disableBackgroundChecks();
                result.success(true);
            } else {
                result.notImplemented();
            }
        } catch (Exception error) {
            result.error(
                    "background_worker_error",
                    error.getMessage(),
                    null
            );
        }
    }

    private void enableBackgroundChecks(List<String> baselineIds) {
        SharedPreferences preferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit().putBoolean(KEY_ENABLED, true);
        if (baselineIds != null) {
            Set<String> baseline = new HashSet<>(baselineIds);
            editor.putStringSet(KEY_SEEN, baseline);
        }
        editor.apply();

        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        PeriodicWorkRequest request = new PeriodicWorkRequest.Builder(
                TiResultWorker.class,
                15,
                TimeUnit.MINUTES
        ).setConstraints(constraints).build();

        WorkManager.getInstance(getApplicationContext())
                .enqueueUniquePeriodicWork(
                        WORK_NAME,
                        ExistingPeriodicWorkPolicy.UPDATE,
                        request
                );
    }

    private void disableBackgroundChecks() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, false)
                .apply();
        WorkManager.getInstance(getApplicationContext())
                .cancelUniqueWork(WORK_NAME);
    }
}
""",
    )

    write(
        JAVA_PACKAGE / "TiResultWorker.java",
        r"""
package com.jamesjesse24.ti_predictions_tracker;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class TiResultWorker extends Worker {
    private static final String FEED_URL =
            "https://raw.githubusercontent.com/jamesjesse24/ti-predictions-tracker/main/data/live.json";
    private static final String PREFS = "ti_native_result_worker";
    private static final String KEY_ENABLED = "enabled";
    private static final String KEY_SEEN = "seen_series";
    private static final String CHANNEL_ID = "ti_result_updates";

    public TiResultWorker(
            @NonNull Context appContext,
            @NonNull WorkerParameters workerParams
    ) {
        super(appContext, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        SharedPreferences preferences =
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (!preferences.getBoolean(KEY_ENABLED, false)) {
            return Result.success();
        }

        HttpURLConnection connection = null;
        try {
            URL url = new URL(FEED_URL + "?t=" + System.currentTimeMillis());
            connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(15000);
            connection.setReadTimeout(20000);
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/json");
            connection.setRequestProperty("Cache-Control", "no-cache");
            connection.setRequestProperty(
                    "User-Agent",
                    "ti-predictions-tracker/android"
            );

            int status = connection.getResponseCode();
            if (status != HttpURLConnection.HTTP_OK) {
                return Result.retry();
            }

            String body = readFully(connection.getInputStream());
            JSONObject root = new JSONObject(body);
            JSONArray series = root.optJSONArray("series");
            if (series == null) {
                return Result.success();
            }

            Set<String> currentIds = new HashSet<>();
            List<JSONObject> completed = new ArrayList<>();
            for (int index = 0; index < series.length(); index++) {
                JSONObject item = series.optJSONObject(index);
                if (item == null || !item.optBoolean("completed", false)) {
                    continue;
                }
                String id = item.optString("id", "").trim();
                if (id.isEmpty()) continue;
                currentIds.add(id);
                completed.add(item);
            }

            Set<String> stored = preferences.getStringSet(KEY_SEEN, null);
            if (stored == null) {
                saveSeen(preferences, currentIds);
                return Result.success();
            }

            Set<String> seen = new HashSet<>(stored);
            List<JSONObject> fresh = new ArrayList<>();
            for (JSONObject item : completed) {
                if (!seen.contains(item.optString("id", ""))) {
                    fresh.add(item);
                }
            }

            if (!fresh.isEmpty()) {
                postNotification(context, fresh);
            }
            saveSeen(preferences, currentIds);
            return Result.success();
        } catch (SecurityException permissionError) {
            return Result.success();
        } catch (Exception networkOrParseError) {
            return Result.retry();
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private static String readFully(InputStream stream) throws Exception {
        StringBuilder value = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(stream, StandardCharsets.UTF_8)
        )) {
            String line;
            while ((line = reader.readLine()) != null) {
                value.append(line);
            }
        }
        return value.toString();
    }

    private static void saveSeen(
            SharedPreferences preferences,
            Set<String> ids
    ) {
        preferences.edit()
                .putStringSet(KEY_SEEN, new HashSet<>(ids))
                .apply();
    }

    private static void postNotification(
            Context context,
            List<JSONObject> fresh
    ) {
        JSONObject latest = fresh.get(fresh.size() - 1);
        String winner = latest.optString("winner", "").trim();
        String title = fresh.size() == 1
                ? (winner.isEmpty() ? "New TI result" : "TI result: " + winner + " wins")
                : fresh.size() + " new TI results";
        String body = fresh.size() == 1
                ? seriesLine(latest)
                : seriesLine(fresh.get(0)) +
                    (fresh.size() > 1 ? " • " + seriesLine(latest) : "");

        NotificationManager manager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "TI result updates",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription(
                    "Completed series, standings changes, and prediction results."
            );
            manager.createNotificationChannel(channel);
        }

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(context, CHANNEL_ID)
                : new Notification.Builder(context);
        builder.setSmallIcon(R.drawable.ic_stat_ti)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_STATUS)
                .setGroup("ti_2026_results");

        Intent launchIntent = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                    context,
                    2026,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            builder.setContentIntent(pendingIntent);
        }

        int notificationId = (int) (System.currentTimeMillis() & 0x7fffffff);
        manager.notify(notificationId, builder.build());
    }

    private static String seriesLine(JSONObject item) {
        return item.optString("teamA", "Unknown") + " " +
                item.optInt("scoreA", 0) + "–" +
                item.optInt("scoreB", 0) + " " +
                item.optString("teamB", "Unknown") + " • " +
                item.optString("stage", "Group stage");
    }
}
""",
    )


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

    dependencies = [
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
        'implementation("androidx.work:work-runtime:2.11.2")',
    ]
    for dependency in dependencies:
        if dependency in text:
            continue
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
        raise SystemExit(
            "Run `flutter create . --platforms=android` before this script."
        )
    configure_icons()
    configure_manifest()
    configure_native_background_worker()
    configure_gradle()
    print(
        "Configured launcher assets, network permissions, and native Android result worker."
    )


if __name__ == "__main__":
    main()
