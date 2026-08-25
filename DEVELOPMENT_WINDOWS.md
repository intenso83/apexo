# Building Apexo on Windows

This fork is tested with Flutter 3.38.1. Using the pinned version avoids
unrequested project migrations from newer Flutter releases.

## Required tools

- Flutter 3.38.1
- Android Studio and Android SDK Platform 36
- Java 17 (configure it with `flutter config --jdk-dir <JAVA_17_FOLDER>`)
- Rust stable (`rustup`, `rustc`, and `cargo`)
- Visual Studio Build Tools with **Desktop development with C++**, including
  the MSVC x64/x86 build tools and a Windows 11 SDK

Run `flutter doctor -v` after installing the tools. Flutter may incorrectly
report that Android licenses are not accepted when Android SDK Command-line
Tools v23 or newer is installed; a successful Gradle build is the definitive
check.

## Build a debug Android APK

From the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_debug.ps1
```

The script loads the Visual C++ environment needed by the Rust/DICOM package,
bypasses Flutter's current
[Windows launcher typo](https://github.com/flutter/flutter/issues/187907),
then builds Apexo with the pinned Flutter tool. The APK is written to:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Optional Sentry configuration

The project builds without a private Sentry key. A release maintainer can
provide one at compile time without committing it:

```powershell
flutter build apk --release --dart-define=SENTRY_DSN=<PRIVATE_DSN>
```

Never commit secrets, real patient information, or DentalWin exports.
