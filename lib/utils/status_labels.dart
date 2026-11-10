import '../l10n/app_strings.dart';
import 'user_prefs.dart';

/// 影视 / 阅读 / 游戏状态显示名的统一出口。
/// 底层状态 key 保持不变，用户自定义文案仅覆盖显示名；未自定义时回退默认文案（走 .tr 多语言）。
class StatusLabels {
  StatusLabels._();

  /// type → (状态 key → 默认中文文案)。顺序即各模块状态栏/表单的展示顺序。
  static const Map<String, Map<String, String>> defaults = {
    'movie': {
      'watched': '已看',
      'watching': '在看',
      'want_to_watch': '想看',
      'abandoned': '弃看',
    },
    'book': {
      'read': '已读',
      'reading': '在读',
      'want_to_read': '想读',
      'abandoned': '弃读',
    },
    'game': {
      'completed': '已通关',
      'playing': '在玩',
      'want_to_play': '想玩',
      'abandoned': '弃游',
    },
  };

  /// 某模块按展示顺序排列的状态 key。
  /// 优先采用用户自定义顺序，并校验补全，保证与默认集合完全一致。
  static List<String> orderedKeys(String type) {
    final defaultKeys = defaults[type]?.keys.toList() ?? const <String>[];
    final saved = UserPrefs().customStatusOrder(type);
    if (saved == null || saved.isEmpty) return defaultKeys;
    final result = <String>[];
    for (final k in saved) {
      if (defaultKeys.contains(k) && !result.contains(k)) result.add(k);
    }
    for (final k in defaultKeys) {
      if (!result.contains(k)) result.add(k);
    }
    return result;
  }

  /// 取状态显示名：优先用户自定义（原文展示，不多语言转换），否则默认文案走 .tr。
  static String label(String type, String key) {
    final override = UserPrefs().customStatusLabels(type)[key]?.trim();
    if (override != null && override.isNotEmpty) return override;
    return (defaults[type]?[key] ?? key).tr;
  }
}
