import 'package:flutter/material.dart';
import '../../../core/utils/batch_parser.dart';
import '../../../core/theme/app_theme.dart';

class PreviewList extends StatefulWidget {
  final List<ParsedItem> items;
  const PreviewList({super.key, required this.items});

  @override
  State<PreviewList> createState() => _PreviewListState();
}

class _PreviewListState extends State<PreviewList> {
  bool _isExpanded = false;
  static const int _collapsedCount = 10;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final allItems = widget.items.length > BatchParser.previewMax ? widget.items.sublist(0, BatchParser.previewMax) : widget.items;
    final hiddenCount = widget.items.length - allItems.length;
    final needCollapse = allItems.length > _collapsedCount;
    final displayItems = (_isExpanded || !needCollapse) ? allItems : allItems.sublist(0, _collapsedCount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('预览列表 (${widget.items.length}注)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (hiddenCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('还有$hiddenCount条未显示', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 6) / 2;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayItems.asMap().entries.map((entry) => _buildItem(context, entry.key + 1, entry.value, itemWidth)).toList(),
              );
            },
          ),
          if (needCollapse) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withAlpha(26)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded ? '收起' : '展开全部 (${allItems.length}注)',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, ParsedItem item, double itemWidth) {
    final totalAmount = item.multiplier * item.baseAmount;

    return Container(
      width: itemWidth,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withAlpha(77),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withAlpha(77)),
      ),
      child: Row(
        children: [
          SizedBox(width: 18, child: Text('$index', style: const TextStyle(fontSize: 9, color: AppColors.textLight, fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(item.number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ),
          if (item.multiplier != 1.0)
            Container(
              margin: const EdgeInsets.only(left: 1),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(color: AppColors.warning.withAlpha(26), borderRadius: BorderRadius.circular(3)),
              child: Text('×${item.multiplier}', style: const TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.w600)),
            ),
          Container(
            margin: const EdgeInsets.only(left: 1),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: item.color.withAlpha(26),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(item.playTypeName, style: TextStyle(fontSize: 8, color: item.color, fontWeight: FontWeight.w500)),
          ),
          Container(
            margin: const EdgeInsets.only(left: 1),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.primary.withAlpha(77)),
            ),
            child: Text(totalAmount.toStringAsFixed(1), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
