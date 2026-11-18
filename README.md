# REDLINE Camera — Starter

This is the initial Flutter application shell for REDLINE Camera.

## Current starter functionality
- Flutter Android/iOS application shell
- Live camera preview through Flutter's camera plugin
- Back/front camera switching
- Still image capture
- Local save to the app's REDLINE folder
- Minimal dark camera interface

## Not implemented yet
This is an implementation starter, not a finished professional camera. It does not yet implement RED IPP2, RAW/DNG capture, manual Camera2/AVFoundation controls, HDR fusion, device calibration, waveform monitoring, or the shared GPU colour engine.

## Requirements
- Flutter stable SDK
- Android Studio / Android SDK
- Xcode and macOS for iOS builds
- Physical devices for meaningful camera testing

## Setup
1. Install Flutter.
2. Extract this project.
3. Run `flutter create .` to generate platform folders.
4. Run `flutter pub get`.
5. Run `flutter run` on a physical Android or iOS device.

For iOS, build and sign through Xcode on macOS. Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`. For Android, ensure the generated manifest includes camera permission. The camera plugin handles runtime permission requests.

## First engineering task
Replace the initial generic capture path with platform capability adapters:
- Android: query CameraManager / CameraCharacteristics and expose a normalized capability report.
- iOS: query AVCaptureDevice discovery sessions and activeFormat capabilities.

## Browser version (GitHub Pages)
`index.html` (with `sw.js` and `manifest.webmanifest`) is a standalone browser build of the camera: live preview, lens switch, capture to downloads.
It is served by GitHub Pages from the repository root at https://wyngaardr-sys.github.io/redline-camera/ .
Browsers only allow the camera on https:// or localhost. After the first visit it works offline, and Chrome can install it via "Add to Home screen".

The Flutter app source is in `lib/main.dart`; architecture notes are in `ARCHITECTURE.md`.
