import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/douban_service.dart';

/// 豆瓣封面加载组件。
/// doubanio 防盗链同时校验 Referer 与浏览器 UA，Flutter 自带
/// Image.network 的内部 HttpClient 即使带 header 仍会被 403/418 拦截，
/// 故统一用 package:http（与搜索接口同链路，已验证 200）拉取字节后
/// 交由 Image.memory 渲染。
class DoubanNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget placeholder;

  const DoubanNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  @override
  State<DoubanNetworkImage> createState() => _DoubanNetworkImageState();
}

class _DoubanNetworkImageState extends State<DoubanNetworkImage> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DoubanNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) return;
    try {
      final resp = await http
          .get(Uri.parse(widget.url), headers: doubanImageHeaders)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        // ── 临时诊断：确认稳定后删除 ──
        debugPrint('[Douban][img] fetch non-200 url=${widget.url} '
            'status=${resp.statusCode} bytes=${resp.bodyBytes.length}');
        if (mounted) setState(() => _error = resp.statusCode);
        return;
      }
      if (mounted) setState(() => _bytes = resp.bodyBytes);
    } catch (e) {
      // ── 临时诊断：确认稳定后删除 ──
      debugPrint('[Douban][img] fetch exception url=${widget.url} '
          'error=${e.runtimeType}: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: widget.fit);
    }
    if (_error != null) return widget.placeholder;
    return widget.placeholder;
  }
}
