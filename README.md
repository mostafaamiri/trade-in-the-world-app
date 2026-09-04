# Trade in the World

Flutter source reconstruction for the Android game "تجارت در جهان".

The original source directory was deleted. This repository was reconstructed
from the released APK's public assets, configuration, Android metadata, and
the running game's backend contract. Flutter AOT binaries do not contain the
original Dart source, so this is a maintainable rebuild rather than a byte-for-byte
recovery of the deleted project.

## Build

```powershell
flutter pub get
flutter analyze
flutter build apk --release
```

The release APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android

- Application ID: `com.tradearoundworld.trade_around_the_world`
- Minimum Android version: 7.0 (API 24)
- Target Android version: 14 (API 34)
- Version: `0.4.0+29`

The app uses the existing public game API at `https://mojtabaamiri.ir/api` and
includes Firebase Cloud Messaging configuration for notifications.
