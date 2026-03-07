import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../utils/movie_dao.dart';
import '../utils/book_dao.dart';
import '../utils/note_dao.dart';
import '../utils/movie_review_dao.dart';
import '../utils/movie_poster_dao.dart';
import '../utils/book_review_dao.dart';
import '../utils/book_excerpt_dao.dart';
import '../utils/image_path_helper.dart';

/// 应用全局状态管理
class AppProvider extends ChangeNotifier {
  // 数据库访问对象
  final MovieDao _movieDao = MovieDao();
  final BookDao _bookDao = BookDao();
  final NoteDao _noteDao = NoteDao();
  final MovieReviewDao _reviewDao = MovieReviewDao();
  final MoviePosterDao _posterDao = MoviePosterDao();
  final BookReviewDao _bookReviewDao = BookReviewDao();
  final BookExcerptDao _bookExcerptDao = BookExcerptDao();
  
  // 数据列表
  List<Movie> _movies = [];
  List<Book> _books = [];
  List<Note> _notes = [];
  
  // 当前主界面选中的标签 (0: 观影，1: 阅读，2: 笔记)
  int _mainTabIndex = 0;
  
  // 当前底部导航选中的索引 (0: 主页，1: 新增，2: 我的)
  int _bottomNavIndex = 0;
  
  // 观影选中的状态 (0: 已看，1: 想看，2: 在看)
  int _movieStatusIndex = 0;
  
  // 阅读选中的状态 (0: 读完，1: 在读，2: 准备读)
  int _bookStatusIndex = 0;
  
  // 侧边菜单是否打开
  bool _drawerOpen = false;
  
  // 初始化数据库
  Future<void> initDatabase() async {
    await loadMovies();
    await loadBooks();
    await loadNotes();
  }
  
  // 加载影视数据
  Future<void> loadMovies() async {
    _movies = await _movieDao.getAllMovies();
    notifyListeners();
  }
  
  // 加载书籍数据
  Future<void> loadBooks() async {
    _books = await _bookDao.getAllBooks();
    notifyListeners();
  }
  
  // 加载笔记数据
  Future<void> loadNotes() async {
    _notes = await _noteDao.getAllNotes();
    notifyListeners();
  }

  // Getters
  int get mainTabIndex => _mainTabIndex;
  int get bottomNavIndex => _bottomNavIndex;
  int get movieStatusIndex => _movieStatusIndex;
  int get bookStatusIndex => _bookStatusIndex;
  bool get drawerOpen => _drawerOpen;
  List<Movie> get movies => _movies;
  List<Book> get books => _books;
  List<Note> get notes => _notes;
  
  // 根据状态获取影视列表
  List<Movie> getMoviesByStatus(String status) {
    return _movies.where((movie) => movie.status == status).toList();
  }
  
  // 根据状态获取书籍列表
  List<Book> getBooksByStatus(String status) {
    return _books.where((book) => book.status == status).toList();
  }

  // Setters
  void setMainTabIndex(int index) {
    _mainTabIndex = index;
    notifyListeners();
  }

  void setBottomNavIndex(int index) {
    _bottomNavIndex = index;
    notifyListeners();
  }

  void setMovieStatusIndex(int index) {
    _movieStatusIndex = index;
    notifyListeners();
  }

  void setBookStatusIndex(int index) {
    _bookStatusIndex = index;
    notifyListeners();
  }

  void toggleDrawer() {
    _drawerOpen = !_drawerOpen;
    notifyListeners();
  }

  void closeDrawer() {
    _drawerOpen = false;
    notifyListeners();
  }
  
  // 添加影视记录
  Future<void> addMovie(Movie movie) async {
    await _movieDao.insertMovie(movie);
    await loadMovies();
  }
  
  // 更新影视记录
  Future<void> updateMovie(Movie movie) async {
    await _movieDao.updateMovie(movie);
    await loadMovies();
  }
  
  // 删除影视记录（软删除，移入回收站）
  // 注意：软删除时不删除图片文件，恢复时文件仍然存在
  Future<void> removeMovie(String id) async {
    await _movieDao.deleteMovie(id);
    await loadMovies();
  }
  
  // 添加书籍记录
  Future<void> addBook(Book book) async {
    await _bookDao.insertBook(book);
    await loadBooks();
  }
  
  // 更新书籍记录
  Future<void> updateBook(Book book) async {
    await _bookDao.updateBook(book);
    await loadBooks();
  }
  
  // 删除书籍记录（软删除，移入回收站）
  // 注意：软删除时不删除图片文件，恢复时文件仍然存在
  Future<void> removeBook(String id) async {
    await _bookDao.deleteBook(id);
    await loadBooks();
  }
  
  // 添加笔记
  Future<void> addNote(Note note) async {
    await _noteDao.insertNote(note);
    await loadNotes();
  }
  
  // 更新笔记
  Future<void> updateNote(Note note) async {
    await _noteDao.updateNote(note);
    await loadNotes();
  }
  
  // 删除笔记（软删除，移入回收站）
  // 注意：软删除时不删除图片文件，恢复时文件仍然存在
  Future<void> removeNote(String id) async {
    await _noteDao.deleteNote(id);
    await loadNotes();
  }
  
  // ========== 影评相关方法 ==========
  
  /// 获取影视的所有影评
  Future<List<MovieReview>> getMovieReviews(String movieId) async {
    return await _reviewDao.getReviewsByMovieId(movieId);
  }
  
  /// 添加影评
  Future<void> addMovieReview(MovieReview review) async {
    await _reviewDao.insertReview(review);
  }
  
  /// 更新影评
  Future<void> updateMovieReview(MovieReview review) async {
    await _reviewDao.updateReview(review);
  }
  
