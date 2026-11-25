import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mooknote/utils/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('detail character settings', () {
    test('uses preview defaults and excludes characters from extra entries',
        () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.init();

      final prefs = UserPrefs();
      expect(prefs.detailCharacterShowPreview('movie'), isTrue);
      expect(prefs.detailCharacterPreviewCount('movie'), 4);
      expect(
        prefs.getDetailExtraItems('movie').map((item) => item.id),
        isNot(contains('characters')),
      );
    });

    test('persists display mode and clamps preview count', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.init();

      final prefs = UserPrefs();
      await prefs.setDetailCharacterShowPreview('game', false);
      await prefs.setDetailCharacterPreviewCount('game', 6);
      expect(prefs.detailCharacterShowPreview('game'), isFalse);
      expect(prefs.detailCharacterPreviewCount('game'), 6);

      await prefs.setDetailCharacterPreviewCount('game', 0);
      expect(prefs.detailCharacterPreviewCount('game'), 1);
      await prefs.setDetailCharacterPreviewCount('game', 99);
      expect(prefs.detailCharacterPreviewCount('game'), 10);
    });

    test('merges old preview and extra entry visibility', () async {
      SharedPreferences.setMockInitialValues({
        'detailModules_movie': jsonEncode([
          {'id': 'characters', 'visible': false},
          {'id': 'extra', 'visible': true},
        ]),
        'detailExtraItems_movie': jsonEncode([
          {'id': 'characters', 'visible': true},
          {'id': 'posters', 'visible': true},
        ]),
        'detailModules_book': jsonEncode([
          {'id': 'characters', 'visible': false},
          {'id': 'extra', 'visible': true},
        ]),
        'detailExtraItems_book': jsonEncode([
          {'id': 'characters', 'visible': false},
          {'id': 'excerpts', 'visible': true},
        ]),
      });
      await UserPrefs.init();

      final prefs = UserPrefs();
      final movieCharacters = prefs
          .getDetailModules('movie')
          .firstWhere((item) => item.id == 'characters');
      final bookCharacters = prefs
          .getDetailModules('book')
          .firstWhere((item) => item.id == 'characters');

      expect(movieCharacters.visible, isTrue);
      expect(bookCharacters.visible, isFalse);
      expect(
        prefs.getDetailExtraItems('movie').map((item) => item.id),
        isNot(contains('characters')),
      );
      expect(
        prefs.getDetailExtraItems('book').map((item) => item.id),
        isNot(contains('characters')),
      );
    });
  });
}
