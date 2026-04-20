import 'package:flutter/material.dart';
import '../../../core/utils/batch_parser.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/play_types.dart';

class PreviewList extends StatefulWidget {
  final List<ParsedItem> items;
  final void Function(int index, ParsedItem item)? onItemUpdated;
  const PreviewList({super.key, required this.items, this.onItemUpdated});

  @override
  State<PreviewList> createState() => _PreviewListState();
}

class _PreviewListState extends State<PreviewList> {
  bool _isExpanded = false;
  static const int _collapsedCount = 12;

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
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('预览列表 (${widget.items.length}条)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (hiddenCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning.withAlpha(26), borderRadius: BorderRadius.circular(10)), child: Text('还有$hiddenCount条未显示', style: TextStyle(fontSize: 11, color: AppColors.warning))),
          ]),
          const SizedBox(height: 6),
          Text('点击条目可单独修改玩法或金额', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const minItemWidth = 100.0;
              const spacing = 4.0;
              final crossCount = (constraints.maxWidth / minItemWidth).floor().clamp(2, 5);
              final itemWidth = (constraints.maxWidth - (crossCount - 1) * spacing) / crossCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: displayItems.asMap().entries.map((entry) => _buildItem(context, entry.key, entry.value, itemWidth)).toList(),
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
                      _isExpanded ? '收起' : '展开全部 (${allItems.length}条)',
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
    final isDefaultAmount = (totalAmount - item.baseAmount).abs() < 0.001;
    return GestureDetector(
      onTap: () => _showEditSheet(context, index, item),
      child: Container(
        width: itemWidth,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withAlpha(77),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${index + 1}', style: const TextStyle(fontSize: 8, color: AppColors.textLight, fontWeight: FontWeight.w500)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(item.number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
            ),
            if (!isDefaultAmount)
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text('${totalAmount.toStringAsFixed(2)}元', style: const TextStyle(fontSize: 7, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(item.playTypeName, style: TextStyle(fontSize: 7, color: item.color, fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(totalAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, int index, ParsedItem item) {
    String selectedPlayType = item.playType;
    double selectedPerBetAmount = item.multiplier * item.baseAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('编辑第${index + 1}条', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('号码: ${item.number}', style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('玩法', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildPlayTypeSelector(selectedPlayType, (code) {
                            setSheetState(() => selectedPlayType = code);
                          }),
                          const SizedBox(height: 16),
                          Text('每注金额(元)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildMultiplierSelector(selectedPerBetAmount, (val) {
                            setSheetState(() => selectedPerBetAmount = val);
                          }),
                          const SizedBox(height: 16),
                          _buildPreviewInfo(item, selectedPlayType, selectedPerBetAmount),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
                              ),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final config = PlayTypes.getByCode(selectedPlayType);
                                if (config != null) {
                                  item.playType = config.code;
                                  item.playTypeName = config.name;
                                  item.color = config.color;
                                  item.baseAmount = config.baseAmount;
                                }
                                item.multiplier = item.baseAmount > 0 ? selectedPerBetAmount / item.baseAmount : 1.0;
                                item.isMultiplierCustomized = true;
                                widget.onItemUpdated?.call(index, item);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
                              ),
                              child: const Text('确认修改'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlayTypeSelector(String selectedCode, ValueChanged<String> onChanged) {
    final categories = PlayTypes.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((category) {
        final items = PlayTypes.getByCategory(category);
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 6),
              child: Text(category, style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: items.map((pt) {
                final isSelected = pt.code == selectedCode;
                return GestureDetector(
                  onTap: () => onChanged(pt.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? pt.color : AppColors.primaryLight.withAlpha(128),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? pt.color : Colors.transparent, width: 1),
                    ),
                    child: Text(
                      pt.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMultiplierSelector(double currentAmount, ValueChanged<double> onChanged) {
    final quickAmounts = [0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: quickAmounts.map((m) {
            final isSelected = (currentAmount - m).abs() < 0.001;
            return GestureDetector(
              onTap: () => onChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primaryLight.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1),
                ),
                child: Text(
                  '${m}元',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('自定义: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: currentAmount.toString(),
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.textLight),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.primaryLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) onChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewInfo(ParsedItem item, String playTypeCode, double perBetAmount) {
    final config = PlayTypes.getByCode(playTypeCode);
    final playTypeName = config?.name ?? item.playTypeName;
    final color = config?.color ?? item.color;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withAlpha(77),
        borderRadius: BorderRadius.circular(AppStyles.radiusXs),
        border: Border.all(color: AppColors.border.withAlpha(77)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('修改后预览', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(item.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                    child: Text(playTypeName, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.warning.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                    child: Text('${perBetAmount.toStringAsFixed(2)}元/注', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('金额', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              const SizedBox(height: 4),
              Text('${perBetAmount.toStringAsFixed(2)}元', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger)),
            ],
          ),
        ],
      ),
    );
  }
}
