import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mooknote/pages/explore/journal_poster_page.dart';
import 'package:mooknote/pages/explore/media_journal_page.dart';
import 'package:mooknote/widgets/fade_in_local_image.dart';

void main() {
  final png = const Base64Decoder().convert(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  for (final count in [1, 2, 5, 20, 40, 120]) {
    for (final (layoutLabel, layoutText) in [
      ('slant', '海报墙（斜）'),
      ('small', '海报墙（小）'),
    ]) {
      testWidgets('wall $layoutLabel with $count items fills the frame',
          (tester) async {
        final dir = Directory.systemTemp.createTempSync('walltest');
        final imgFile = File('${dir.path}/p.png')..writeAsBytesSync(png);
        final items = [
          for (var i = 0; i < count; i++)
            JournalItem(
              path: imgFile.path,
              title: 'm $i',
              type: 'movie',
              data: null,
              date: DateTime(2026, 11, (i % 28) + 1),
            ),
        ];

        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: JournalPosterPage(
            anchorMonth: DateTime(2026, 11),
            items: items,
            typeColor: (_) => const Color(0xFF4A90D9),
            typeLabel: (_) => '影视',
            typeIcon: (_) => Icons.movie_outlined,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('布局'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(layoutText));
        await tester.pumpAndSettle();
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 200)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final clip = tester.renderObject<RenderBox>(find.byType(OverflowBox));
        final clipRect = clip.localToGlobal(Offset.zero) & clip.size;
        final wrapBox = tester.renderObject<RenderBox>(find.byType(Wrap));
        final layoutW = wrapBox.size.width;
        final contentH = wrapBox.size.height;

        // 左右安全边距：OverflowBox 相对外层 ClipRRect 各内缩 14px，
        // 且必须有内框 ClipRect 真正裁掉溢出绘制（OverflowBox 本身允许画出去）
        final outerClip = tester.renderObject<RenderBox>(
          find.ancestor(
            of: find.byType(OverflowBox),
            matching: find.byType(ClipRRect),
          ),
        );
        final outerRect =
            outerClip.localToGlobal(Offset.zero) & outerClip.size;
        expect(clipRect.left - outerRect.left, closeTo(14, 0.5));
        expect(outerRect.right - clipRect.right, closeTo(14, 0.5));
        // ClipRRect 也是 ClipRect 子类，谓词排除掉外层圆角裁剪；
        // 取最近的祖先即墙的内框裁剪（框架层可能还有别的 ClipRect）
        final innerClipMatches = find
            .ancestor(
              of: find.byType(OverflowBox),
              matching: find.byWidgetPredicate(
                  (w) => w is ClipRect && w is! ClipRRect),
            )
            .evaluate();
        expect(innerClipMatches, isNotEmpty);
        final innerClip =
            innerClipMatches.first.renderObject as RenderBox;
        final innerRect =
            innerClip.localToGlobal(Offset.zero) & innerClip.size;
        expect(innerRect.left, closeTo(clipRect.left, 0.5));
        expect(innerRect.right, closeTo(clipRect.right, 0.5));

        // 循环补齐：瓦片数不少于数据条数（全部数据至少上墙一次）；
        // 上限按生产侧同公式计算：max(100, 各候选角度理论网格的最大值)
        final frameW = clip.size.width;
        final tileW = layoutLabel == 'slant' ? 104.0 : 72.0;
        final tileH = tileW * 1.38;
        const spacing = 10.0;
        final baseCols =
            math.max(1, ((frameW + spacing) / (tileW + spacing)).floor());
        final naturalRows = (count / baseCols).ceil();
        final targetFrameH = naturalRows * tileH;
        var expectedCap = math.max(100, naturalRows * baseCols);
        for (final a in [0.24, 0.32, 0.40, 0.50]) {
          final needCols =
              ((frameW * math.cos(a) + targetFrameH * math.sin(a) + spacing) /
                      (tileW + spacing))
                  .ceil();
          final needRows =
              ((frameW * math.sin(a) + targetFrameH * math.cos(a) + spacing) /
                      (tileH + spacing))
                  .ceil();
          expectedCap = math.max(expectedCap, needCols * needRows);
        }
        final wrapFinder = find.byType(Wrap);
        final tiles = find.descendant(of: wrapFinder, matching: find.byType(Image));
        final tileCount = tiles.evaluate().length;
        expect(tileCount, greaterThanOrEqualTo(count));
        expect(tileCount, lessThanOrEqualTo(expectedCap));

        // 零留白：框内均匀采样，逆旋转回内容坐标系后每点都落在内容矩形内。
        // 倾角是自适应的，从 Transform 矩阵反算实际角度（旋转角为 -a）。
        final transform = tester.widget<Transform>(
          find.descendant(
              of: find.byType(OverflowBox), matching: find.byType(Transform)),
        );
        final m = transform.transform;
        final wallAngle = math.atan2(-m.entry(1, 0), m.entry(0, 0)).abs();
        final cosA = math.cos(wallAngle);
        final sinA = math.sin(wallAngle);
        final frameCenter = clipRect.center;
        var gaps = 0;
        for (var ix = 1; ix < 40; ix++) {
          for (var iy = 1; iy < 60; iy++) {
            final p = Offset(
              clipRect.left + clipRect.width * ix / 40,
              clipRect.top + clipRect.height * iy / 60,
            );
            final q = p - frameCenter;
            final c = Offset(
                  q.dx * cosA - q.dy * sinA,
                  q.dx * sinA + q.dy * cosA,
                ) +
                Offset(layoutW / 2, contentH / 2);
            if (c.dx < -1 ||
                c.dy < -1 ||
                c.dx > layoutW + 1 ||
                c.dy > contentH + 1) {
              gaps++;
            }
          }
        }
        expect(gaps, 0,
            reason: '$gaps sample points fall on background gap (angle=$wallAngle)');

        // 墙内必须用静态 Image（无 FadeInLocalImage 动画控制器）
        expect(
          find.descendant(of: wrapFinder, matching: find.byType(FadeInLocalImage)),
          findsNothing,
        );

        // 每个瓦片都必须有红色移除角标
        final badges = find.descendant(
          of: wrapFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == const Color(0xFFE53935),
          ),
        );
        expect(badges.evaluate().length, tileCount);
      });
    }
  }

  for (final layoutText in ['卡片', '列表', '海报墙（斜）', '海报墙（小）']) {
    testWidgets('layout "$layoutText" uses static images (no fade-in controllers)',
        (tester) async {
      const count = 20;
      final dir = Directory.systemTemp.createTempSync('walltest');
      final imgFile = File('${dir.path}/p.png')..writeAsBytesSync(png);
      final items = [
        for (var i = 0; i < count; i++)
          JournalItem(
            path: imgFile.path,
            title: 'm $i',
            type: 'movie',
            data: null,
            date: DateTime(2026, 11, (i % 28) + 1),
          ),
      ];

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: JournalPosterPage(
          anchorMonth: DateTime(2026, 11),
          items: items,
          typeColor: (_) => const Color(0xFF4A90D9),
          typeLabel: (_) => '影视',
          typeIcon: (_) => Icons.movie_outlined,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('布局'));
      await tester.pumpAndSettle();
      // “海报”与 AppBar 标题重名，last 命中底部布局面板里的选项
      await tester.tap(find.text(layoutText).last);
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 整个页面不允许出现淡入图片组件（每个都带一个 AnimationController）
      expect(find.byType(FadeInLocalImage), findsNothing);

      final redBadges = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFFE53935),
      );
      switch (layoutText) {
        // 数据多于最小框位时展示全部 20 条，每格一张图、一个角标
        case '卡片':
          expect(
            find.descendant(of: find.byType(GridView), matching: find.byType(Image)),
            findsNWidgets(count),
          );
          expect(redBadges, findsNWidgets(count));
          // 每格中央一个换封面按钮
          expect(find.byIcon(Icons.swap_horiz_rounded), findsNWidgets(count));
        case '列表':
          // 全页 Image 含品牌行 1 张
          expect(find.byType(Image), findsNWidgets(count + 1));
          expect(redBadges, findsNWidgets(count));
          expect(find.byIcon(Icons.swap_horiz_rounded), findsNWidgets(count));
        default:
          // 墙布局会循环、数量不少于数据条数且不超 100
          expect(find.byType(Image).evaluate().length, greaterThanOrEqualTo(count));
      }
    });
  }

  for (final (layoutText, slots) in [('卡片', 12), ('列表', 6)]) {
    testWidgets('$layoutText cyclic-fills slots with only 2 items', (tester) async {
      const count = 2;
      final dir = Directory.systemTemp.createTempSync('walltest');
      final imgFile = File('${dir.path}/p.png')..writeAsBytesSync(png);
      final items = [
        for (var i = 0; i < count; i++)
          JournalItem(
            path: imgFile.path,
            title: 'm $i',
            type: 'movie',
            data: null,
            date: DateTime(2026, 11, i + 1),
          ),
      ];

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: JournalPosterPage(
          anchorMonth: DateTime(2026, 11),
          items: items,
          typeColor: (_) => const Color(0xFF4A90D9),
          typeLabel: (_) => '影视',
          typeIcon: (_) => Icons.movie_outlined,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('布局'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(layoutText).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final redBadges = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFFE53935),
      );
      expect(redBadges, findsNWidgets(slots));
      if (layoutText == '卡片') {
        expect(
          find.descendant(of: find.byType(GridView), matching: find.byType(Image)),
          findsNWidgets(slots),
        );
      } else {
        // 全页 Image 含品牌行 1 张
        expect(find.byType(Image), findsNWidgets(slots + 1));
      }
    });
  }

  testWidgets('layout switch shows loading indicator before content builds',
      (tester) async {
    const count = 20;
    final dir = Directory.systemTemp.createTempSync('walltest');
    final imgFile = File('${dir.path}/p.png')..writeAsBytesSync(png);
    final items = [
      for (var i = 0; i < count; i++)
        JournalItem(
          path: imgFile.path,
          title: 'm $i',
          type: 'movie',
          data: null,
          date: DateTime(2026, 11, (i % 28) + 1),
        ),
    ];

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JournalPosterPage(
        anchorMonth: DateTime(2026, 11),
        items: items,
        typeColor: (_) => const Color(0xFF4A90D9),
        typeLabel: (_) => '影视',
        typeIcon: (_) => Icons.movie_outlined,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('列表').last);
    // 只推进一帧：重内容尚未构建，先显示加载动画
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 下一帧后内容挂载，加载动画消失
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image).evaluate().length, greaterThanOrEqualTo(count));
  });

  testWidgets('cover picker lets user choose the poster for a slot', (tester) async {
    const count = 20;
    final dir = Directory.systemTemp.createTempSync('walltest');
    final imgFile = File('${dir.path}/p.png')..writeAsBytesSync(png);
    final items = [
      for (var i = 0; i < count; i++)
        JournalItem(
          path: imgFile.path,
          title: 'm $i',
          type: 'movie',
          data: null,
          date: DateTime(2026, 11, (i % 28) + 1),
        ),
    ];

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JournalPosterPage(
        anchorMonth: DateTime(2026, 11),
        items: items,
        typeColor: (_) => const Color(0xFF4A90D9),
        typeLabel: (_) => '影视',
        typeIcon: (_) => Icons.movie_outlined,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('列表').last);
    await tester.pumpAndSettle();

    // 初始首行展示 m 0，每行标题唯一
    expect(find.text('m 0'), findsOneWidget);
    expect(find.text('m 1'), findsOneWidget);

    // 点首行的选择封面按钮：弹出封面面板，列出当前筛选下的全部记录
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('选择封面'), findsOneWidget);
    // 列表布局下页面本身无 GridView，面板里的网格是唯一的；
    // 面板可滚动，离屏缩略图懒加载，只校验可见项已构建
    final sheetGrid = find.byType(GridView);
    expect(sheetGrid, findsOneWidget);
    expect(
      find.descendant(of: sheetGrid, matching: find.byType(Image)),
      findsWidgets,
    );
    // 当前格位（m 0）在面板里带选中角标
    expect(
      find.descendant(of: sheetGrid, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    // 用户手动选择 m 1：面板关闭，首行换成 m 1，其余行不变
    await tester.tap(
        find.descendant(of: sheetGrid, matching: find.text('m 1')));
    await tester.pumpAndSettle();
    expect(find.text('选择封面'), findsNothing);
    expect(find.text('m 0'), findsNothing);
    expect(find.text('m 1'), findsNWidgets(2));
    expect(find.text('m 2'), findsOneWidget);
  });
}
