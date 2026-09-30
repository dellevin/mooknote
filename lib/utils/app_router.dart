import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_models.dart';
import '../l10n/app_strings.dart';
import 'slide_up_page_route.dart';
import 'platform_utils.dart';
import '../pages/movies/movie_form_page.dart';
import '../pages/book/book_form_page.dart';
import '../pages/note/note_form_page.dart';
import '../pages/game/game_form_page.dart';
import '../pages/movies/movie_detail_page.dart';
import '../pages/book/book_detail_page.dart';
import '../pages/note/note_detail_page.dart';
import '../pages/game/game_detail_page.dart';
import '../pages/movies/douban_webview_page.dart';

/// 路由生成器
class AppRouter {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/movie-form':
        final args = settings.arguments;
        final Movie? movie = args is Movie ? args : null;
        final String? initialStatus =
            args is Map<String, dynamic> ? (args['initialStatus'] as String?) : null;
        final Map<String, dynamic>? prefill =
            args is Map<String, dynamic> ? (args['prefill'] as Map<String, dynamic>?) : null;
        return SlideUpPageRoute(
          page: MovieFormPage(movie: movie, initialStatus: initialStatus, prefill: prefill),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/book-form':
        final args = settings.arguments;
        final Book? book = args is Book ? args : null;
        final String? initialStatus =
            args is Map<String, dynamic> ? (args['initialStatus'] as String?) : null;
        final Map<String, dynamic>? prefill =
            args is Map<String, dynamic> ? (args['prefill'] as Map<String, dynamic>?) : null;
        return SlideUpPageRoute(
          page: BookFormPage(book: book, initialStatus: initialStatus, prefill: prefill),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/note-form':
        final args = settings.arguments;
        final Note? note = args is Note ? args : null;
        return SlideUpPageRoute(
          page: NoteFormPage(note: note),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/movie-detail':
        final movie = settings.arguments is Movie ? settings.arguments as Movie : null;
        if (movie == null) {
          return _buildUnknownRoute(settings.name);
        }
        // 从底部弹出详情（与表单页同一转场样式）
        return SlideUpPageRoute(
          page: MovieDetailPage(movie: movie),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/book-detail':
        final book = settings.arguments is Book ? settings.arguments as Book : null;
        if (book == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(
          page: BookDetailPage(book: book),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/note-detail':
        final note = settings.arguments is Note ? settings.arguments as Note : null;
        if (note == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(page: NoteDetailPage(note: note));

      case '/game-form':
        final args = settings.arguments;
        final Game? game = args is Game ? args : null;
        final String? initialStatus =
            args is Map<String, dynamic> ? (args['initialStatus'] as String?) : null;
        final Map<String, dynamic>? prefill =
            args is Map<String, dynamic> ? (args['prefill'] as Map<String, dynamic>?) : null;
        return SlideUpPageRoute(
          page: GameFormPage(game: game, initialStatus: initialStatus, prefill: prefill),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/game-detail':
        final game = settings.arguments is Game ? settings.arguments as Game : null;
        if (game == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(
          page: GameDetailPage(game: game),
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          beginOffsetY: 1.0,
        );

      case '/douban-webview':
        final args = settings.arguments;
        final String url;
        final String category;
        final String source;
        if (args is String) {
          url = args;
          category = 'movie';
          source = 'douban';
        } else if (args is Map<String, dynamic>) {
          url = (args['url'] as String?) ?? '';
          category = (args['category'] as String?) ?? 'movie';
          source = (args['source'] as String?) ?? 'douban';
        } else {
          return _buildUnknownRoute(settings.name);
        }
        if (url.isEmpty) {
          return _buildUnknownRoute(settings.name);
        }
        if (PlatformUtils.isDesktop) {
          // 桌面端无 webview 支持，用系统浏览器打开
          launchUrl(Uri.parse(url));
          return null;
        }
        return SlideUpPageRoute(
            page: DoubanWebViewPage(url: url, category: category, source: source));

      default:
        return _buildUnknownRoute(settings.name);
    }
  }

  static Route<dynamic> _buildUnknownRoute(String? name) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text('未找到页面：{name}'.trf({'name': name ?? ''}))),
      ),
    );
  }
}
