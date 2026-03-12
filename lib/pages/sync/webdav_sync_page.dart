import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/toast_util.dart';
import '../../utils/sync/webdav_service.dart';
import '../../providers/app_provider.dart';

/// WebDAV 备份页面
class WebDAVSyncPage extends StatefulWidget {
  const WebDAVSyncPage({super.key});

  @override
  State<WebDAVSyncPage> createState() => _WebDAVSyncPageState();
}

class _WebDAVSyncPageState extends State<WebDAVSyncPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController(text: '/mooknote');
  
  bool _isLoading = false;
  bool _isConfigured = false;
  bool _obscurePassword = true;
  SyncDirection _syncDirection = SyncDirection.upload;
  
  @override
  void initState() {
    super.initState();
    _loadConfig();
  }
  
  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }
  
  /// 加载已保存的配置
  Future<void> _loadConfig() async {
    final config = await WebDAVService.instance.getConfig();
    if (config != null) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _pathController.text = config['path'] ?? '/mooknote';
        _isConfigured = true;
      });
    }
  }
  
  /// 保存配置
  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final path = _pathController.text.trim();
    
    if (url.isEmpty) {
      ToastUtil.show(context, '请输入服务器地址');
      return;
    }
    if (username.isEmpty) {
      ToastUtil.show(context, '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      ToastUtil.show(context, '请输入密码');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 测试连接
      final result = await WebDAVService.instance.testConnection(
        url: url,
        username: username,
        password: password,
        path: path,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // 保存配置
        await WebDAVService.instance.saveConfig(
          url: url,
          username: username,
          password: password,
          path: path,
        );
        
        setState(() => _isConfigured = true);
        ToastUtil.show(context, result['message'] ?? '连接成功，配置已保存');
        
        // 连接成功后停留在当前页面，不返回上级
      } else {
        ToastUtil.show(context, result['message'] ?? '连接失败，请检查配置');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '连接失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 执行同步
  Future<void> _syncData() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await WebDAVService.instance.syncData(direction: _syncDirection);
      
      if (!mounted) return;
      
      if (result.success) {
        final details = '上传: ${result.uploadedFiles} 文件, ${result.uploadedImages} 图片\n'
                       '下载: ${result.downloadedFiles} 文件, ${result.downloadedImages} 图片';
        
        // 如果需要重新加载数据（下载了数据库）
        if (result.needReload) {
          // 显示提示
          ToastUtil.show(context, '数据已更新，正在重新加载...');
          
          // 重新加载所有数据
          final provider = context.read<AppProvider>();
          await provider.loadMovies();
          await provider.loadBooks();
          await provider.loadNotes();
          
          if (mounted) {
            _showSyncResultDialog('同步成功（数据已刷新）', details);
          }
        } else {
          _showSyncResultDialog('同步成功', details);
        }
      } else {
        ToastUtil.show(context, result.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '同步失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 显示同步结果对话框
  void _showSyncResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 清除配置
  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('清除配置'),
        content: const Text('确定要清除 WebDAV 配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await WebDAVService.instance.clearConfig();
      setState(() {
        _urlController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _pathController.text = '/mooknote';
        _isConfigured = false;
      });
      if (mounted) {
        ToastUtil.show(context, '配置已清除');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('WebDAV 备份'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 状态提示
                  if (_isConfigured)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        border: Border(
                          left: BorderSide(color: Color(0xFF1A1A1A), width: 4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF1A1A1A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            '已配置 WebDAV',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 服务器地址
                  _buildTextField(
                    controller: _urlController,
                    label: '服务器地址',
                    hint: 'https://dav.example.com 或 http://192.168.1.1:5244',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),
                  
                  // 用户名
                  _buildTextField(
                    controller: _usernameController,
                    label: '用户名',
                    hint: '请输入用户名',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  
                  // 密码
                  _buildTextField(
                    controller: _passwordController,
                    label: '密码',
                    hint: '请输入密码',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF999999),
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 同步路径
                  _buildTextField(
                    controller: _pathController,
                    label: '同步路径',
                    hint: '/mooknote',
                    icon: Icons.folder_outlined,
                  ),
                  const SizedBox(height: 24),
                  
                  // 保存配置按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '测试并保存',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  if (_isConfigured) ...[
                    const SizedBox(height: 24),
                    
                    // 同步方向选择
                    const Text(
                      '同步方向',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDirectionButton(
                            '上传',
                            SyncDirection.upload,
                            Icons.upload,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDirectionButton(
                            '下载',
                            SyncDirection.download,
                            Icons.download,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 同步按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _syncData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A1A),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: Color(0xFF1A1A1A)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '立即同步',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 清除配置按钮
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isLoading ? null : _clearConfig,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('清除配置'),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // 说明
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 支持坚果云、Nextcloud、AList 等 WebDAV 服务\n'
                          '• 服务器地址需包含协议（http:// 或 https://）\n'
                          '• 同步前请确保服务器可用且空间充足\n'
                          '• 首次同步将上传所有数据，后续只同步变更',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
            prefixIcon: Icon(icon, color: const Color(0xFF999999)),
            suffixIcon: suffixIcon,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF1A1A1A)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDirectionButton(String label, SyncDirection direction, IconData icon) {
    final isSelected = _syncDirection == direction;
    return GestureDetector(
      onTap: () => setState(() => _syncDirection = direction),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : const Color(0xFF666666),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
