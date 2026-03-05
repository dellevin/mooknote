import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../utils/movie_dao.dart';
import '../utils/book_dao.dart';
import '../utils/note_dao.dart';

/// 应用全局状态管理
class AppProvider extends ChangeNotifier {
  // 数据库访问对象
  final MovieDao _movieDao = MovieDao();
  final BookDao _bookDao = BookDao();
  final NoteDao _noteDao = NoteDao();
  
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
  
  // 删除影视记录
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
  
  // 删除书籍记录
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
  
  // 删除笔记
  Future<void> removeNote(String id) async {
    await _noteDao.deleteNote(id);
    await loadNotes();
  }
}
