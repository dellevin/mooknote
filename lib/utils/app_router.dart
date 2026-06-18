import 'package:flutter/material.dart';
import '../models/data_models.dart';
import 'slide_up_page_route.dart';
import '../pages/movies/movie_form_page.dart';
import '../pages/book/book_form_page.dart';
import '../pages/note/note_form_page.dart';
import '../pages/movies/movie_detail_page.dart';
import '../pages/book/book_detail_page.dart';
import '../pages/note/note_detail_page.dart';
import '../pages/movies/douban_webview_page.dart';

/// 路由生成器
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/movie-form':
        final args = settings.arguments;
        final Movie? movie = args is Movie ? args : null;
        final String? initialStatus =
            args is Map<String, dynamic> ? (args['initialStatus'] as String?) : null;
        return SlideUpPageRoute(
          page: MovieFormPage(movie: movie, initialStatus: initialStatus),
        );

      case '/book-form':
        final args = settings.arguments;
        final Book? book = args is Book ? args : null;
        final String? initialStatus =
            args is Map<String, dynamic> ? (args['initialStatus'] as String?) : null;
        return SlideUpPageRoute(
          page: BookFormPage(book: book, initialStatus: initialStatus),
        );

      case '/note-form':
        final args = settings.arguments;
        final Note? note = args is Note ? args : null;
        return SlideUpPageRoute(page: NoteFormPage(note: note));

      case '/movie-detail':
        final movie = settings.arguments is Movie ? settings.arguments as Movie : null;
        if (movie == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(page: MovieDetailPage(movie: movie));

      case '/book-detail':
        final book = settings.arguments is Book ? settings.arguments as Book : null;
        if (book == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(page: BookDetailPage(book: book));

      case '/note-detail':
        final note = settings.arguments is Note ? settings.arguments as Note : null;
        if (note == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(page: NoteDetailPage(note: note));

      case '/douban-webview':
        final url = settings.arguments is String ? settings.arguments as String : null;
        if (url == null) {
          return _buildUnknownRoute(settings.name);
        }
        return SlideUpPageRoute(page: DoubanWebViewPage(url: url));

      default:
        return _buildUnknownRoute(settings.name);
    }
  }

  static Route<dynamic> _buildUnknownRoute(String? name) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text('未找到页面：${name ?? ''}')),
      ),
    );
  }
}
