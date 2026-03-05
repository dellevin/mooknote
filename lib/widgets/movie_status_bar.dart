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
          color: Colors.white,
          child: Row(
            children: [
              _buildStatusItem(
                '已看',
                0,
                provider.movieStatusIndex,
                () => provider.setMovieStatusIndex(0),
              ),
              const SizedBox(width: 24),
              _buildStatusItem(
                '想看',
                1,
                provider.movieStatusIndex,
                () => provider.setMovieStatusIndex(1),
              ),
              const SizedBox(width: 24),
              _buildStatusItem(
                '在看',
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
    String label,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
        ),
      ),
    );
  }
}
