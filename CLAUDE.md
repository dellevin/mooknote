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

MookNote is a Flutter media-tracking app centered on **影视 / 阅读 / 游戏 / 笔记** four media types, with people/characters, playlists (片单), custom modules (自定义分类), image galleries, online search with multiple data sources (豆瓣 / TMDB / Bangumi / Steam / 自建资源服务), explore features (统计 / 日历 / 碎阅 / 已阅 / 漫步 / 相遇), and cloud/WebDAV sync. Language: Dart/Flutter, Chinese UI with English localization. AGPL-3.0 licensed. Current app version: 0.4.x (see pubspec.yaml).

**Platforms:** Android is primary (phone + tablet adaptive NavigationRail / master-detail). Windows desktop is fully supported (hidden title bar, FFI sqflite, wide-screen master-detail; separate Electron port lives in the `mooknote_windows` repo). `ios/`, `linux/`, `macos/`, `web/` directories exist but are secondary.

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

- **main.dart** — App entry; initializes `UserPrefs`, installs global HTTP proxy overrides, `AppProvider`, auto-backup, usage stats, and sync validation on startup. Applies dynamic_color (Monet), frosted-glass theme, window_manager, media_kit
- **models/data_models.dart** — All data models in one file (28 classes): `Movie`, `Book`, `Note`, `Game`, reviews (`MovieReview`/`BookReview`/`GameReview`), `MoviePoster`, `MovieEpisode`, `BookChapter`, `BookExcerpt`, `GameScreenshot`, `GameCompletion`, `GameLevel`, `Playlist`/`PlaylistItem`, `Person` + `MoviePerson`/`BookPerson`/`GamePerson`, `MovieCharacter`/`BookCharacter`/`GameCharacter`, `GalleryItem`, `CustomFieldDef`/`CustomModule`/`CustomModuleDesign`/`CustomModuleItem`. Each has `fromJson`/`toJson`/`copyWith`
- **providers/app_provider.dart** — Single `AppProvider` (ChangeNotifier) holds all app state. Manages the four media type lists (movies, books, games, notes, playlists, people), theme mode, tab indices, drawer state, per-type UI preferences. Uses DAO pattern; `_useRemote` flag switches between local SQLite and remote server
- **data/** — DAO layer + database:
  - `database_helper.dart` — SQLite (sqflite), **version 55**, migration chain in `_onUpgrade`
  - Per-entity DAOs: `movie/`, `book/`, `game/`, `note/`, `person/`, `character/`, `tag/`, `gallery/` (含 `image_asset_dao` 图片自定义名), `playlist/`, `custom_module/` (CRUD operations)
- **pages/** — UI by feature domain:
  - `movies/`, `book/`, `game/`, `note/` — detail/form/list pages per media type; detail pages each have 4 style builders (标准/毛玻璃/浅色极简/豆瓣) dispatched by global `UserPrefs.detailPageStyle`, modules ordered by `getDetailModules(type)`
  - `custom_module/` — 自定义分类 (module manage, form designer, entry form/detail, tab page)
  - `online_search/` — `search_hub_page` 统一入口 + `online_search_page` (自建影视/书籍资源)、`tmdb_*`、`bangumi_*` (含人物收藏/关联 sheet)、`enhanced_search_settings_page`、各数据源 settings 页
  - `explore/` — `statistics_page`、`media_calendar_page`、`media_journal_page` + `journal_poster_page` (碎阅/海报)、`reviewed_page` (已阅)、`stroll_page` (漫步)、`encounter_page` (相遇)、`gallery_*`、`person_list_page`
  - `people/`, `character/`, `playlist/`, `progress/`, `quick_add/`, `profile/`, `settings/`, `sync/`, `home/`
- **services/** — Non-UI logic:
  - `sync/` — server sync, webdav, backup service, cache_cleaner, `incremental/` (LWW delta sync)
  - `bangumi_service.dart` / `tmdb_service.dart` — 在线数据源 API 客户端
  - `api_proxy_client.dart` — 按用户配置构造带 `findProxy` 的 http.Client（仅 API 请求）
  - `http_proxy_overrides.dart` — 全局 `HttpOverrides`，按 host 分流代理，让 `Image.network` 等内部 HttpClient 也走代理
  - `server_export_service.dart`, `changelog_service.dart`, `font_download_manager.dart`, `log_service.dart`, `report_service.dart`, `app_icon_channel.dart`, `media_scan_channel.dart`, `system_settings_channel.dart`
- **utils/** — `image_path_helper.dart`, `responsive.dart`, `toast_util.dart`, `slide_up_page_route.dart`, `theme/app_theme.dart`, `user_prefs.dart`, `server_config.dart`, `excel_exporter.dart`, `image_saver.dart`, `douban_parser.dart`, `steam_parser.dart`, `image_picker_helper.dart`
- **l10n/** — 轻量自建 i18n：`app_strings.dart` 聚合 `en/en_*.dart` 各域英文 Map
- **widgets/** — Shared widgets (list items, star rating, `custom_drawer`, `bottom_nav_bar` dock, app shell, frosted background, shimmer skeleton, master-detail scaffold, `add_sheet`)
- **utils/app_router.dart** — Named route generator using `onGenerateRoute` with `SlideUpPageRoute` transitions

### UI / Tabs

Main tabs cover **影视 → 阅读 → 游戏 → 笔记**. On mobile (`home/main_content_page.dart`) all four pages stay alive in a persistent `Stack` and cross-fade via `AnimatedOpacity`, declaratively driven by `AppProvider.mainTabIndex` (no PageController timing logic); horizontal swipe still flips pages through a `PageView`. The bottom nav (home/calendar/profile) uses the same Stack + cross-fade pattern. Tab visibility is user-configurable (`UserPrefs.showMovieTab` / `showBookTab` / `showGameTab` / `showNoteTab`). Custom modules can also be enabled as additional tabs. Desktop uses a master-detail scaffold in `home/home_page.dart`.

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

- **i18n**: Chinese literal is the key. Wrap UI text with `.tr` (or `.trf({'n': x})` for placeholders) from `l10n/app_strings.dart`; add the English mapping to the matching `l10n/en/en_*.dart` domain file. Missing English falls back to Chinese automatically. New user-facing strings should always get an English entry in the same change.
- **HTTP decoding**: never use `Response.body` for JSON/HTML text — `package:http` falls back to latin1 when the response lacks `charset=utf-8`, causing Chinese mojibake. Always `utf8.decode(resp.bodyBytes)` (dart:convert). Binary/image downloads use `bodyBytes` directly.
- **Proxies**: data-source API clients go through `buildProxyClient()` (per-service proxy setting); image/global traffic is covered by `installHttpProxyOverrides()` host-based `HttpOverrides` (bgm.tv / tmdb.org only, everything else DIRECT). SOCKS5 is not supported — HTTP proxy only.
- UUID-based IDs for all entities (generated at creation time)
- List fields (directors, actors, genres, tags) stored as JSON-encoded strings in SQLite, parsed via `Movie.parseStringList()`
- `copyWith` uses a `_CopyWithNullSentinel` pattern to distinguish "not passed" from "passed null" for nullable fields
- Route transitions use custom `SlideUpPageRoute` (bottom-to-top slide)
- **SQL compatibility**: user devices may run old SQLite. Avoid 3.30+ syntax (e.g. `NULLS LAST` froze sorting on device); use `col IS NULL, col DESC` for null ordering instead.
- DB migrations in `DatabaseHelper._onUpgrade` — always add new migration blocks with version checks (`if (oldVersion < N)`), and bump the version constant (currently 55)
