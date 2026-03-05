import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../pages/movie_form_page.dart';
import '../pages/book_form_page.dart';
import '../pages/note_form_page.dart';
import '../pages/movie_detail_page.dart';
import '../pages/book_detail_page.dart';
import '../pages/note_detail_page.dart';

/// 路由生成器
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/movie-form':
        final movie = settings.arguments as Movie?;
        return MaterialPageRoute(
          builder: (_) => MovieFormPage(movie: movie),
        );
      
      case '/book-form':
        final book = settings.arguments as Book?;
        return MaterialPageRoute(
          builder: (_) => BookFormPage(book: book),
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
