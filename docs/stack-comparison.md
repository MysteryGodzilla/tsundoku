# App stack: Expo (React Native) or Flutter

Compared 2026-11-14 against what Tsundoku needs. Library facts are from each project's docs on that
date; anything marked *verify* is to be confirmed in the Phase 0 spike.

## What matters for this app
1. A native-feeling Android app (Phase 1), iPhone later from the same code.
2. Barcode scanning on the phone **and** on a desktop webcam, not tied to one browser's built-in
   detector (a product rule).
3. A local database that works offline on the phone **and** in a desktop browser (Phase 4).
4. Passkeys with the PRF extension, for library recovery on a new phone.
5. Fingerprint/face/PIN app lock.
6. A calm, custom look: neutral palette, one soft accent, light and dark.

## Side by side

| Need | Expo (React Native, TypeScript) | Flutter (Dart) |
|---|---|---|
| Android app | Native components; very mature | Draws its own widgets; very mature |
| Phone scanning | `expo-camera` with ML Kit; good | `mobile_scanner` with ML Kit; good |
| Desktop webcam scanning | `expo-camera` on web relies on the browser's Barcode Detection API, which the brief rules out as the only path (and it's missing on Windows desktop browsers, *verify*); needs a separate ZXing integration written by us | `mobile_scanner` on web uses ZXing (zxing-wasm fallback); Chrome and Edge 83+, Safari 17+, not Firefox |
| Offline database in a browser | `expo-sqlite` on web is **alpha** ("may be unstable"); needs Metro wasm config and special HTTP headers | `drift` on web uses SQLite wasm with OPFS; mature, actively fixed |
| Desktop alternative | Browser only | Can also build a real Windows app, sidestepping browser camera limits |
| Passkey PRF | `react-native-passkey` 3.3+ documents PRF on Android and iOS 18+; the more established option | `passkeys` (Corbado) and `flutter_passkey_service` document PRF; `maktub_passkey` is pre-release. Fewer users |
| App lock | `expo-local-authentication` | `local_auth` |
| Custom look | Styling by hand or a UI kit | Material 3 theming from one seed colour; light/dark built in. Same look on every platform |
| Server language | TypeScript, same as the app | Dart (`shelf`) to stay one language, or Node/TypeScript |
| Tools needed here | Node 26 (installed), Android SDK and a JDK (not installed) | Flutter SDK, Android SDK and a JDK (none installed) |
| Web download size | Smaller | Larger first load (a few MB); fine once cached as a PWA |

## Verdict (recommendation)
For Phases 1 to 3 (phone only) the two are about even. The difference is Phase 4: Flutter's web
scanning and browser database are mature, while Expo's are alpha or would need our own work. So
**Flutter is recommended**, with a Dart server to keep one language. Expo stays the fallback if the
Phase 0 spike finds Flutter's passkey PRF support doesn't work on her phone.

## Sources
- [Expo SQLite docs](https://docs.expo.dev/versions/latest/sdk/sqlite.md) (web support alpha)
- [Expo Camera docs](https://docs.expo.dev/versions/latest/sdk/camera.md) and
  [expo-camera web scanner source](https://cdn.jsdelivr.net/npm/expo-camera@55.0.9/src/web/WebBarcodeScanner.ts)
- [react-native-passkey](https://github.com/getclave/react-native-passkey) (PRF 3.3+)
- [mobile_scanner](https://pub.dev/packages/mobile_scanner) (web via ZXing)
- [drift on the web](https://drift.simonbinder.eu/web/) (SQLite wasm, OPFS)
- [passkeys (Corbado)](https://pub.dev/packages/passkeys),
  [flutter_passkey_service](https://pub.dev/documentation/flutter_passkey_service),
  [maktub_passkey](https://pub.dev/packages/maktub_passkey)
