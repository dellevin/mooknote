import 'en/en_profile.dart';
import 'en/en_movie.dart';
import 'en/en_book.dart';
import 'en/en_game.dart';
import 'en/en_epub.dart';
import 'en/en_home.dart';
import 'en/en_explore_note.dart';
import 'en/en_widgets.dart';
import 'en/en_search_sync.dart';
import 'en/en_people.dart';

/// 轻量 i18n：中文原文作为 key，英文缺失时回退中文。
///
/// 用法：
/// - 普通文案：`Text('设置'.tr)`
/// - 带占位符：`'共 {n} 项'.trf({'n': count})`
class AppStrings {
  AppStrings._();

  /// 当前是否为英文界面（由 AppProvider 语言设置驱动）
  static bool isEnglish = false;

  static final Map<String, String> _en = {
    ...enProfile,
    ...enMovie,
    ...enBook,
    ...enGame,
    ...enEpub,
    ...enHome,
    ...enExploreNote,
    ...enWidgets,
    ...enSearchSync,
    ...enPeople,
  };

  static String lookup(String zh) {
    if (!isEnglish) return zh;
    return _en[zh] ?? zh;
  }
}

extension StringTr on String {
  /// 按当前语言翻译（英文资源缺失时回退中文原文）
  String get tr => AppStrings.lookup(this);

  /// 带占位符的翻译：'共 {n} 项'.trf({'n': 5})
  String trf(Map<String, Object?> args) {
    var s = AppStrings.lookup(this);
    args.forEach((k, v) {
      s = s.replaceAll('{$k}', '$v');
    });
    return s;
  }
}
