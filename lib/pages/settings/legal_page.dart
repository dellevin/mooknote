import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import '../../utils/server_config.dart';

/// 用户服务协议 / 隐私政策查看页面
class LegalPage extends StatefulWidget {
  final String slug;
  final String title;

  const LegalPage({super.key, required this.slug, required this.title});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  static final String _baseUrl = ServerConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/pages/${widget.slug}'),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _content = data['content'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '暂无内容';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? _buildError(colors)
              : _buildContent(colors),
    );
  }

  Widget _buildContent(ColorScheme colors) {
    return Markdown(
      data: _content,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
        p: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.8),
        code: TextStyle(fontSize: 13, color: colors.onSurface, backgroundColor: colors.surfaceContainerHighest),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.onSurface.withValues(alpha: 0.4), width: 4)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        listBullet: TextStyle(fontSize: 14, color: colors.onSurface),
        listIndent: 24,
        a: const TextStyle(fontSize: 14, color: Color(0xFF4A90D9), decoration: TextDecoration.underline),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _load(); },
            child: Text('重试', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
}
