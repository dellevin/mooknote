import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../widgets/app_back_button.dart';
import '../../l10n/app_strings.dart';

/// 豆瓣 WebView 登录页：用户手动登录后，从 CookieManager 收割 dbcl2 等 cookie 返回。
/// 返回值为 cookie 的 JSON 字符串；用户取消返回 null。
class DoubanLoginPage extends StatefulWidget {
  const DoubanLoginPage({super.key});

  @override
  State<DoubanLoginPage> createState() => _DoubanLoginPageState();
}

class _DoubanLoginPageState extends State<DoubanLoginPage> {
  bool _loading = true;
  bool _harvesting = false;

  /// dbcl2 种在 .douban.com 下，登录在 accounts 子站完成，两个 URL 都查一遍
  static const _cookieUrls = [
    'https://www.douban.com',
    'https://accounts.douban.com',
  ];

  Future<void> _tryHarvest() async {
    if (_harvesting) return;
    _harvesting = true;
    try {
      final cookies = <String, String>{};
      for (final url in _cookieUrls) {
        final list = await CookieManager.instance()
            .getCookies(url: WebUri(url));
        for (final c in list) {
          if (c.name == 'dbcl2' || c.name == 'bid' || c.name == 'ck') {
            cookies[c.name] = c.value ?? '';
          }
        }
      }
      if (!cookies.containsKey('dbcl2') || cookies['dbcl2']!.isEmpty) return;
      if (!mounted) return;
      Navigator.pop(context, jsonEncode(cookies));
    } finally {
      _harvesting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('豆瓣登录'.tr),
        actions: [
          TextButton(
            onPressed: _tryHarvest,
            child: Text(
              '我已登录'.tr,
              style: TextStyle(
                  fontSize: 13,
                  color: colors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri('https://accounts.douban.com/passport/login')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              // 桌面 UA，与 DoubanService 请求头保持一致，降低风控差异
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            ),
            onLoadStart: (_, __) {
              if (mounted) setState(() => _loading = true);
            },
            onLoadStop: (_, __) async {
              if (mounted) setState(() => _loading = false);
              await _tryHarvest();
            },
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
