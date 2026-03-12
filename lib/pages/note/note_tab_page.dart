import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/note_list_item.dart';

/// 笔记标签页
class NoteTabPage extends StatefulWidget {
  const NoteTabPage({super.key});

  @override
  State<NoteTabPage> createState() => _NoteTabPageState();
}

class _NoteTabPageState extends State<NoteTabPage> {
  // 使用分页加载
  static const int _pageSize = 50;
  final List<Note> _displayedNotes = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 延迟加载初始数据，避免阻塞UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreNotes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotes();
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    // 使用微任务延迟加载，避免阻塞UI
    await Future.microtask(() {
      final provider = context.read<AppProvider>();
      final allNotes = provider.notes;
      
      final startIndex = _displayedNotes.length;
      final endIndex = (startIndex + _pageSize).clamp(0, allNotes.length);
      
      if (startIndex >= allNotes.length) {
        _hasMore = false;
      } else {
        final newNotes = allNotes.sublist(startIndex, endIndex);
        _displayedNotes.addAll(newNotes);
        _hasMore = endIndex < allNotes.length;
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    final provider = context.read<AppProvider>();
    await provider.loadNotes();
    setState(() {
      _displayedNotes.clear();
      _hasMore = true;
    });
    await _loadMoreNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 笔记列表（分页加载）
        Expanded(
          child: _buildNoteList(context),
        ),
      ],
    );
  }

  /// 构建笔记列表
  Widget _buildNoteList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final allNotes = provider.notes;
        
        if (allNotes.isEmpty && _displayedNotes.isEmpty) {
          return _buildEmptyState(context);
        }
        
        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF1A1A1A),
          backgroundColor: Colors.white,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _displayedNotes.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _displayedNotes.length) {
                // 底部加载指示器
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                );
              }
              return NoteListItem(note: _displayedNotes[index]);
            },
          ),
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.note_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无笔记',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/note-form');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
              ),
              child: const Text(
                '添加笔记',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取示例笔记数据
  List<Note> _getSampleNotes() {
    final now = DateTime.now();
    // 示例数据（实际应从数据库获取）
    return [
      Note(
        id: '1',
        content: '今天开始学习 Flutter 框架，感觉和 Vue 有很多相似之处，都是声明式 UI，组件化开发。Widget 的概念很有趣，一切皆 Widget。',
        tags: ['学习', 'Flutter', '编程'],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Note(
        id: '2',
        content: '余华的《活着》真的是一部让人深思的作品。福贵的一生经历了太多的苦难，但他依然坚强地活着。生命的意义或许就在于活着本身。',
        tags: ['阅读', '感悟', '书籍'],
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      Note(
        id: '3',
        content: '诺兰的电影总是充满想象力。《星际穿越》将科幻与亲情完美结合，五维空间的呈现方式令人震撼。配乐也是一绝。',
        tags: ['观影', '科幻', '电影'],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      Note(
        id: '4',
        content: 'Pandas 库的 DataFrame 操作非常强大，可以方便地进行数据清洗和分析。需要多练习熟练掌握常用操作。',
        tags: ['Python', '数据分析', '技术'],
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
      Note(
        id: '5',
        content: '春天来了，天气渐暖。周末去公园散步，看到花开得很好。生活中的小确幸值得记录。',
        tags: ['生活', '随笔'],
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }
}
