import 'package:flutter/material.dart';
import '../../../core/constants/play_types.dart';
import '../../../core/theme/app_theme.dart';

class PlayTypeChips extends StatefulWidget {
  final String selectedPlayType;
  final ValueChanged<String> onChanged;

  const PlayTypeChips({super.key, required this.selectedPlayType, required this.onChanged});

  @override
  State<PlayTypeChips> createState() => _PlayTypeChipsState();
}

class _PlayTypeChipsState extends State<PlayTypeChips> {
  final Set<String> _expandedCategories = {'基础三码'};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选择玩法', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              GestureDetector(
                onTap: () {
                  setState(() {
                    final isAllExpanded = _expandedCategories.length == PlayTypes.categories.length;
                    if (isAllExpanded) {
                      _expandedCategories.clear();
                      _expandedCategories.add('基础三码');
                    } else {
                      _expandedCategories.clear();
                      _expandedCategories.addAll(PlayTypes.categories);
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expandedCategories.length == PlayTypes.categories.length ? '全部收起' : '全部展开',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expandedCategories.length == PlayTypes.categories.length ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildAutoChip(),
          const SizedBox(height: 8),
          ...PlayTypes.categories.map((cat) => _buildCategorySection(cat)),
        ],
      ),
    );
  }

  Widget _buildAutoChip() {
    final isAuto = widget.selectedPlayType == 'auto';
    return GestureDetector(
      onTap: () => widget.onChanged('auto'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAuto ? AppColors.primary : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isAuto ? AppColors.primary : Colors.transparent, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 14, color: isAuto ? Colors.white : AppColors.primary),
          const SizedBox(width: 4),
          Text('自动识别', style: TextStyle(color: isAuto ? Colors.white : AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (isAuto) ...[
            const SizedBox(width: 4),
            Text('智能匹配每行玩法', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ]),
      ),
    );
  }

  Widget _buildCategorySection(String category) {
    final isExpanded = _expandedCategories.contains(category);
    final types = PlayTypes.getByCategory(category);
    final selectedInCategory = types.any((pt) => pt.code == widget.selectedPlayType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category);
              } else {
                _expandedCategories.add(category);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: selectedInCategory ? AppColors.primary.withAlpha(20) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(isExpanded ? Icons.expand_less : Icons.chevron_right, size: 16, color: selectedInCategory ? AppColors.primary : AppColors.textLight),
                const SizedBox(width: 4),
                Text(category, style: TextStyle(fontSize: 12, color: selectedInCategory ? AppColors.primary : AppColors.textLight, fontWeight: selectedInCategory ? FontWeight.w600 : FontWeight.w500)),
                if (selectedInCategory) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Wrap(spacing: 6, runSpacing: 6, children: types.map((pt) => _buildChip(pt)).toList()),
          ),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }

  Widget _buildChip(PlayTypeConfig pt) {
    final isSelected = widget.selectedPlayType == pt.code;
    return GestureDetector(
      onTap: () => widget.onChanged(pt.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? pt.color : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? pt.color : Colors.transparent, width: 1),
        ),
        child: Text(pt.name, style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}
