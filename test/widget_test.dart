import 'package:flutter_test/flutter_test.dart';

import 'package:mooknote/providers/app_provider.dart';

void main() {
  test('AppProvider 初始状态为空列表', () {
    final provider = AppProvider();

    expect(provider.movies, isEmpty);
    expect(provider.books, isEmpty);
    expect(provider.games, isEmpty);
    expect(provider.notes, isEmpty);
  });
}
