import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 观影状态选择栏 - 极简主义设计
class MovieStatusBar extends StatelessWidget {
  const MovieStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              _buildStatusItem(
                context,
                '已看',
                0,
                provider.movieStatusIndex,
                () => provider.setMovieStatusIndex(0),
              ),
              const SizedBox(width: 16),
              _buildStatusItem(
                context,
                '在看',
                1,
                provider.movieStatusIndex,
                () => provider.setMovieStatusIndex(1),
              ),
              const SizedBox(width: 16),
              _buildStatusItem(
                context,
                '想看',
                2,
                provider.movieStatusIndex,
                () => provider.setMovieStatusIndex(2),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建状态项
  Widget _buildStatusItem(
    BuildContext context,
    String label,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    
    Color color;
    // 0:已看(深色), 1:在看(中灰), 2:想看(浅灰)
    switch (index) {
      case 0:
        color = const Color(0xFF1A1A1A);
        break;
      case 1:
        color = const Color(0xFF666666);
        break;
      case 2:
        color = const Color(0xFF999999);
        break;
      default:
        color = const Color(0xFFCCCCCC);
    }
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