  /// 删除影评
  Future<void> removeMovieReview(String id) async {
    await _reviewDao.deleteReview(id);
  }
  
  /// 获取影视的影评数量
  Future<int> getMovieReviewCount(String movieId) async {
    return await _reviewDao.getReviewCount(movieId);
  }
  
  // ========== 海报墙相关方法 ==========
  
  /// 获取影视的所有海报
  Future<List<MoviePoster>> getMoviePosters(String movieId) async {
    return await _posterDao.getPostersByMovieId(movieId);
  }
  
  /// 添加海报
  Future<void> addMoviePoster(MoviePoster poster) async {
    await _posterDao.insertPoster(poster);
  }
  
  /// 删除海报
  Future<void> removeMoviePoster(String id) async {
    // 先获取海报信息，以便删除文件
    final poster = await _posterDao.getPosterById(id);
    if (poster != null) {
      // 删除海报文件
      await ImagePathHelper.instance.deleteFile(poster.posterPath);
    }
    
    await _posterDao.deletePoster(id);
  }
  
  /// 获取影视的海报数量
  Future<int> getMoviePosterCount(String movieId) async {
    return await _posterDao.getPosterCount(movieId);
  }

  // ========== 书评相关方法 ==========

  /// 获取书籍的所有书评
  Future<List<BookReview>> getBookReviews(String bookId) async {
    return await _bookReviewDao.getReviewsByBookId(bookId);
  }

  /// 添加书评
  Future<void> addBookReview(BookReview review) async {
    await _bookReviewDao.insertReview(review);
  }

  /// 更新书评
  Future<void> updateBookReview(BookReview review) async {
    await _bookReviewDao.updateReview(review);
  }

  /// 删除书评
  Future<void> removeBookReview(String id) async {
    await _bookReviewDao.deleteReview(id);
  }

  /// 获取书籍的书评数量
  Future<int> getBookReviewCount(String bookId) async {
    return await _bookReviewDao.getReviewCount(bookId);
  }

  // ========== 摘抄相关方法 ==========

  /// 获取书籍的所有摘抄
  Future<List<BookExcerpt>> getBookExcerpts(String bookId) async {
    return await _bookExcerptDao.getExcerptsByBookId(bookId);
  }

  /// 添加摘抄
  Future<void> addBookExcerpt(BookExcerpt excerpt) async {
    await _bookExcerptDao.insertExcerpt(excerpt);
  }

  /// 更新摘抄
  Future<void> updateBookExcerpt(BookExcerpt excerpt) async {
    await _bookExcerptDao.updateExcerpt(excerpt);
  }

  /// 删除摘抄
  Future<void> removeBookExcerpt(String id) async {
    await _bookExcerptDao.deleteExcerpt(id);
  }

  /// 获取书籍的摘抄数量
  Future<int> getBookExcerptCount(String bookId) async {
    return await _bookExcerptDao.getExcerptCount(bookId);
  }

  // ========== 回收站相关方法 ==========
  
  /// 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() async {
    return await _movieDao.getDeletedMovies();
  }
  
  /// 恢复影视
  Future<void> restoreMovie(String id) async {
    await _movieDao.restoreMovie(id);
    await loadMovies();
  }
  
  /// 彻底删除影视
  Future<void> permanentDeleteMovie(String id) async {
    // 删除影视对应的图片目录（包括海报和海报墙）
    await ImagePathHelper.instance.deleteMovieImages(id);
    
    await _movieDao.permanentDeleteMovie(id);
  }
  
  /// 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() async {
    return await _bookDao.getDeletedBooks();
  }
  
  /// 恢复书籍
  Future<void> restoreBook(String id) async {
    await _bookDao.restoreBook(id);
    await loadBooks();
  }
  
  /// 彻底删除书籍
  Future<void> permanentDeleteBook(String id) async {
    // 删除书籍对应的图片目录
    await ImagePathHelper.instance.deleteBookImages(id);
    
    await _bookDao.permanentDeleteBook(id);
  }
  
  /// 获取已删除的笔记
  Future<List<Note>> getDeletedNotes() async {
    return await _noteDao.getDeletedNotes();
  }
  
  /// 恢复笔记
  Future<void> restoreNote(String id) async {
    await _noteDao.restoreNote(id);
    await loadNotes();
  }
  
  /// 彻底删除笔记
  Future<void> permanentDeleteNote(String id) async {
    // 删除笔记对应的图片目录
    await ImagePathHelper.instance.deleteNoteImages(id);
    
    await _noteDao.permanentDeleteNote(id);
  }
  
  /// 清空回收站
  Future<void> clearRecycleBin() async {
    final deletedMovies = await _movieDao.getDeletedMovies();
    final deletedBooks = await _bookDao.getDeletedBooks();
    final deletedNotes = await _noteDao.getDeletedNotes();
    
    for (final movie in deletedMovies) {
      // 删除影视对应的图片目录（包括海报和海报墙）
      await ImagePathHelper.instance.deleteMovieImages(movie.id);
      await _movieDao.permanentDeleteMovie(movie.id);
    }
    for (final book in deletedBooks) {
      // 删除书籍对应的图片目录
      await ImagePathHelper.instance.deleteBookImages(book.id);
      await _bookDao.permanentDeleteBook(book.id);
    }
    for (final note in deletedNotes) {
      // 删除笔记对应的图片目录
      await ImagePathHelper.instance.deleteNoteImages(note.id);
      await _noteDao.permanentDeleteNote(note.id);
    }
    
    await loadMovies();
    await loadBooks();
    await loadNotes();
  }
}
