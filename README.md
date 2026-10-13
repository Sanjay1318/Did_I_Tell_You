# Did I Tell You?

**Did I Tell You?** is a private, local-first Flutter memory assistant. It helps people capture something once and retrieve it later through natural-language questions, structured filters, people views, reminders, and follow-ups.

The current product is designed for on-device Android and iOS use. It does not require an account, server, analytics service, or internet connection to store and search memories.

## Contents

- [Capabilities](#capabilities)
- [How data is handled](#how-data-is-handled)
- [Supported platforms](#supported-platforms)
- [Architecture](#architecture)
- [Local development](#local-development)
- [Testing](#testing)
- [Database migrations](#database-migrations)
- [Release checklist](#release-checklist)
- [Known limitations](#known-limitations)
- [Planned cloud and AI phase](#planned-cloud-and-ai-phase)

## Capabilities

### Capture and organize

- Create memories from typed text or speech-to-text input.
- Add custom comma-separated tags.
- Attach a photo or screenshot from the camera or device gallery.
- Pin important memories and archive/restore older entries.
- Edit original text and manually correct extracted person, amount, date, location, and category values.
- Delete individual memories or all locally stored memories.

### Extraction and follow-ups

The app uses local rule-based extraction. It can detect common people names, amounts, dates, locations, keywords, and categories. It also recognizes simple commitment phrasing such as `I'll send the resume tomorrow`, stores it as a pending follow-up, and lets the user mark it complete or reopen it.

Built-in categories are General, Money, People, Events, Purchases, Places, Entertainment, Work, Education, and Important.

### Search and discovery

- Keyword search across memory text and custom tags.
- Rule-based natural-language questions for common requests such as people, money, today, yesterday, last week, and categories.
- Filters by category, person, date range, minimum amount, and maximum amount.
- Sorting by newest, oldest, highest amount, or lowest amount.
- Timeline, recent-memory, people, and upcoming-reminder views.

### Reminders and money tracking

- Select a date and time for an on-device local notification.
- Change a reminder from the memory detail screen.
- Mark money-related memories as open or settled.
- View pending follow-ups and weekly capture activity from the dashboard.

### Privacy and device controls

- Local SQLite storage.
- Optional dark mode.
- Optional app lock using the device's existing authentication method.
- JSON and CSV export.
- JSON import with basic validation and duplicate-aware restoration.

## How data is handled

Memory records, app preferences, reminder state, and attachments are kept on the device. The app currently has no login, cloud synchronization, telemetry, advertising SDK, or remote AI request.

Exports may contain sensitive information. Share them only through trusted destinations. App Lock delegates to the device screen lock; the app does not store a PIN, biometric template, or authentication secret.

## Supported platforms

Android and iOS are the intended release platforms. Web and desktop folders are Flutter scaffolding only; do not distribute them until storage, import/export, notifications, and authentication have equivalent platform support.

## Architecture

```text
Flutter UI
  -> Provider state (MemoryService and SettingsService)
  -> Local services (extraction, duplicate detection, reminders, attachments)
  -> SQLite database and application-document attachments
```

The app is intentionally local-first. The extraction and natural-language query features are heuristic/rule based, not LLM-based. There is no semantic vector index, cloud RAG pipeline, or user-account system in the current version.

## Local development

### Prerequisites

- Flutter stable compatible with Dart 3.5 or later.
- Android SDK for Android development.
- Xcode and a macOS host for iOS development.
- A physical device for final validation of notifications, microphone input, camera/gallery input, and device authentication.

### Setup

```sh
flutter pub get
dart analyze lib test
flutter test
flutter run
```

Use `flutter devices` to see available devices. Run on a physical Android device before treating a build as release candidate quality.

## Testing

Automated tests currently cover:

- Memory serialization and database-compatible numeric values.
- New persisted model fields such as pins, reminders, settlement state, tags, attachments, and task state.
- Entity extraction, category classification, and duplicate detection.
- Local database behavior (`test/database/`): create, read, update and delete; filters, search and ordering; persistence across restarts; and upgrades from schema versions 1, 2 and 3 to the current version without losing data. These run against SQLite on the development machine via `sqflite_common_ffi`, so they need no phone or emulator.

Before every release, also manually verify:

1. Database upgrade with existing data.
2. Voice capture and microphone permission.
3. Camera/gallery attachment selection and deletion.
4. Notification scheduling, editing, and permission handling.
5. App Lock on a device with screen lock configured.
6. Export/import with representative data.
7. Archive/restore, follow-up completion, and data deletion.

## Database migrations

The local database is currently schema version 4. Migration code must remain in place after shipping because existing installations upgrade in place.

| Version | Added |
| --- | --- |
| 3 | Pin state, reminder timestamp, and money settlement status |
| 4 | Tags, attachment paths, task action/status, and recurrence metadata |

## Release checklist

Before publishing to Google Play or the App Store:

1. Replace the placeholder Android application ID in `android/app/build.gradle.kts` with a permanent reverse-DNS ID.
2. Configure an upload keystore via an untracked `key.properties` file. Never commit keys or passwords.
3. Set final iOS bundle identifier, signing team, app icon, and store metadata.
4. Prepare screenshots, support email, privacy policy, and store listing copy.
5. Complete every manual test in the [Testing](#testing) section on physical devices.
6. Create a signed Android App Bundle:

```sh
flutter build appbundle --release
```

7. Begin with Play Console internal testing, then closed testing, before a staged production rollout.

## Known limitations

- Image attachments are stored locally, but JSON/CSV export preserves only their metadata/path. It is not a portable image backup. Do not rely on export as the only backup for attached images.
- Commitment recognition is intentionally simple. It does not yet provide recurring scheduling, snooze actions, or advanced intent understanding.
- Search is keyword and rule based. Similar wording is not semantically matched unless it shares terms, tags, or known query patterns.
- There are no user accounts, cloud sync, account deletion flow, remote authorization, database encryption, or multi-device support.
- Automated tests do not replace physical-device validation.

## Planned cloud and AI phase

After the local-first experience is verified, the next phase should add a secure backend deliberately rather than mixing cloud behavior into the current database layer:

1. Authentication and user-scoped authorization.
2. Encrypted sync and account/data-deletion controls.
3. Secure media backup.
4. Embeddings and semantic retrieval.
5. Grounded RAG answers that cite source memories and communicate uncertainty.
6. Stronger people summaries, commitment detection, recurring reminders, and snooze workflows.

Any cloud release must guarantee that one user cannot retrieve another user's memories through row-level authorization, server-side validation, and independent security testing.
