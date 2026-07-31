# Live sync diagnosis

The release APK was generated from Flutter's Android template. Internet access exists in the debug/profile manifests, but the generated main release manifest did not receive `android.permission.INTERNET` or `android.permission.ACCESS_NETWORK_STATE` from the project configuration script.

As a result, the release app could open but every HTTP request to `data/live.json` failed. `TrackerController.lastUpdated` therefore remained null and the interface continued to show `Not synced yet`.

The Android configuration script now injects both permissions into the release manifest, and CI verifies their presence before building the APK.
