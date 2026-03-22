import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 豆瓣影视WebView页面 - 用于抓取影视信息
class DoubanWebViewPage extends StatefulWidget {
  final String url;
  
  const DoubanWebViewPage({super.key, required this.url});
  
  @override
  State<DoubanWebViewPage> createState() => _DoubanWebViewPageState();
}

class _DoubanWebViewPageState extends State<DoubanWebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _canExtract = false;
  bool _isExtracting = false;  // 防止重复提取
  
  @override
  void initState() {
    super.initState();
    _initWebView();
  }
  
  @override
  void dispose() {
    // 清理 WebView 资源
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }
  
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _canExtract = url.contains('douban.com/subject');
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('豆瓣影视'),
        leading: _buildBackButton(),
        actions: [
          // 提取按钮 - 始终显示
          _buildActionButton(
            icon: Icons.auto_fix_high_outlined,
            onPressed: _showExtractedInfo,
            tooltip: '提取信息',
          ),
          // 刷新按钮
          _buildActionButton(
            icon: Icons.refresh,
            onPressed: () => _controller.reload(),
            tooltip: '刷新',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // 加载指示器
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),

    );
  }
  
  /// 构建返回按钮
  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 停止加载并返回
            _controller.loadRequest(Uri.parse('about:blank'));
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  /// 构建右上角操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
          ),
        ),
      ),
    );
  }
  
  /// 显示提取的信息对话框
  Future<void> _showExtractedInfo() async {
    // 先提取信息
    final movieInfo = await _extractMovieInfo();
    if (movieInfo == null) return;
    
    // 显示提取的信息
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            '提取的影视信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('标题', movieInfo['title']?.toString() ?? '未提取到'),
                _buildInfoRow('导演', movieInfo['director']?.toString() ?? '未提取到'),
                _buildInfoRow('类型', movieInfo['genres']?.toString() ?? '未提取到'),
                _buildInfoRow('上映日期', movieInfo['releaseDate']?.toString() ?? '未提取到'),
                if (movieInfo['summary'] != null)
                  _buildInfoRow('简介', movieInfo['summary'].toString().substring(0, 
                    movieInfo['summary'].toString().length > 100 ? 100 : movieInfo['summary'].toString().length) + '...'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消',
                style: TextStyle(color: Color(0xFF999999)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, movieInfo);
              },
              child: const Text(
                '使用此信息',
                style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 提取影视信息
  Future<Map<String, dynamic>?> _extractMovieInfo() async {
    // 检查是否已提取过，避免重复点击
    if (_isExtracting) return null;
    
    try {
      _isExtracting = true;
      
      // 显示加载提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // 执行JavaScript代码提取页面信息
      final result = await _controller.runJavaScriptReturningResult(r'''
        (function() {
          const info = {};
          
          // 获取标题 - 移动版页面
          const titleEl = document.querySelector('.sub-title');
          info.title = titleEl ? titleEl.textContent.trim() : '';
          
          // 获取年份 - 从 original-title 中提取
          const originalTitleEl = document.querySelector('.sub-original-title');
          if (originalTitleEl) {
            const yearMatch = originalTitleEl.textContent.match(/\((\d{4})\)/);
            info.year = yearMatch ? yearMatch[1] : '';
          } else {
            info.year = '';
          }
          
          // 获取封面图 - 从 sub-cover 中的 img 标签获取
          const coverEl = document.querySelector('.sub-cover img');
          if (coverEl) {
            let coverUrl = coverEl.src;
            // 将 webp 转换为 jpg 格式，提高兼容性
            if (coverUrl && coverUrl.includes('.webp')) {
              coverUrl = coverUrl.replace('.webp', '.jpg');
            }
            info.coverUrl = coverUrl;
          } else {
            info.coverUrl = '';
          }
          
          // 获取评分 - 移动版可能在 mark-item 中
          const ratingEl = document.querySelector('.rating-num') || document.querySelector('.score');
          info.rating = ratingEl ? ratingEl.textContent.trim() : '';
          
          // 获取导演 - 从演职员列表中找
          const directorEl = document.querySelector('.movie-celebrities .item__celebrity .role');
          if (directorEl && directorEl.textContent.includes('导演')) {
            const nameEl = directorEl.closest('.item__celebrity').querySelector('.name');
            info.director = nameEl ? nameEl.textContent.trim() : '';
          } else {
            info.director = '';
          }
          
          // 获取编剧 - 从演职员列表中找（匹配"编剧"或"剧本"）
          const writerEls = document.querySelectorAll('.movie-celebrities .item__celebrity');
          const writers = [];
          writerEls.forEach(el => {
            const roleEl = el.querySelector('.role');
            if (roleEl && (roleEl.textContent.includes('编剧') || roleEl.textContent.includes('剧本'))) {
              const nameEl = el.querySelector('.name');
              if (nameEl) writers.push(nameEl.textContent.trim());
            }
          });
          info.writers = writers;
          
          // 获取主演- 从演职员列表中找前5个
          const actorEls = document.querySelectorAll('.movie-celebrities .item__celebrity');
          const actors = [];
          actorEls.forEach(el => {
            const roleEl = el
            .querySelector('.role');
            if (roleEl && (
            roleEl.textContent.includes('配音') || 
            roleEl.textContent.includes('主演') || 
            roleEl.textContent.includes('演员') ||
            roleEl.textContent.includes('参演') ||  
            roleEl.textContent.includes('饰')
            )) {
              const nameEl = el.querySelector('.name');
              if (nameEl) actors.push(nameEl.textContent.trim());
            }
          });
          info.actors = actors;
          
          // 获取类型 - 从 sub-meta 或标签中提取
          const metaEl = document.querySelector('.sub-meta');
          if (metaEl) {
            const metaText = metaEl.textContent;
            const parts = metaText.split('/').map(s => s.trim());
            // 过滤出类型（通常是中文，不是日期，不是时长）
            info.genres = parts.filter(p => 
              p && !p.match(/^\d{4}/) && !p.includes('分钟') && !p.includes('上映')
            ).join(',');
          } else {
            info.genres = '';
          }
          
          // 获取上映日期
          if (metaEl) {
            const dateMatch = metaEl.textContent.match(/(\d{4}-\d{2}-\d{2})/);
            info.releaseDate = dateMatch ? dateMatch[1] : '';
          } else {
            info.releaseDate = '';
          }
          
          // 获取简介
          const summaryEl = document.querySelector('.subject-intro p');
          if (summaryEl) {
            info.summary = summaryEl.textContent.trim().substring(0, 500);
          } else {
            info.summary = '';
          }
          
          // 获取别名 - 从 original-title 中提取（去掉年份）
          if (originalTitleEl) {
            const fullText = originalTitleEl.textContent.trim();
            info.alternateTitles = [fullText.replace(/\s*\(\d{4}\)\s*$/, '')];
          } else {
            info.alternateTitles = [];
          }
          
          return JSON.stringify(info);
        })()
      ''');
      
      // 关闭加载提示
      if (mounted) Navigator.pop(context);
      
      // 解析提取的信息
      // result 是 JavaScript 执行结果，已经是 JSON 字符串（带引号的）
      final String jsonStr = result.toString();
      // 去除 Dart 字符串转义后外层可能多余的引号
      final String cleanJson = jsonStr.startsWith('"') && jsonStr.endsWith('"')
          ? jsonDecode(jsonStr) as String
          : jsonStr;
      final Map<String, dynamic> movieInfo = jsonDecode(cleanJson) as Map<String, dynamic>;
      
      return movieInfo;
    } catch (e) {
      // 关闭加载提示
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提取信息失败: $e')),
        );
      }
      return null;
    } finally {
      _isExtracting = false;
    }
  }
}
