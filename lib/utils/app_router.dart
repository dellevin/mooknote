import 'package:flutter/material.dart';
import '../models/data_models.dart';
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
        // 处理不同参数类型：Movie 对象或 Map（包含 initialStatus）
        final args = settings.arguments;
        Movie? movie;
        String? initialStatus;
        
        if (args is Movie) {
          movie = args;
        } else if (args is Map<String, dynamic>) {
          initialStatus = args['initialStatus'] as String?;
        }
        
        return MaterialPageRoute(
          builder: (_) => MovieFormPage(
            movie: movie,
            initialStatus: initialStatus,
          ),
        );
      
      case '/book-form':
        // 处理不同参数类型：Book 对象或 Map（包含 initialStatus）
        final args = settings.arguments;
        Book? book;
        String? initialStatus;

        if (args is Book) {
          book = args;
        } else if (args is Map<String, dynamic>) {
          initialStatus = args['initialStatus'] as String?;
        }

        return MaterialPageRoute(
          builder: (_) => BookFormPage(
            book: book,
            initialStatus: initialStatus,
          ),
        );
      
      case '/note-form':
        final note = settings.arguments as Note?;
        return MaterialPageRoute(
          builder: (_) => NoteFormPage(note: note),
        );
      
      case '/movie-detail':
        final movie = settings.arguments as Movie;
        return MaterialPageRoute(
          builder: (_) => MovieDetailPage(movie: movie),
        );
      
      case '/book-detail':
        final book = settings.arguments as Book;
        return MaterialPageRoute(
          builder: (_) => BookDetailPage(book: book),
        );
      
      case '/note-detail':
        final note = settings.arguments as Note;
        return MaterialPageRoute(
          builder: (_) => NoteDetailPage(note: note),
        );
      
      case '/douban-webview':
        final url = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => DoubanWebViewPage(url: url),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('未找到页面：${settings.name}'),
            ),
          ),
        );
    }
  }
}
