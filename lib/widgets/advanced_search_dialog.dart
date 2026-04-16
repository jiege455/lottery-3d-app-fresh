import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/play_types.dart';

class AdvancedSearchDialog extends StatefulWidget {
  final int lotteryType;
  final Function(Map<String, dynamic>) onSearch;

  const AdvancedSearchDialog({
    super.key,
    required this.lotteryType,
    required this.onSearch,
  });

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _keywordController = TextEditingController();
  String? _selectedPlayType;
  double? _minAmount;
  double? _maxAmount;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _doSearch() {
    final params = <String, dynamic>{
      'keyword': _keywordController.text.trim(),
      'playType': _selectedPlayType,
      'minAmount': _minAmount,
      'maxAmount': _maxAmount,
      'startDate': _dateRange?.start,
      'endDate': _dateRange?.end,
    };
    widget.onSearch(params);
    Navigator.pop(context);
  }

  void _reset() {
    _keywordController.clear();
    setState(() {
      _selectedPlayType = null;
      _minAmount = null;
      _maxAmount = null;
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('高级搜索', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: '搜索号码/玩法/批次...',
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textLight),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('玩法类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('全部', style: TextStyle(fontSize: 12)),
                          selected: _selectedPlayType == null,
                          onSelected: (_) => setState(() => _selectedPlayType = null),
                        ),
                        ...PlayTypes.categories.map((cat) {
                          final playTypes = PlayTypes.getByCategory(cat);
                          return playTypes.map((pt) {
                            final selected = _selectedPlayType == pt.code;
                            return ChoiceChip(
                              label: Text(pt.name, style: const TextStyle(fontSize: 11)),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedPlayType = selected ? null : pt.code),
                            );
                          });
                        }).expand((e) => e),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('金额范围（单注金额）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '最小金额',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) => _minAmount = double.tryParse(v),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '最大金额',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) => _maxAmount = double.tryParse(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('时间范围', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime.now(),
                          initialDateRange: _dateRange,
                        );
                        if (range != null) {
                          setState(() => _dateRange = range);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppStyles.radiusXs),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _dateRange != null
                                  ? '${_dateRange!.start.toString().substring(0, 10)} ~ ${_dateRange!.end.toString().substring(0, 10)}'
                                  : '选择日期范围',
                              style: TextStyle(
                                fontSize: 13,
                                color: _dateRange != null ? AppColors.textPrimary : AppColors.textLight,
                              ),
                            ),
                            const Spacer(),
                            if (_dateRange != null)
                              GestureDetector(
                                onTap: () => setState(() => _dateRange = null),
                                child: Icon(Icons.clear, size: 16, color: AppColors.textLight),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('重置'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _doSearch,
                    child: const Text('搜索', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
