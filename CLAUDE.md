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

MookNote is a Flutter media-tracking app centered on **影视 / 阅读 / 游戏 / 笔记** four media types, with additional people/characters, playlists, image galleries, EPUB reader, online search, and cloud/WebDAV sync. Language: Dart/Flutter with Chinese UI. AGPL-3.0 licensed.

**Platforms:** Android is primary. Windows desktop is fully supported (hidden title bar, FFI sqflite, WebView2 + `epub://` custom protocol). `ios/`, `linux/`, `macos/`, `web/` directories exist but are secondary.

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

- **main.dart** — App entry; initializes `UserPrefs`, `AppProvider`, auto-backup, usage stats, and sync validation on startup. Applies dynamic_color (Monet), frosted-glass theme, window_manager, media_kit, and WebView2 `epub://` protocol on Windows
- **models/data_models.dart** — All data models in one file (~21 classes): `Movie`, `Book`, `Note`, `Game`, `Playlist`, `PlaylistItem`, `Person`, `MoviePerson`/`BookPerson`/`GamePerson`, `MovieCharacter`/`BookCharacter`/`GameCharacter`, `GalleryItem`, `MovieReview`, `BookReview`, `GameReview`, `MoviePoster`, `BookExcerpt`, `GameScreenshot`. Each has `fromJson`/`toJson`/`copyWith`
- **providers/app_provider.dart** — Single `AppProvider` (ChangeNotifier) has all app state (~260 members). Manages the four media type lists (movies, books, games, notes, playlists, people), theme mode, tab indices, drawer state, per-type UI preferences. Uses DAO pattern; `_useRemote` flag switches between local SQLite and remote server
- **data/** — DAO layer + database:
  - `database_helper.dart` — SQLite (sqflite), **version 42**, migration chain in `_onUpgrade`
  - Per-entity DAOs: `movie/`, `book/`, `game/`, `note/`, `person/`, `character/`, `tag/`, `gallery/`, `epub/` (reader), `playlist/`, `book_source/` (CRUD operations)
- **pages/** — UI by feature domain. Large subsystems:
  - `movies/`, `book/`, `game/`, `note/` — detail/form/list pages per media type
  - `epub_reader/` — full EPUB reader (webview renderer, page-turn sessions for Android/iOS, selection toolbar/handles, TOC, search, highlights, footnotes, image viewer, mixins)
  - `people/`, `character/`, `playlist/`, `explore/` (stats, gallery, calendar), `online_search/`, `markdown_reader/`, `quick_add/`, `profile/`, `settings/`, `sync/`
- **services/** — Non-UI logic: `epub/` (parser, stream service), `sync/` (server sync via ServerDataService, webdav, backup service), `usage_stats_service.dart`, `changelog_service.dart`, `font_download_manager.dart`, `app_icon_channel.dart`, `server_config.dart`
- **utils/** — `image_path_helper.dart`, `responsive.dart`, `toast_util.dart`, `slide_up_page_route.dart`, `theme/app_theme.dart`, `user_prefs.dart`, `server_config.dart`, `book_source/`
- **widgets/** — Shared widgets (list items, star rating, drawer, bottom nav, app shell, frosted background, shimmer skeleton, master-detail scaffold)
- **utils/app_router.dart** — Named route generator using `onGenerateRoute` with `SlideUpPageRoute` transitions

### UI / Tabs

Main tabs (mobile `main_content_page.dart` / desktop `home_page.dart`) switch by **影视 → 阅读 → 游戏 → 笔记** via a swipeable `PageView`. Tab visibility is user-configurable (`UserPrefs.showMovieTab` / `showBookTab` / `showGameTab` / `showNoteTab`).

### State Management

Provider pattern. A single `AppProvider` (ChangeNotifier) is provided at the root via `MultiProvider`/`Consumer`. All pages read state from `context.watch<AppProvider>()` or `context.read<AppProvider>()`.

### Data Layer

- **Local**: SQLite via sqflite (`DatabaseHelper` singleton, DB name: `mooknote.db`; FFI on Windows)
- **Remote**: Optional server sync via `ServerSyncService` / `ServerDataService`. Controlled by `UserPrefs.syncEnabled` + activation code
- **DAO pattern**: Each entity has its own DAO operating locally or remotely based on the `_useRemote` flag in `AppProvider`
- **Soft delete**: Models have `isDeleted`; recycle bin page manages restores

### Image Storage

Images stored at: `/mooknote/images/<category>/<entity_id>/<filename>` on device. `ImagePathHelper` manages paths. `FadeInLocalImage` widget handles local image display.

### Server (server/)

Python Flask backend (auth, admin API, sync API, web UI) for user stats and sync. Not part of the Flutter build. Run with `python app.py` or gunicorn.

## Key Conventions

- All Chinese UI strings are hardcoded (no i18n framework beyond Flutter's built-in localization delegates)
- UUID-based IDs for all entities (generated at creation time)
- List fields (directors, actors, genres, tags) stored as JSON-encoded strings in SQLite, parsed via `Movie.parseStringList()`
- `copyWith` uses a `_CopyWithNullSentinel` pattern to distinguish "not passed" from "passed null" for nullable fields
- Route transitions use custom `SlideUpPageRoute` (bottom-to-top slide)
- DB migrations in `DatabaseHelper._onUpgrade` — always add new migration blocks with version checks (`if (oldVersion < N)`), and bump the version constant
