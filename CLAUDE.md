# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.


---

## Project Overview

MookNote is a Flutter-based Android app for tracking movies, books, and notes. Language: Dart/Flutter with Chinese UI. AGPL-3.0 licensed.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (connect Android device or start emulator first)
flutter run

# Build release APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release

# Clean build
flutter clean && flutter pub get

# Static analysis
flutter analyze

# Use China mirror if pub get fails
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

## Architecture

### App Structure (lib/)

- **main.dart** — App entry; initializes `UserPrefs`, `AppProvider`, auto-backup, usage stats, and sync validation on startup
- **models/data_models.dart** — All data models in one file: `Movie`, `Book`, `Note`, `MovieReview`, `BookReview`, `MoviePoster`, `BookExcerpt`. Each has `fromJson`/`toJson`/`copyWith`
- **providers/app_provider.dart** — Single `AppProvider` (ChangeNotifier) holds all app state. Manages movies, books, notes lists, theme mode, tab indices, drawer state. Uses DAO pattern for data access. Has a `_useRemote` flag to switch between local SQLite and remote server
- **pages/** — UI pages organized by feature domain: `movies/`, `book/`, `note/`, `sync/`, `markdown_reader/`
- **utils/** — Business logic layer:
  - `database_helper.dart` — SQLite database (sqflite), version 13, with migration chain
  - `movie/`, `book/`, `note/` — DAO classes for each entity (CRUD operations)
  - `tag/tag_dao.dart` — Tag management
  - `sync/` — Server sync, WebDAV sync, auto-backup, backup service
  - `theme/app_theme.dart` — Minimalist black/white/gray theme with Material 3
  - `user_prefs.dart` — SharedPreferences wrapper (singleton)
- **widgets/** — Shared reusable widgets (list items, star rating, drawer, bottom nav, shimmer skeleton)
- **utils/app_router.dart** — Named route generator using `onGenerateRoute` with `SlideUpPageRoute` transitions

### State Management

Provider pattern. A single `AppProvider` (ChangeNotifier) is provided at the root via `MultiProvider`/`Consumer`. All pages read state from `context.watch<AppProvider>()` or `context.read<AppProvider>()`.

### Data Layer

- **Local**: SQLite via sqflite (`DatabaseHelper` singleton, DB name: `mooknote.db`)
- **Remote**: Optional server sync via `ServerSyncService` / `ServerDataService`. Controlled by `UserPrefs.syncEnabled` + activation code
- **DAO pattern**: Each entity has its own DAO (`MovieDao`, `BookDao`, `NoteDao`, etc.) that can operate locally or remotely based on `_useRemote` flag in AppProvider
- **Soft delete**: All models have `isDeleted` field; a recycle bin page manages restores

### Image Storage

Images stored at: `/mooknote/images/<category>/<entity_id>/<filename>` on device. `ImagePathHelper` manages paths. `FadeInLocalImage` widget handles local image display.

### Server (server/)

Python Flask backend for user stats and sync API. Not part of the Flutter build. Run with `python app.py` or gunicorn.

## Key Conventions

- All Chinese UI strings are hardcoded (no i18n framework beyond Flutter's built-in localization delegates)
- UUID-based IDs for all entities (generated at creation time)
- List fields (directors, actors, genres, tags) stored as JSON-encoded strings in SQLite, parsed via `Movie.parseStringList()`
- `copyWith` uses a `_CopyWithNullSentinel` pattern to distinguish "not passed" from "passed null" for nullable fields
- Route transitions use custom `SlideUpPageRoute` (bottom-to-top slide)
- DB migrations in `DatabaseHelper._onUpgrade` — always add new migration blocks with version checks (`if (oldVersion < N)`)
