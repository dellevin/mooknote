import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../../data/epub/reader_models.dart';

/// EPUB 解析器 - 从 ZIP 归档中解析 EPUB 结构
class EpubParser {
  /// 从文件路径解析 EPUB
  Future<EpubBookInfo?> parseFromFile(String filePath,
      {String? fileName}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      return _parseFromArchive(archive, fileName: fileName);
    } catch (e) {
      return null;
    }
  }

  EpubBookInfo? _parseFromArchive(Archive archive, {String? fileName}) {
    try {
      // 检查加密（只拒绝真正阻止内容读取的加密，忽略字体混淆等）
      final encFile = archive.findFile('META-INF/encryption.xml');
      if (encFile != null) {
        try {
          final encContent = utf8.decode(encFile.content as List<int>);
          final encDoc = XmlDocument.parse(encContent);
          // 如果有 EncryptedData 且不是字体文件，则拒绝
          final encryptedData = encDoc.findAllElements('EncryptedData');
          for (final ed in encryptedData) {
            final cipherRef = ed.findAllElements('CipherReference').firstOrNull;
            final uri = cipherRef?.getAttribute('URI') ?? '';
            // 非字体文件被加密 → 真正的 DRM
            if (!uri.endsWith('.ttf') &&
                !uri.endsWith('.otf') &&
                !uri.endsWith('.woff') &&
                !uri.endsWith('.woff2')) {
              debugPrint('[EpubParser] 内容加密的 EPUB，不支持: $uri');
              return null;
            }
          }
          debugPrint('[EpubParser] 仅字体混淆，继续解析');
        } catch (e) {
          debugPrint('[EpubParser] encryption.xml 解析失败，跳过: $e');
        }
      }

      final opfPath = _findOpfPath(archive);
      debugPrint('[EpubParser] OPF 路径: $opfPath');
      if (opfPath == null) return null;

      final opfFile = archive.findFile(opfPath);
      debugPrint('[EpubParser] OPF 文件: ${opfFile != null ? '找到' : '未找到'}');
      if (opfFile == null) return null;

      final opfContent = utf8.decode(opfFile.content as List<int>);
      debugPrint('[EpubParser] OPF 内容长度: ${opfContent.length}');
      return _parseOpf(opfContent, opfPath, archive, fileName);
    } catch (e, stack) {
      debugPrint('[EpubParser] _parseFromArchive 失败: $e');
      debugPrint('[EpubParser] $stack');
      return null;
    }
  }

  /// 查找 OPF 文件路径
  String? _findOpfPath(Archive archive) {
    // 策略1: 解析 container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile != null) {
      try {
        final content = utf8.decode(containerFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        final rootfile = doc.findAllElements('rootfile').firstOrNull;
        if (rootfile != null) {
          final fullPath = rootfile.getAttribute('full-path');
          if (fullPath != null) return fullPath;
        }
      } catch (_) {}
    }

    // 策略2: 常见路径
    const commonPaths = [
      'content.opf',
      'OEBPS/content.opf',
      'OPS/content.opf',
      'EPUB/content.opf',
    ];
    for (final path in commonPaths) {
      if (archive.findFile(path) != null) return path;
    }

    // 策略3: 扫描 .opf 文件
    for (final file in archive.files) {
      if (file.name.endsWith('.opf')) return file.name;
    }

    return null;
  }

  /// 解析 OPF 文件
  EpubBookInfo? _parseOpf(
      String content, String opfPath, Archive archive, String? fileName) {
    final opfDir =
        opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/')) : '';

    final doc = XmlDocument.parse(content);
    final package = doc.rootElement;
    final version = package.getAttribute('version') ?? '2.0';

    final metadata = package.findElements('metadata').firstOrNull;
    final manifest = package.findElements('manifest').firstOrNull;
    final spine = package.findElements('spine').firstOrNull;
    debugPrint('[EpubParser] metadata=${metadata != null}, manifest=${manifest != null}, spine=${spine != null}');
    if (metadata == null || manifest == null || spine == null) return null;

    // 解析 manifest (id -> href)
    final manifestMap = <String, String>{};
    final manifestProperties = <String, String>{};
    for (final item in manifest.findElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final properties = item.getAttribute('properties');
      if (id != null && href != null) {
        manifestMap[id] = _resolveRelativePath(opfDir, _normalizePath(href));
        if (properties != null) manifestProperties[id] = properties;
      }
    }

    // 解析 metadata
    final titles = _findByLocalName(metadata, 'title')
        .map((e) => e.innerText.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final authors = _findByLocalName(metadata, 'creator')
        .map((e) => e.innerText.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    final description =
        _findByLocalName(metadata, 'description').firstOrNull?.innerText.trim();

    // 解析 spine
    final spineItems = <SpineItem>[];
    final spineIndexMap = <String, int>{};
    int index = 0;
    for (final itemref in spine.findElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      final linearAttr = itemref.getAttribute('linear');
      final isLinear =
          linearAttr == null || linearAttr.toLowerCase() != 'no';
      if (idref != null && manifestMap.containsKey(idref)) {
        final href = manifestMap[idref]!;
        spineItems.add(SpineItem(
          index: index,
          href: href,
          idref: idref,
          linear: isLinear,
        ));
        spineIndexMap[href] = index;
        index++;
      }
    }

    // 解析 TOC
    List<TocEntry> toc = [];

    // EPUB 3 NAV 文档
    String? navId;
    for (final entry in manifestProperties.entries) {
      if (_containsWholeWord(entry.value, 'nav')) {
        navId = entry.key;
        break;
      }
    }
    if (navId != null && manifestMap.containsKey(navId)) {
      final navPath = manifestMap[navId]!;
      final navFile = archive.findFile(navPath);
      if (navFile != null) {
        try {
          final navContent = utf8.decode(navFile.content as List<int>);
          final navDir = navPath.contains('/')
              ? navPath.substring(0, navPath.lastIndexOf('/'))
              : '';
          toc = _parseNav(navContent, navDir, spineIndexMap);
        } catch (_) {}
      }
    }

    // EPUB 2 NCX 回退
    if (toc.isEmpty) {
      final tocId = spine.getAttribute('toc');
      if (tocId != null && manifestMap.containsKey(tocId)) {
        final tocPath = manifestMap[tocId]!;
        final tocFile = archive.findFile(tocPath);
        if (tocFile != null) {
          try {
            final tocContent = utf8.decode(tocFile.content as List<int>);
            final ncxDir = tocPath.contains('/')
                ? tocPath.substring(0, tocPath.lastIndexOf('/'))
                : '';
            toc = _parseNcx(tocContent, ncxDir, spineIndexMap);
          } catch (_) {}
        }
      }
    }

    // 最终回退: 从 spine 生成平坦目录
    if (toc.isEmpty) {
      int chNum = 1;
      for (final si in spineItems) {
        if (!si.linear) continue;
        toc.add(TocEntry(
          label: '第 $chNum 章',
          href: '${si.href}#top',
          spineIndex: si.index,
        ));
        chNum++;
      }
    }

    // 检测封面
    String? coverHref = _detectCover(metadata, manifestMap, manifestProperties, archive, opfDir);

    final title = titles.isNotEmpty
        ? titles.first
        : (fileName ?? '').split('/').last.split('.').first;

    return EpubBookInfo(
      title: title,
      author: authors.isNotEmpty ? authors.first : '',
      authors: authors,
      description: description,
      coverHref: coverHref,
      opfRootPath: opfPath,
      epubVersion: version,
      spine: spineItems,
      toc: toc,
    );
  }

  /// 检测封面图片路径（相对于 OPF 目录）
  String? _detectCover(
    XmlElement metadata,
    Map<String, String> manifestMap,
    Map<String, String> manifestProperties,
    Archive archive,
    String opfDir,
  ) {
    // 策略1: meta name="cover"
    final coverMeta = metadata
        .findAllElements('meta')
        .where((e) => e.getAttribute('name') == 'cover')
        .firstOrNull;
    if (coverMeta != null) {
      final coverId = coverMeta.getAttribute('content');
      if (coverId != null && manifestMap.containsKey(coverId)) {
        final href = manifestMap[coverId]!;
        if (_isImageFile(href)) return href;
      }
    }

    // 策略2: manifest 属性包含 cover-image
    for (final entry in manifestProperties.entries) {
      if (_containsWholeWord(entry.value, 'cover-image')) {
        if (manifestMap.containsKey(entry.key)) {
          final href = manifestMap[entry.key]!;
          if (_isImageFile(href)) return href;
        }
      }
    }

    // 策略3: 常见文件名
    for (final key in manifestMap.keys) {
      final lower = key.toLowerCase();
      if (lower == 'cover.jpg' ||
          lower == 'cover.png' ||
          lower == 'cover.jpeg' ||
          lower == 'cover.webp') {
        return manifestMap[key]!;
      }
    }

    // 策略4: guide 中的 cover 引用
    final guideElement = XmlDocument.parse(
            '<root>${metadata.parent?.toXmlString() ?? ''}</root>')
        .rootElement
        .findElements('guide')
        .firstOrNull;
    if (guideElement != null) {
      for (final ref in guideElement.findElements('reference')) {
        final type = ref.getAttribute('type') ?? '';
        if (type.toLowerCase() == 'cover') {
          final href = ref.getAttribute('href');
          if (href != null) {
            final resolved = _resolveRelativePath(opfDir, href);
            if (_isImageFile(resolved)) return resolved;
            // href 可能指向一个 XHTML 文件，需要从中提取图片
            final coverFile = archive.findFile(resolved);
            if (coverFile != null) {
              try {
                final html = utf8.decode(coverFile.content as List<int>);
                final imgSrc = _extractFirstImage(html);
                if (imgSrc != null) {
                  final hrefDir = resolved.contains('/')
                      ? resolved.substring(0, resolved.lastIndexOf('/'))
                      : '';
                  return _resolveRelativePath(hrefDir, imgSrc);
                }
              } catch (_) {}
            }
          }
        }
      }
    }

    return null;
  }

  String? _extractFirstImage(String html) {
    final imgReg = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
    final match = imgReg.firstMatch(html);
    return match?.group(1);
  }

  /// 解析 EPUB 3 NAV 文档
  List<TocEntry> _parseNav(
      String content, String navDir, Map<String, int> spineIndexMap) {
    try {
      final doc = XmlDocument.parse(content);
      final navElement = doc.findAllElements('nav').where((el) {
        final epubType = el.getAttribute('epub:type') ??
            el.getAttribute('type') ??
            '';
        return _containsWholeWord(epubType, 'toc');
      }).firstOrNull;
      if (navElement == null) return [];

      final rootOl = navElement.childElements
          .where((el) => el.localName == 'ol')
          .firstOrNull;
      if (rootOl == null) return [];

      return _parseNavListItems(rootOl.findElements('li'), navDir, spineIndexMap);
    } catch (_) {
      return [];
    }
  }

  List<TocEntry> _parseNavListItems(
      Iterable<XmlElement> items, String baseDir, Map<String, int> spineIndexMap) {
    final entries = <TocEntry>[];
    for (final li in items) {
      final anchor = li.childElements
          .where((el) => el.localName == 'a' || el.localName == 'span')
          .firstOrNull;
      final label =
          anchor?.innerText.trim().isNotEmpty == true ? anchor!.innerText.trim() : 'Chapter';
      final hrefValue =
          anchor?.localName == 'a' ? anchor!.getAttribute('href') : null;

      String href = '';
      int spineIdx = -1;
      if (hrefValue != null && hrefValue.trim().isNotEmpty) {
        final resolved = _resolveRelativePath(baseDir, hrefValue);
        href = resolved;
        final pathOnly = href.split('#').first;
        spineIdx = spineIndexMap[pathOnly] ?? -1;
      }

      final nestedOl = li.childElements
          .where((el) => el.localName == 'ol')
          .firstOrNull;
      final children = nestedOl != null
          ? _parseNavListItems(nestedOl.findElements('li'), baseDir, spineIndexMap)
          : <TocEntry>[];

      entries.add(TocEntry(
        label: label,
        href: href,
        spineIndex: spineIdx,
        children: children,
      ));
    }
    return entries;
  }

  /// 解析 EPUB 2 NCX 文档
  List<TocEntry> _parseNcx(
      String content, String baseDir, Map<String, int> spineIndexMap) {
    try {
      final doc = XmlDocument.parse(content);
      final navMap = doc.findAllElements('navMap').firstOrNull;
      if (navMap == null) return [];
      return _parseNavPoints(navMap.findElements('navPoint'), baseDir, spineIndexMap);
    } catch (_) {
      return [];
    }
  }

  List<TocEntry> _parseNavPoints(
      Iterable<XmlElement> navPoints, String baseDir, Map<String, int> spineIndexMap) {
    final entries = <TocEntry>[];
    for (final np in navPoints) {
      final label = np
              .findElements('navLabel')
              .firstOrNull
              ?.findElements('text')
              .firstOrNull
              ?.innerText
              .trim() ??
          'Chapter';
      final src = np.findElements('content').firstOrNull?.getAttribute('src') ?? '';

      final resolved = _resolveRelativePath(baseDir, src);
      final pathOnly = resolved.split('#').first;
      final spineIdx = spineIndexMap[pathOnly] ?? -1;

      final children = _parseNavPoints(np.findElements('navPoint'), baseDir, spineIndexMap);

      entries.add(TocEntry(
        label: label,
        href: resolved,
        spineIndex: spineIdx,
        children: children,
      ));
    }
    return entries;
  }

  // ─── 辅助方法 ─────────────────────────────────────────────────

  Iterable<XmlElement> _findByLocalName(XmlElement parent, String name) {
    return parent.descendantElements.where((e) => e.localName == name);
  }

  bool _containsWholeWord(String? value, String word) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false)
        .hasMatch(value);
  }

  String _resolveRelativePath(String baseDir, String relativePath) {
    if (baseDir.isEmpty) return relativePath;
    final baseUri = Uri.parse(baseDir.endsWith('/') ? baseDir : '$baseDir/');
    final resolved = baseUri.resolve(relativePath);
    String result = resolved.toString();
    if (result.startsWith('/')) result = result.substring(1);
    return Uri.decodeFull(result);
  }

  String _normalizePath(String path) {
    path = path.trim();
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    path = path.replaceAll(RegExp(r'/+'), '/');
    return path;
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }
}
