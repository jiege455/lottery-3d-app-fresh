import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/play_types.dart';
import '../../models/bet_record.dart';
import '../../providers/bet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/number_filter_service.dart';
import '../../widgets/toast.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final Set<int> _includeDigits = {};
  final Set<int> _excludeDigits = {};
  int? _minSum;
  int? _maxSum;
  int? _minSpan;
  int? _maxSpan;
  String? _formType;
  String? _oddEvenRatio;
  String? _bigSmallRatio;
  int? _pos1Digit;
  int? _pos2Digit;
  int? _pos3Digit;

  List<FilterResult> _results = [];
  bool _hasSearched = false;

  void _doFilter() {
    setState(() {
      _results = NumberFilterService.filter(
        includeDigits: _includeDigits.isEmpty ? null : _includeDigits,
        excludeDigits: _excludeDigits.isEmpty ? null : _excludeDigits,
        minSum: _minSum,
        maxSum: _maxSum,
        minSpan: _minSpan,
        maxSpan: _maxSpan,
        formType: _formType,
        oddEvenRatio: _oddEvenRatio,
        bigSmallRatio: _bigSmallRatio,
        pos1Digit: _pos1Digit,
        pos2Digit: _pos2Digit,
        pos3Digit: _pos3Digit,
      );
      _hasSearched = true;
    });
  }

  void _reset() {
    setState(() {
      _includeDigits.clear();
      _excludeDigits.clear();
      _minSum = null;
      _maxSum = null;
      _minSpan = null;
      _maxSpan = null;
      _formType = null;
      _oddEvenRatio = null;
      _bigSmallRatio = null;
      _pos1Digit = null;
      _pos2Digit = null;
      _pos3Digit = null;
      _results = [];
      _hasSearched = false;
    });
  }

  Future<void> _saveAsBets(String playTypeCode) async {
    if (_results.isEmpty) {
      ToastUtil.warning(context, '没有可保存的结果');
      return;
    }
    final config = PlayTypes.getByCode(playTypeCode);
    if (config == null) return;

    List<FilterResult> filteredResults;
    if (playTypeCode == 'group3') {
      filteredResults = _results.where((r) => r.formType == '组三').toList();
    } else if (playTypeCode == 'group6') {
      filteredResults = _results.where((r) => r.formType == '组六').toList();
    } else {
      filteredResults = _results;
    }

    if (filteredResults.isEmpty) {
      ToastUtil.warning(context, '没有符合条件的${config.name}号码');
      return;
    }

    final lotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
    final batchId = 'B${DateTime.now().millisecondsSinceEpoch}';
    final bets = filteredResults.map((r) => BetRecord(
      number: r.number,
      playType: playTypeCode,
      playTypeName: config.name,
      lotteryType: lotteryType,
      multiplier: 1.0,
      baseAmount: config.baseAmount,
      batchId: batchId,
    )).toList();

    try {
      await Provider.of<BetProvider>(context, listen: false).addBetsBatch(bets);
      if (mounted) {
        ToastUtil.success(context, '已保存 ${bets.length} 条${config.name}投注');
      }
    } catch (e) {
      if (mounted) ToastUtil.error(context, '保存失败: $e');
    }
  }

  void _showSaveDialog() {
    if (_results.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('保存为投注', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('共 ${_results.length} 注，选择保存方式：', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.straighten, color: AppColors.primary),
              title: const Text('保存为直选'),
              subtitle: Text('${_results.length} 注 × 2元 = ${(_results.length * 2).toStringAsFixed(0)}元'),
              onTap: () { Navigator.pop(ctx); _saveAsBets('single'); },
            ),
            ListTile(
              leading: Icon(Icons.shuffle, color: AppColors.warning),
              title: const Text('保存为组三'),
              subtitle: Text('仅组三号码可保存，组三号码: ${_results.where((r) => r.formType == "组三").length} 注'),
              onTap: () { Navigator.pop(ctx); _saveAsBets('group3'); },
            ),
            ListTile(
              leading: Icon(Icons.grid_view, color: AppColors.success),
              title: const Text('保存为组六'),
              subtitle: Text('仅组六号码可保存，组六号码: ${_results.where((r) => r.formType == "组六").length} 注'),
              onTap: () { Navigator.pop(ctx); _saveAsBets('group6'); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('缩水过滤', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('开发者：杰哥网络科技', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                ],
              ),
            ),
            _buildIncludeDigitsCard(),
            const SizedBox(height: 8),
            _buildExcludeDigitsCard(),
            const SizedBox(height: 8),
            _buildSumSpanCard(),
            const SizedBox(height: 8),
            _buildFormTypeCard(),
            const SizedBox(height: 8),
            _buildOddEvenCard(),
            const SizedBox(height: 8),
            _buildBigSmallCard(),
            const SizedBox(height: 8),
            _buildPositionCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (_hasSearched) ...[
              const SizedBox(height: 12),
              _buildResultsCard(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitSelector(String title, Set<int> selectedDigits, void Function(int) onToggle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (selectedDigits.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => selectedDigits.clear()),
                  child: const Text('清除', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(10, (i) {
              final selected = selectedDigits.contains(i);
              return GestureDetector(
                onTap: () => setState(() => onToggle(i)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludeDigitsCard() {
    return _buildDigitSelector('必含数字（号码中必须包含的数字）', _includeDigits, (i) {
      if (_includeDigits.contains(i)) {
        _includeDigits.remove(i);
      } else {
        _includeDigits.add(i);
        _excludeDigits.remove(i);
      }
    });
  }

  Widget _buildExcludeDigitsCard() {
    return _buildDigitSelector('排除数字（号码中不能包含的数字）', _excludeDigits, (i) {
      if (_excludeDigits.contains(i)) {
        _excludeDigits.remove(i);
      } else {
        _excludeDigits.add(i);
        _includeDigits.remove(i);
      }
    });
  }

  Widget _buildSumSpanCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('和值 / 跨度范围', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('和值', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 36,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '最小',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: AppColors.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _minSum = int.tryParse(v),
                ),
              ),
              const Text(' ~ ', style: TextStyle(fontSize: 14)),
              SizedBox(
                width: 60,
                height: 36,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '最大',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: AppColors.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _maxSum = int.tryParse(v),
                ),
              ),
              const SizedBox(width: 20),
              const Text('跨度', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 36,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '最小',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: AppColors.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _minSpan = int.tryParse(v),
                ),
              ),
              const Text(' ~ ', style: TextStyle(fontSize: 14)),
              SizedBox(
                width: 60,
                height: 36,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '最大',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: AppColors.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _maxSpan = int.tryParse(v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormTypeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('形态过滤', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['', '豹子', '组三', '组六'].map((type) {
              final selected = _formType == type;
              final label = type.isEmpty ? '不限' : type;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _formType = selected ? null : type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOddEvenCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('奇偶比（奇:偶）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['', '3:0', '2:1', '1:2', '0:3'].map((ratio) {
              final selected = _oddEvenRatio == ratio;
              final label = ratio.isEmpty ? '不限' : ratio;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _oddEvenRatio = selected ? null : ratio),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBigSmallCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('大小比（大:小，5-9为大，0-4为小）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['', '3:0', '2:1', '1:2', '0:3'].map((ratio) {
              final selected = _bigSmallRatio == ratio;
              final label = ratio.isEmpty ? '不限' : ratio;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _bigSmallRatio = selected ? null : ratio),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('定位过滤（指定某位数字）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPosSelector('百位', _pos1Digit, (v) => setState(() => _pos1Digit = v)),
              _buildPosSelector('十位', _pos2Digit, (v) => setState(() => _pos2Digit = v)),
              _buildPosSelector('个位', _pos3Digit, (v) => setState(() => _pos3Digit = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPosSelector(String label, int? selected, void Function(int?) onChanged) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          height: 36,
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: selected != null ? '$selected' : '-',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: AppColors.primaryLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              final val = int.tryParse(v);
              if (val != null && val >= 0 && val <= 9) {
                onChanged(val);
              } else if (v.isEmpty) {
                onChanged(null);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重置条件'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _doFilter,
              icon: const Icon(Icons.filter_alt, size: 18),
              label: const Text('开始过滤', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final baoziCount = _results.where((r) => r.formType == '豹子').length;
    final g3Count = _results.where((r) => r.formType == '组三').length;
    final g6Count = _results.where((r) => r.formType == '组六').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
              const Text('过滤结果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (_results.isNotEmpty)
                TextButton.icon(
                  onPressed: _showSaveDialog,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('保存为投注', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withAlpha(204)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppStyles.radiusXs),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat('总计', '${_results.length}', Colors.white),
                _buildResultStat('豹子', '$baoziCount', Colors.yellowAccent),
                _buildResultStat('组三', '$g3Count', Colors.white70),
                _buildResultStat('组六', '$g6Count', Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.filter_list_off, size: 48, color: AppColors.textSecondary.withAlpha(128)),
                    const SizedBox(height: 12),
                    Text('没有符合条件的号码', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('请放宽过滤条件后重试', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _results.map((r) {
                    Color bgColor;
                    Color textColor;
                    if (r.formType == '豹子') {
                      bgColor = AppColors.danger.withAlpha(26);
                      textColor = AppColors.danger;
                    } else if (r.formType == '组三') {
                      bgColor = AppColors.warning.withAlpha(26);
                      textColor = AppColors.warning;
                    } else {
                      bgColor = AppColors.success.withAlpha(26);
                      textColor = AppColors.success;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }
}
