/// EPUB 解析结果数据模型
library;

class EpubBookInfo {
  final String title;
  final String author;
  final List<String> authors;
  final String? description;
  final String? coverHref;
  final String opfRootPath;
  final String epubVersion;
  final List<SpineItem> spine;
  final List<TocEntry> toc;

  EpubBookInfo({
    required this.title,
    required this.author,
    required this.authors,
    this.description,
    this.coverHref,
    required this.opfRootPath,
    required this.epubVersion,
    required this.spine,
    required this.toc,
  });
}

class SpineItem {
  final int index;
  final String href;
  final String idref;
  final bool linear;

  SpineItem({
    required this.index,
    required this.href,
    required this.idref,
    this.linear = true,
  });
}

class TocEntry {
  final String label;
  final String href;
  final int spineIndex;
  final List<TocEntry> children;

  TocEntry({
    required this.label,
    required this.href,
    this.spineIndex = -1,
    this.children = const [],
  });

  /// 递归展平为列表（保留层级信息通过 depth）
  List<FlatTocItem> flatten() {
    final result = <FlatTocItem>[];
    _flattenRecursive(result, 0);
    return result;
  }

  void _flattenRecursive(List<FlatTocItem> list, int depth) {
    list.add(FlatTocItem(entry: this, depth: depth));
    for (final child in children) {
      child._flattenRecursive(list, depth + 1);
    }
  }
}

class FlatTocItem {
  final TocEntry entry;
  final int depth;
  FlatTocItem({required this.entry, required this.depth});
}
