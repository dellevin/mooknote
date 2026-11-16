import 'package:flutter/material.dart';
import 'douban_network_image.dart';

/// 在线封面统一加载组件。
/// 豆瓣图床（doubanio.com）有 Referer + 浏览器 UA 防盗链，走
/// DoubanNetworkImage 用 http 拉字节渲染；其他图床用常规 Image.network。
class CoverNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget placeholder;

  const CoverNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return placeholder;
    if (url.contains('doubanio.com')) {
      return DoubanNetworkImage(
          url: url, fit: fit, placeholder: placeholder);
    }
    return Image.network(url,
        fit: fit, errorBuilder: (_, __, ___) => placeholder);
  }
}
