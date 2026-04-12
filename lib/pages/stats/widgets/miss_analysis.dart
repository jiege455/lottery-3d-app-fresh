import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/db_service.dart';
import '../../../models/draw_record.dart';
import '../../../widgets/empty_state.dart';

class MissAnalysis extends StatefulWidget {
  const MissAnalysis({super.key});

  @override
  State<MissAnalysis> createState() => _MissAnalysisState();
}

class _MissAnalysisState extends State<MissAnalysis> {
  int _periods = 30;
  List<DrawRecord> _draws = [];
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) {
        _loaded = true;
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final lotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
      final draws = await DatabaseHelper.instance.getAllDraws(lotteryType: lotteryType, limit: _periods);
      if (mounted) setState(() { _draws = draws; _loading = false; });
    } catch (e) {
      print('MissAnalysis._loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, int> _calcMiss() {
    final missCount = <String, int>{};
    for (var i = 0; i < 10; i++) missCount[i.toString()] = 0;

    final recentDraws = _draws.take(_periods).toList();
    if (recentDraws.isEmpty) return missCount;

    for (var i = 0; i < 10; i++) {
      final d = i.toString();
      int miss = 0;
      for (final draw in recentDraws) {
        if (!draw.numbers.contains(d)) {
          miss++;
        } else {
          break;
        }
      }
      missCount[d] = miss;
    }
    return missCount;
  }

  Map<String, int> _calcFrequency() {
    final freq = <String, int>{};
    for (var i = 0; i < 10; i++) freq[i.toString()] = 0;
    for (final draw in _draws.take(_periods)) {
      for (final c in draw.numbers.split('')) {
        if (freq.containsKey(c)) freq[c] = freq[c]! + 1;
      }
    }
    return freq;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));

    if (_draws.isEmpty) return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('遗漏分析', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        EmptyState(message: '暂无开奖数据，请先在管理页导入', icon: Icons.data_usage),
      ]),
    );

    final missCount = _calcMiss();
    final freq = _calcFrequency();
    final missingDigits = missCount.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final hotDigits = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final coldDigits = freq.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('遗漏分析', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Row(children: [
            DropdownButton<int>(value: _periods, items: [10, 20, 30, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('${v}期', style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) { setState(() => _periods = v!); _loadData(); }),
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ]),
        const SizedBox(height: 12),
        Text('基于最近 $_periods 期开奖数据分析', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _buildSection('冷号（遗漏最多）', missingDigits.isEmpty ? null : missingDigits, isMiss: true),
        const SizedBox(height: 12),
        _buildSection('高频号码', hotDigits.take(3).toList(), isMiss: false),
        const SizedBox(height: 12),
        _buildSection('低频号码', coldDigits.take(3).toList(), isMiss: false),
      ]),
    );
  }

  Widget _buildSection(String title, List<MapEntry<String, int>>? data, {required bool isMiss}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      if (data == null || data.isEmpty)
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(AppStyles.radiusXs)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: AppColors.success, size: 16), const SizedBox(width: 6), Text('所有号码近期都已出现', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500, fontSize: 12))]))
      else
        Wrap(spacing: 8, runSpacing: 8, children: data.map((e) => Container(
          width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isMiss ? AppColors.danger.withAlpha(26) : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isMiss ? AppColors.danger.withAlpha(77) : AppColors.primary.withAlpha(77)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(e.key, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isMiss ? AppColors.danger : AppColors.primary)),
            Text(isMiss ? '${e.value}期' : '${e.value}次', style: TextStyle(fontSize: 9, color: isMiss ? AppColors.danger.withAlpha(179) : AppColors.primary.withAlpha(179))),
          ]),
        )).toList()),
    ]);
  }
}
