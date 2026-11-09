# Did I Tell You?

[![CI](https://github.com/Sanjay1318/Did_I_Tell_You/actions/workflows/ci.yml/badge.svg)](https://github.com/Sanjay1318/Did_I_Tell_You/actions/workflows/ci.yml)

**Did I Tell You?** is a private, local-first memory assistant built with Flutter. It runs as an Android app, an iOS app and a web app. You tell it something once ("I lent Rahul ₹500", "parked at Forum Mall", "I'll send the resume tomorrow") and ask for it back later in plain language.

Everything stays on your device (or in your browser for the web version). There is no account, server, analytics or internet connection needed to save and search memories.

## Contents

- [Features](#features)
- [How data is handled](#how-data-is-handled)
- [Screens](#screens)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Free hosting](#free-hosting)
- [Testing](#testing)
- [Database and backups](#database-and-backups)
- [Release checklist](#release-checklist)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)

## Features

### Capture and organize

- Save memories by typing, by speech-to-text, or with a photo from the camera or gallery.
- Add comma-separated tags, pin important memories, and archive or restore old ones.
- Edit a memory's text and correct the detected person, amount, date, location and category by hand.
- A warning appears if a new memory looks like a duplicate of, or contradicts, an existing one.
- Delete one memory or everything.

### Automatic understanding (rule-based, on the device)

- Detects people, amounts, dates, locations, keywords and one of ten categories: General, Money, People, Events, Purchases, Places, Entertainment, Work, Education and Important.
- Recognises commitments such as `I'll send the resume tomorrow` and turns them into pending follow-ups.
- Editing the wording of a completed follow-up keeps it completed; removing the commitment from the text clears it.

### Search and questions

- Ask questions such as "who owes me", "what do I know about Priya", "where did I park", "what happened yesterday" or "last week".
- Questions that are not word for word in a memory still work: "where did I put my keys" matches on the meaningful words, ignores filler words, matches plurals, and ranks memories that match more words first.
- Written answers above the results, which can be read aloud.
- Filters for category, person, date range and minimum/maximum amount; sorting by newest, oldest or amount.
- Timeline, All memories, People and Archived views.

### Reminders and follow-ups

- Local notifications at a date and time you choose.
- **Snooze** a reminder for 1 hour, 3 hours or until 9:00 tomorrow.
- **Repeat** a reminder daily, weekly or monthly. A monthly reminder on the 31st falls on the last day of shorter months.
- Pending follow-ups are listed on the home screen; **overdue** ones come first with a warning marker.
- Money memories can be marked open or settled.

### Privacy, backup and appearance

- Optional app lock using the phone's own screen lock or biometrics.
- **Full JSON backup**: every memory (archived ones included) and its photos in one file. Older list-only backups can still be imported.
- **Import preview** before anything changes: how many memories are new, how many are already here and will be skipped, and how many photos are included. Imported reminders are scheduled again.
- CSV export for spreadsheets.
- Light and dark themes (the dark theme is a full theme, including the bottom bar), and a custom app icon with an Android adaptive version.

## How data is handled

Memories, settings, reminder state and attachments are stored on the device. The app has no login, cloud sync, telemetry, advertising SDK or remote AI requests.

Backups and exports contain personal information and photos. Share them only with trusted destinations. App lock hands the check to the device; the app stores no PIN, fingerprint or secret of its own. The database file itself is not encrypted.

## Screens

| Screen | What it does |
| --- | --- |
| Home | Greeting, "Ask your memory", quick capture, follow-ups (overdue first) and recent memories |
| Add memory | Text, voice, photo, tags, optional reminder, live preview of what was detected, duplicate warning |
| Search | Natural-language questions, filters, sorting, spoken answer |
| Timeline | Memories grouped by day |
| Memory detail | Edit, pin, archive, delete, tags, photos, follow-up status, reminder, snooze, repeat, settle money |
| Person | Everything about one person, with a category breakdown |
| All memories | Browse with category and person filters |
| Archived | Restore with a swipe |
| Settings | Dark mode, app lock, backup/import, CSV, delete all |

## Architecture

```text
Flutter UI (lib/screens, lib/widgets)
  -> Provider state: MemoryService, SettingsService
  -> Local services: extraction, duplicate detection, recurrence, reminders,
                     attachments, export/import
  -> SQLite (sqflite) and photo files in the app documents folder
```

```text
lib/
  app.dart, main.dart       app shell, light/dark theme, bottom navigation
  models/memory.dart        the Memory record and its database mapping
  services/
    memory_service.dart     state, search, follow-ups, reminders, import preview
    database_service.dart   SQLite schema, migrations, queries
    entity_extractor.dart   people, amounts, dates, locations, keywords
    category_classifier.dart, commitment_extractor.dart, duplicate_detector.dart
    search_answer.dart      written answers above search results
    recurrence.dart         daily / weekly / monthly reminder maths
    reminder_service.dart   on-device notifications
    export_service.dart     JSON backup (with photos), CSV, restore
    attachment_service.dart, settings_service.dart
  screens/, widgets/        UI
test/, integration_test/    automated tests
```

Understanding and search are heuristic, not machine-learning based. There is no vector index, cloud pipeline or account system.

## Getting started

### Prerequisites

- A current stable Flutter SDK.
- Android SDK for Android. The build asks for NDK 28.2.13676358 and Gradle installs it on first use.
- Xcode on a Mac for iOS.
- A physical phone for final checks of notifications, microphone, camera and device authentication.

### Run it

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter devices` lists the available devices.

## Free hosting

Both routes cost nothing and use only this GitHub repository.

### Web app on GitHub Pages

The web version is published automatically to `https://<your-user>.github.io/Did_I_Tell_You/` every time `main` changes (`.github/workflows/deploy-web.yml`).

One-time setup: **Settings -> Pages -> Build and deployment -> Source: GitHub Actions** (the repository must be public on the free plan). Then run the workflow once from the **Actions** tab, or merge to `main`.

The same `build/web` folder also works on Netlify, Cloudflare Pages, Vercel or any static host: build it with the commands below and upload the folder (set `--base-href "/"` when it is served from the root of a domain).

```sh
flutter pub get
dart run sqflite_common_ffi_web:setup   # downloads sqlite3.wasm into web/
flutter build web --release --base-href "/"
```

In the browser the data lives in that browser's own storage (IndexedDB), so clearing site data erases it; use **Export** for a backup. The web version does not have: notifications (reminders are saved but nothing is scheduled), app lock, or photo attachments. Backups from the web contain the memories without photos.

To try it locally: `dart run sqflite_common_ffi_web:setup` once, then `flutter run -d chrome`.

### Android APK on GitHub Releases

`.github/workflows/release-android.yml` builds an installable APK and attaches it to a GitHub Release. Run it from the **Actions** tab (**Release Android APK -> Run workflow**, version such as `v1.0.0`), or push a tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Download `did-i-tell-you.apk` from the Releases page and open it on an Android phone (allow "install unknown apps" for your browser). The APK is signed with the debug key, which is fine for installing directly but is not accepted by Google Play.

## Testing

Run everything with `flutter test`. Several hundred automated tests cover:

- **Database** (`test/database/`): create, read, update, delete, filters, search, ordering, persistence across restarts, and upgrades from schema versions 1 to 4 to the current one without losing data. They use SQLite on the development machine through `sqflite_common_ffi`, so no phone is needed.
- **Services** (`test/services/`): `MemoryService` (saving, duplicates, import/export, follow-ups, reminders, snooze and repeat, overdue rules, keyword search, pin and archive, day labels, questions), extraction, classification, recurrence maths, search answers, backup format and photo restore, settings and attachments. These use an in-memory fake database and a fake reminder service (`test/helpers/fakes.dart`).
- **Screens and widgets** (`test/widgets/`): home, add memory, search, memory detail, timeline, person, all memories, archived, settings, the memory card, follow-up actions, app lock, tab navigation and the light and dark themes.
- **End to end** (`integration_test/`): runs the real app on a phone or emulator: add a memory, find it by searching, and check it survives a restart. Run it with `flutter test integration_test`.

### Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and pull request:

1. Analyze and run all unit and widget tests (blocking).
2. Build a debug Android APK and an iOS build without code signing.
3. Run the integration test on an Android emulator. This job reports a result but does not block a merge, because emulators on CI can be flaky.

### Check by hand on a device

Automated tests cannot cover the phone's own features:

1. Voice input and microphone permission.
2. Camera and gallery photos.
3. Notifications: delivery, snooze, daily/weekly/monthly repeat, permission handling.
4. App lock with a screen lock configured.
5. Sharing a backup, then deleting everything and importing it: check the preview, a photo and an archived memory.
6. Upgrading over an installation that already has data.

## Database and backups

The database is currently at schema version 5. Migration code must stay in place because installed apps upgrade in place.

| Version | Added |
| --- | --- |
| 3 | Pin state, reminder time, money settlement status |
| 4 | Tags, attachment paths, follow-up action and status, recurrence |
| 5 | Status and follow-up indexes that earlier version 4 databases lacked |

A JSON backup is an object with `app`, `version` (2), `exported_at`, `memories` and `attachments` (photo files encoded as text, keyed by file name). Memories refer to photos by file name, so a backup restores on any phone. Imports skip anything already present (same text and time, archived included) and only ever write photos inside the app's own folder.

## Release checklist

Not started yet; publishing is deliberately postponed until the app is finished. Before publishing to Google Play or the App Store:

1. Replace the placeholder Android application ID (`com.example.did_i_tell_you`) in `android/app/build.gradle.kts` with a permanent one.
2. Set up an upload keystore through an untracked `key.properties`. Never commit keys or passwords.
3. Set the iOS bundle identifier and signing team, and prepare store listing text and screenshots.
4. Write a privacy policy and set up a support email.
5. Complete the manual checks above on physical devices.
6. Build a signed bundle with `flutter build appbundle --release`.
7. Start with internal testing, then closed testing, before a staged rollout.

The custom app icon is already in place for both platforms.

## Known limitations

- Understanding is rule-based: unusual names, phrasing and dates can be missed, and commitment detection is simple.
- Search matches words, not meaning: "glasses" will not find "spectacles" unless a tag or the text shares the word.
- The database is not encrypted; app lock only guards opening the app.
- No accounts, cloud sync or multi-device support.
- The web version has no notifications, app lock or photo attachments, and is tested only by compiling it in CI. Desktop folders are Flutter scaffolding only.
- Automated tests do not replace checks on a real device.

## Roadmap

Possible next steps, none started:

1. **On-device semantic search** with a small embedding model, so questions match meaning as well as words, with memories still never leaving the phone.
2. Better on-device extraction of dates and times (for example with Google's on-device entity extraction).
3. Optional, opt-in cloud features behind a secure backend: sign-in, encrypted sync, and grounded answers that cite their source memories. Any cloud release needs per-user authorization and independent security testing.
4. Store release, following the checklist above. Google Play ($25 once) and the App Store ($99 a year) are not free; GitHub Releases and Pages are.
