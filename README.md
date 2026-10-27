# PantryLens

PantryLens is an Android pantry inventory app built with Flutter.
Scan a product barcode to add it to your pantry, look up its name and image with
Open Food Facts, and keep inventory quantities in a local SQLite database.

## Features

Local-first tools for pantry inventory and household planning.

- Independent product batches, fractional amounts (g, kg, ml, l, pieces and
  bottles), oldest-first usage, opened-package expiry, tags and categories
- Multiple homes, custom storage locations, location/category filters and moving
  batches between homes or locations
- Minimum-stock rules that generate shopping entries, purchase prices and stores,
  pantry value, expiry-specific losses, partial waste with reasons, monthly usage,
  most-used and most-wasted products
- Camera/library OCR for printed dates and receipts, with review before saving;
  manual corrections for names, photos, ingredients and allergens
- Open Food Facts API v2 with Open Products Facts fallback, nutrition per 100 g,
  household allergy warnings and persistent offline product photos
- Local expiry notifications, individual reminders or daily digests, configurable
  reminder time and quiet hours; Use soon and Shopping home screen widgets
- Shopping by aisle, system sharing, purchase history and event ingredient lists
- Assigned staff checklists with due dates and photos; guest/household dietary
  profiles, allergies and favorites; meal/event planning and an activity log
- Three-step onboarding with an optional sample pantry, tablet navigation and a
  two-pane inventory, large-text layouts, labelled controls and retry states
- Local diagnostic logging, optional Sentry crash reporting and paged inventory
  queries

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
names, amounts, units and prices. Review and edit each suggested line, add missed
items, exclude unwanted lines, choose a home and set a shared expiry before import.
The parser accepts dot/comma prices, tax flags, wrapped item names, separate
quantity/price lines and weighted items; receipt formats vary, so review is required.
Ambiguous printed dates offer both interpretations. Month-only dates use the last
day of that month.

**Record as wasted** in a batch lets you enter a partial amount and a reason:
past expiry, spoiled/damaged, or another reason. **Usage & waste** separates
actual expiry losses from current expired stock value. History from before
schema v5 keeps its waste total with an unspecified reason rather than guessing
the cause. Reports aggregate the full history across the selected home or all homes.

Households are stored on this device. Shopping lists are shared as messages
through the system share sheet. Inventory JSON exports preserve batches and all
their fields and accept older v1 exports; they are inventory exports, rather
than backups of tasks, guest profiles, activity, settings or local photo files.
There is no account service or automatic cross-device synchronization.
Replacing an inventory affects the selected home; choose **All homes** to replace
the combined inventory. Bulk imports and removals record the current operator
in the activity log in the same database transaction.

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

Android needs the Android SDK and an emulator or device with camera support.
In Android Studio's SDK Manager, install the Android SDK Platform and
Android SDK Command-line Tools, then accept Android licenses with
`flutter doctor --android-licenses`. Camera permission declarations are
included in the native platform projects. Open Food Facts lookups require an
internet connection.

Check formatting, analyze the app and build an Android APK:

```sh
dart format --output=none --set-exit-if-changed lib
flutter analyze
flutter build apk --debug
```

Inventory queries use indexed fields, bounded pages and debounced search.
Tabs load on first use, and usage reports aggregate the complete stored history.
Pull requests run formatting checks, static analysis and an Android debug build.
The release workflow analyzes the app before building signed Android artifacts.

## Notifications, widgets and diagnostics

Enable **Expiry reminders** in Settings to request notification permission.
Quiet hours defer a reminder to their end; equal start/end hours disable quiet
hours. Daily digests are scheduled 30 days ahead, individual reminders use the
earliest 60 upcoming batches to respect platform limits, and schedules refresh
on inventory/settings changes and when the app resumes. Android uses inexact
alarms, so delivery may be delayed by the OS. Reopen the app periodically to
refresh the schedule. Both home screen widgets show their last refresh time;
open the app to update their snapshots.

Android widgets are registered in the manifest. Add **Use soon** or **Shopping**
from the launcher's widget picker and resize to show more rows.

Errors are appended to the app's bounded local diagnostic log across restarts,
viewable under
**Settings → Diagnostics**. To enable remote crash reporting for your own
Sentry project, build with `--dart-define=SENTRY_DSN=<your-dsn>`. No remote
reporting is initialized without a DSN. **Run diagnostic check** records an
intentional non-fatal event so a configured project can confirm delivery. Set
the optional `SENTRY_DSN` Actions secret to include it in automated Android releases.
Sentry 9 is retained for Android 7 compatibility, with project-level
Kotlin/compile-SDK compatibility settings.
Product and shopping photos for every home download in the background, with
two bounded downloads at once and an 8 MB per-photo limit. Saved photos live in
application support rather than the temporary image cache and are reused after
restarts without contacting the server. **Settings → Offline photos** shows
progress, missing downloads and a retry action. A corrected photo picked from
the library is copied to the app's documents directory.

## Contributing

After setting up the development environment above, create a feature branch,
make and format your changes, then run `flutter analyze` and check the app on
an Android emulator or device. Open a pull request against `main` with a short
summary of the change and any relevant screenshots. Debug builds do not require
the Android release signing key.

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
android/                 Android project and release signing configuration
.github/workflows/       Analysis, Android build checks and signed releases
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

The workflow builds Android APK and AAB artifacts.
