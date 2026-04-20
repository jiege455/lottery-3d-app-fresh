import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/play_types.dart';

class AdvancedFilter extends StatefulWidget {
  final List<dynamic> allBets;
  final Function(List<dynamic>) onFilterApplied;
  
  const AdvancedFilter({
    super.key, 
    required this.allBets, 
    required this.onFilterApplied,
  });

  @override
  State<AdvancedFilter> createState() => _AdvancedFilterState();
}

class _AdvancedFilterState extends State<AdvancedFilter> {
  String _selectedPlayType = 'all';
  String _timeRange = 'all';
  String _multiplierRange = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  void _applyFilter() {
    List<dynamic> filtered = widget.allBets;

    if (_selectedPlayType != 'all') {
      filtered = filtered.where((b) => b.playType == _selectedPlayType).toList();
    }

    if (_timeRange != 'all') {
      final now = DateTime.now();
      DateTime start;
      DateTime? end;
      switch (_timeRange) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          end = now;
          break;
        case 'month':
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
          end = now;
          break;
        case 'custom':
          start = _startDate ?? now.subtract(const Duration(days: 30));
          end = _endDate;
          break;
        default:
          start = now;
          end = now;
      }
      if (_timeRange == 'custom' && end != null) {
        end = DateTime(end.year, end.month, end.day, 23, 59, 59);
        filtered = filtered.where((b) {
          final betTime = b.createTime as DateTime;
          return !betTime.isBefore(start) && !betTime.isAfter(end!);
        }).toList();
      } else {
        filtered = filtered.where((b) {
          final betTime = b.createTime as DateTime;
          return !betTime.isBefore(start) && (end == null || !betTime.isAfter(end));
        }).toList();
      }
    }

    if (_multiplierRange != 'all') {
      switch (_multiplierRange) {
        case 'low':
          filtered = filtered.where((b) => b.multiplier * b.baseAmount < 5).toList();
          break;
        case 'medium':
          filtered = filtered.where((b) => b.multiplier * b.baseAmount >= 5 && b.multiplier * b.baseAmount < 20).toList();
          break;
        case 'high':
          filtered = filtered.where((b) => b.multiplier * b.baseAmount >= 20).toList();
          break;
      }
    }

    widget.onFilterApplied(filtered);
  }

  void _resetFilters() {
    setState(() {
      _selectedPlayType = 'all';
      _timeRange = 'all';
      _multiplierRange = 'all';
      _startDate = null;
      _endDate = null;
    });
    _applyFilter();
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedPlayType != 'all') count++;
    if (_timeRange != 'all') count++;
    if (_multiplierRange != 'all') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final uniquePlayTypes = widget.allBets.map((b) => b.playType).toSet().toList();
    final activeFilterCount = _getActiveFilterCount();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('高级过滤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (activeFilterCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeFilterCount',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重置', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                      icon: Icon(
                        _showFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (_showFilters) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: '玩法过滤',
                    icon: Icons.games,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 80),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('全部', 'all', _selectedPlayType, (v) => setState(() => _selectedPlayType = v)),
                            const SizedBox(width: 8),
                            ...uniquePlayTypes.map((pt) {
                              final config = PlayTypes.getByCode(pt);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(
                                  config?.name ?? pt,
                                  pt,
                                  _selectedPlayType,
                                  (v) => setState(() => _selectedPlayType = v),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  _buildFilterSection(
                    title: '时间范围',
                    icon: Icons.calendar_today,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildFilterChip('全部', 'all', _timeRange, (v) => setState(() => _timeRange = v)),
                            const SizedBox(width: 8),
                            _buildFilterChip('今天', 'today', _timeRange, (v) => setState(() => _timeRange = v)),
                            const SizedBox(width: 8),
                            _buildFilterChip('最近 7 天', 'week', _timeRange, (v) => setState(() => _timeRange = v)),
                            const SizedBox(width: 8),
                            _buildFilterChip('最近 30 天', 'month', _timeRange, (v) => setState(() => _timeRange = v)),
                            const SizedBox(width: 8),
                            _buildFilterChip('自定义', 'custom', _timeRange, (v) => setState(() => _timeRange = v)),
                          ],
                        ),
                        if (_timeRange == 'custom') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _startDate = picked);
                                      _applyFilter();
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(
                                    _startDate != null 
                                      ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                      : '开始日期',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ?? DateTime.now(),
                                      firstDate: _startDate ?? DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _endDate = picked);
                                      _applyFilter();
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(
                                    _endDate != null 
                                      ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                      : '结束日期',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  _buildFilterSection(
                    title: '金额范围',
                    icon: Icons.multiline_chart,
                    child: Row(
                      children: [
                        _buildFilterChip('全部', 'all', _multiplierRange, (v) => setState(() => _multiplierRange = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('<5元', 'low', _multiplierRange, (v) => setState(() => _multiplierRange = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('5-20元', 'medium', _multiplierRange, (v) => setState(() => _multiplierRange = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('>20元', 'high', _multiplierRange, (v) => setState(() => _multiplierRange = v)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyFilter,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('应用过滤', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusXs)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildQuickFilterChip('今天', 'today', _timeRange, (v) {
                    setState(() => _timeRange = v);
                    _applyFilter();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickFilterChip('7 天', 'week', _timeRange, (v) {
                    setState(() => _timeRange = v);
                    _applyFilter();
                  }),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildFilterChip(
    String label, 
    String value, 
    String selected, 
    Function(String) onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(
    String label, 
    String value, 
    String selected, 
    Function(String) onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'today' ? Icons.today :
              Icons.date_range,
              size: 12,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
