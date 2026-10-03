# PantryLens

PantryLens is a native Android and iOS pantry inventory app built with Flutter.
Scan a product barcode to add it to your pantry, look up its name and image with
Open Food Facts, and keep inventory quantities in a local SQLite database.

## Features

- Barcode scanning with the device camera, flashlight and camera switching, and
  manual barcode entry
- Open Food Facts product lookup when an item is first scanned
- Home overview of items to use soon, expired items, and recent additions
- Inventory with search, filters, sorting, quantity controls, and editable
  names and best-before dates
- Shopping list that collects used-up items with their photos, has quantity
  controls and editable names, and checks items off when they are rescanned
- Full-screen product photos with pinch and double-tap zoom
- Export of the inventory to a JSON file, and import that merges into or
  replaces the current inventory
- Settings for light, dark, or system theme, default best-before period,
  use-soon warnings, product lookup, continuous scanning, and haptics
- Material 3 interface and a custom PantryLens launcher icon

The inventory database stays on the device. Open Food Facts is contacted when a
new barcode is scanned and product lookup is on; existing items can be
incremented without a product lookup.

## Technology

- Flutter and Dart
- Provider for app state
- SQLite through `sqflite` and `path_provider`
- `mobile_scanner` for barcode scanning
- `http` for the Open Food Facts API
- `file_picker` for the system dialogs that save and open inventory exports
- `shared_preferences` for settings and `package_info_plus` for the app version

## Requirements

- Flutter SDK 3.47.0 (stable) and Dart from the matching Flutter SDK
- Android Studio with the Android SDK Platform and Android SDK Command-line Tools
- Xcode on macOS for iOS development
- A physical device or emulator for camera scanning

## Set up a development machine

Clone the repository from GitHub and open its project folder. From the project
root, install the Flutter packages and generate platform icon assets:

```sh
flutter pub get
dart run flutter_launcher_icons
```

Check the available devices and run the app:

```sh
flutter devices
flutter run -d <device-id>
```

Android needs the Android SDK and an emulator or device with camera support. For
iOS, use macOS with Xcode installed, then select an iOS simulator or connected
device. In Android Studio's SDK Manager, install the Android SDK Platform and
Android SDK Command-line Tools, then accept Android licenses with
`flutter doctor --android-licenses`. Camera permission declarations are
included in the native platform projects. Open Food Facts lookups require an
internet connection.

To run static analysis and the device integration checks:

```sh
flutter analyze
flutter test integration_test/pantrylens_smoke_test.dart -d <device-id>
```

The integration checks cover inventory insertion and increments, tab
navigation, quantity controls, switching to dark mode, scanner navigation,
editing a shopping list entry, the inventory export format and import, and
parsing an Open Food Facts response. The API parsing check uses
a mock HTTP client so it remains deterministic and does not depend on emulator
DNS or external service availability.

## Contributing

After setting up the development environment above, create a feature branch,
make and format your changes, then run `flutter analyze` and the integration
checks on an emulator or device. Open a pull request against `main` with a short
summary of the change and any relevant screenshots. Debug development and
integration tests do not require the Android release signing key.

## Project structure

```text
lib/
  api_service.dart       Open Food Facts client
  app_theme.dart         Light and dark themes and freshness colors
  database_helper.dart   SQLite database access
  inventory_backup.dart  JSON format for inventory export and import
  main.dart              App entry point and providers
  pantry_actions.dart    Shared flows: item editing, undo, manual entry,
                         export and import
  pantry_item.dart       Inventory data model
  pantry_provider.dart   Inventory, shopping list, and scan handling
  settings_provider.dart Persisted app settings
  shopping_item.dart     Shopping list data model
  screens/               Tab shell, Home, Inventory, Shopping, Settings,
                         item editors, photo viewer, and scanner
  widgets/               Shared widgets
assets/
  icon.png               Launcher icon source image
integration_test/        Device integration checks
android/                 Android project and release signing configuration
ios/                     iOS project
.github/workflows/       Automated Android release workflow
```

## Android signing key

The Android release key is `pantrylens-release-key.jks` in the project root.
Its local Gradle credentials are in `android/key.properties`. Both files are
ignored by Git because the private signing key must not be published.
The signing certificate's SHA-256 fingerprint is
`386ef053234ac3abca75345a28e28f80fd0b8815ad0b78a4e1be78cfd418342c`; compare it
with `keytool -list -v -keystore pantrylens-release-key.jks -alias pantrylens-release`
after transferring a backup to verify that it is the same key.

Keep secure backups of the `.jks` file and its passwords in at least two places
you control, such as an encrypted password manager and encrypted offline
storage. Anyone who gets the key and passwords can sign app builds as PantryLens;
losing them prevents signing updates that Android recognizes as updates to the
same installed app.

To set up another development machine, transfer `pantrylens-release-key.jks`
over a secure channel and place it in the repository root. Create
`android/key.properties` with the same alias and passwords:

```properties
storeFile=../pantrylens-release-key.jks
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=pantrylens-release
```

Do not add either file to Git, issues, pull requests, or chat. For local signed
Android builds, use `flutter build apk --release` or
`flutter build appbundle --release` after setting up these files.

## GitHub releases

Every source push to `main` runs the release workflow. It increments the patch
version in `pubspec.yaml`, increments the Android build number, builds a signed
APK and Android App Bundle, pushes the version bump and a `vX.Y.Z` tag, then
publishes a GitHub Release titled `PantryLens vX.Y.Z` with both Android
artifacts attached. For example, the first release after `1.0.0+1` is
`PantryLens v1.0.1`. The workflow's own version commit does not start another
release run.

Configure these repository Actions secrets before enabling releases:

- `ANDROID_KEYSTORE_BASE64`: base64 encoding of the root
  `pantrylens-release-key.jks` file
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: `pantrylens-release`
- `ANDROID_KEY_PASSWORD`: private key password

On PowerShell, copy the base64 value to the clipboard without printing the key
contents in the terminal:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("pantrylens-release-key.jks")) | Set-Clipboard
```

Paste it directly into the `ANDROID_KEYSTORE_BASE64` Actions secret. Set the
other three secrets in the repository's **Settings → Secrets and variables →
Actions** page. Keep the original key and the passwords backed up separately
from GitHub. The workflow needs permission to write repository contents and to
push its version commit and tag to `main`; branch protection must allow this
release automation to update `main`.

The workflow builds Android APK and AAB artifacts. iOS builds require macOS and
Xcode and are not produced by this Android release workflow.
