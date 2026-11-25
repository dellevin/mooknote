import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mooknote/utils/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('detail review settings', () {
    test('uses preview defaults and excludes reviews from extra entries',
        () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.init();

      final prefs = UserPrefs();
      expect(prefs.detailReviewShowPreview('movie'), isTrue);
      expect(prefs.detailReviewPreviewCount('movie'), 3);
      expect(
        prefs.getDetailExtraItems('movie').map((item) => item.id),
        isNot(contains('reviews')),
      );
    });

    test('persists display mode and clamps preview count', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.init();

      final prefs = UserPrefs();
      await prefs.setDetailReviewShowPreview('book', false);
      await prefs.setDetailReviewPreviewCount('book', 7);
      expect(prefs.detailReviewShowPreview('book'), isFalse);
      expect(prefs.detailReviewPreviewCount('book'), 7);

      await prefs.setDetailReviewPreviewCount('book', 0);
      expect(prefs.detailReviewPreviewCount('book'), 1);
      await prefs.setDetailReviewPreviewCount('book', 99);
      expect(prefs.detailReviewPreviewCount('book'), 10);
    });

    test('merges old preview and extra entry visibility', () async {
      SharedPreferences.setMockInitialValues({
        'detailModules_movie': jsonEncode([
          {'id': 'summary', 'visible': true},
          {'id': 'reviews', 'visible': false},
          {'id': 'extra', 'visible': true},
        ]),
        'detailExtraItems_movie': jsonEncode([
          {'id': 'progress', 'visible': false},
          {'id': 'reviews', 'visible': true},
          {'id': 'posters', 'visible': true},
        ]),
        'detailModules_book': jsonEncode([
          {'id': 'reviews', 'visible': false},
          {'id': 'extra', 'visible': true},
        ]),
        'detailExtraItems_book': jsonEncode([
          {'id': 'reviews', 'visible': false},
          {'id': 'excerpts', 'visible': true},
        ]),
      });
      await UserPrefs.init();

      final prefs = UserPrefs();
      final movieReview = prefs
          .getDetailModules('movie')
          .firstWhere((item) => item.id == 'reviews');
      final bookReview = prefs
          .getDetailModules('book')
          .firstWhere((item) => item.id == 'reviews');

      expect(movieReview.visible, isTrue);
      expect(bookReview.visible, isFalse);
      expect(
        prefs.getDetailExtraItems('movie').map((item) => item.id),
        isNot(contains('reviews')),
      );
      expect(
        prefs.getDetailExtraItems('book').map((item) => item.id),
        isNot(contains('reviews')),
      );
      expect(
        prefs
            .getDetailExtraItems('movie')
            .firstWhere((item) => item.id == 'progress')
            .visible,
        isFalse,
      );
    });
  });
}
