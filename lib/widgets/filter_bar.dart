import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  const FilterBar({super.key, required this.selectedFilter, required this.onFilterChanged});

  static const List<Map<String, dynamic>> filters = [
    {'label': '全部', 'value': 'all', 'icon': Icons.list},
    {'label': '福彩3D', 'value': 'fc', 'icon': Icons.casino},
    {'label': '排列三', 'value': 'pl', 'icon': Icons.shuffle},
    {'label': '今天', 'value': 'today', 'icon': Icons.today},
    {'label': '本周', 'value': 'week', 'icon': Icons.date_range},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusXs)),
      child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 4), itemCount: filters.length, separatorBuilder: (_, __) => const SizedBox(width: 4), itemBuilder: (context, index) {
        final f = filters[index];
        final isSelected = selectedFilter == f['value'];
        return GestureDetector(onTap: () => onFilterChanged(f['value'] as String), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(f['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary), const SizedBox(width: 4), Text(f['label'] as String, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? Colors.white : AppColors.textSecondary))])));
      }),
    );
  }
}
