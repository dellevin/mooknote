import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/note_list_item.dart';

/// 笔记标签页
class NoteTabPage extends StatelessWidget {
  const NoteTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 笔记列表（无状态筛选，显示所有笔记）
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
        final notes = provider.notes;
        
        if (notes.isEmpty) {
          return _buildEmptyState(context);
        }
        
        return RefreshIndicator(
          onRefresh: () async => await provider.loadNotes(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return NoteListItem(note: notes[index]);
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
          Icon(
            Icons.note_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无笔记',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加笔记'),
            onPressed: () {
              Navigator.pushNamed(context, '/note-form');
            },
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
