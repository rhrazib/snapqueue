# Android setup

The `android/` folder is produced by `flutter create`; these are the only edits.

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

`android/app/build.gradle(.kts)`:

```
minSdk = 24
```
