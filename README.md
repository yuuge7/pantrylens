# PantryLens

PantryLens is a native Android and iOS pantry inventory app built with Flutter.
Scan a product barcode to add it to your pantry, look up its name and image with
Open Food Facts, and keep inventory quantities in a local SQLite database.

## Features

The `ideas.md` roadmap is implemented as local-first household tools:

- Independent product batches, fractional amounts (g, kg, ml, l, pieces and
  bottles), oldest-first usage, opened-package expiry, tags and categories
- Multiple homes, custom storage locations, location/category filters and moving
  batches between homes or locations
- Minimum-stock rules that generate shopping entries, purchase prices and stores,
  pantry value, recorded waste, monthly usage and most-used products
- Camera/library OCR for printed dates and receipts, with review before saving;
  manual corrections for names, photos, ingredients and allergens
- Open Food Facts API v2 with Open Products Facts fallback, nutrition per 100 g,
  household allergy warnings and persistent product-photo caching
- Local expiry notifications, individual reminders or daily digests, configurable
  reminder time and quiet hours; Use soon and Shopping home screen widgets
- Shopping by aisle, system sharing, purchase history and event ingredient lists
- Assigned staff checklists with due dates and photos; guest/household dietary
  profiles, allergies and favorites; meal/event planning and an activity log
- Three-step onboarding with an optional sample pantry, tablet navigation and a
  two-pane inventory, large-text layouts and labelled controls
- Local diagnostic logging and optional Sentry crash reporting, schema migration
  tests, model/provider/backup tests, PR checks and paged inventory queries

Use the home menu to select a property or **All homes**. The **+** menu adds a
batch, enters a barcode or scans a receipt. Open a batch to set its location,
amount, opening date, restock threshold and purchase price. The home menu's
**Manage household** opens tasks, guest profiles, events and activity. **Usage &
waste** is available from Home and Settings. Set the operator's name in Settings
before staff use the device; activity records that local name.

Barcode scans add to a matching unopened batch only when its home, default
location, unit and best-before date match. **Add a batch** always makes an
independent batch. Usage consumes the earliest effective expiry first within
the chosen home and unit. Stock thresholds are per product, home and unit and
continue working after the last batch is used. Receipt OCR supplies suggested
names, amounts and prices; verify the lines and edit each batch's expiry after
import. Ambiguous printed dates offer both interpretations for review.

Households are stored on this device. Shopping lists are shared as messages
through the system share sheet. Inventory JSON exports preserve batches and all
their fields and accept older v1 exports; they are inventory exports, rather
than backups of tasks, guest profiles, activity, settings or local photo files.
There is no account service or automatic cross-device synchronization.

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
flutter test
flutter test integration_test/pantrylens_smoke_test.dart -d <device-id>
flutter test integration_test/roadmap_test.dart -d <device-id>
```

The integration checks cover inventory insertion and increments, tab
navigation, quantity controls, switching to dark mode, scanner navigation,
editing a shopping list entry, the inventory export format and import, and
parsing an Open Food Facts response. The API parsing check uses
a mock HTTP client so it remains deterministic and does not depend on emulator
DNS or external service availability.

The roadmap integration suite also runs native ML Kit recognition against a
generated package/receipt image, receipt review/import, household checklists,
batch/FIFO behavior, widget data, notification scheduling/cancellation and a
5,000-batch browsing check with frame timing measurements. Unit tests cover migrations from schema versions
1, 2 and 3, partial amounts, opening dates, idempotent imports, atomic invalid
imports, concurrent stock changes, minimum-stock rules, dietary profiles,
receipt/date parsing, event unit conversions and quiet hours. UI tests exercise
phone, large-text, tablet and landscape sizes.

Inventory reads are limited to 60 rows per page (hard maximum 200), with lazy
row rendering, indexed home/name/barcode/expiry fields and debounced search.
The automated budget allows under one second for a 60-row emulator database
query against 5,000 batches and under 15 seconds for the complete host fixture
insertion and paging test. Capture scroll performance in profile mode for a
release decision; debug traces include instrumentation overhead. Cold-start
target: under two seconds to a usable first screen on a current device. Scroll
target: 60 fps on a 60 Hz display; these are device performance targets rather
than guarantees from host unit tests.

The local Android 17/API 37 emulator profile run measured a 3.907-second cold
Activity launch and 762 ms from Dart entry to its first frame. A 60-row read from
5,000 batches took 17.135 ms. The physical-device two-second cold-start target
still needs device validation. Tabs mount on first use, startup reads use one
consistent database batch, and usage reports aggregate the complete stored
history independently of the activity feed's display limit.

Build with `--dart-define=PROFILE_STARTUP=true` to print Dart startup milestones
to the device log. The default build leaves this instrumentation off.

For a full VM timeline on a physical device, run
`flutter drive --profile --no-dds -d <device-id> --driver=test_driver/integration_test.dart --target=integration_test/roadmap_test.dart --dart-define=CAPTURE_TIMELINE=true`.
The driver writes measurements to `build/integration_response_data.json`.

## Notifications, widgets and diagnostics

Enable **Expiry reminders** in Settings to request notification permission.
Quiet hours defer a reminder to their end; equal start/end hours disable quiet
hours. Daily digests are scheduled 30 days ahead, individual reminders use the
earliest 60 upcoming batches to respect platform limits, and schedules refresh
on inventory/settings changes and when the app resumes. Android uses inexact
alarms, so delivery may be delayed by the OS. Reopen the app periodically to
refresh the schedule. Both home screen widgets show their last refresh time;
open the app to update their snapshots.

Android widgets are registered in the manifest. iOS includes an embedded
WidgetKit extension with both widgets. On a Mac, enable the App Group
`group.com.pantrylens.pantrylens` for the Runner and PantryLensWidgets targets
in your Apple Developer provisioning profiles. ML Kit requires iOS 15.5 or
newer. iOS compilation and signing require Xcode and must be verified on macOS.

Errors are recorded in the app's bounded local diagnostic log, viewable under
**Settings → Diagnostics**. To enable remote crash reporting for your own
Sentry project, build with `--dart-define=SENTRY_DSN=<your-dsn>`. No remote
reporting is initialized without a DSN. Sentry 9 is retained for Android 7
compatibility, with project-level Kotlin/compile-SDK compatibility settings.
Photo cache contents may be evicted by the OS; a corrected photo picked from
the library is copied to the app's documents directory.

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
  features/              Adding/OCR, household planning, inventory paging,
                         insights and onboarding
  services/              Diagnostics, notifications, widget snapshots and
                         application lifecycle synchronization
  widgets/               Shared widgets
assets/
  icon.png               Launcher icon source image
integration_test/        Device integration checks
test/                    Model, provider, backup, migration and UI tests
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
