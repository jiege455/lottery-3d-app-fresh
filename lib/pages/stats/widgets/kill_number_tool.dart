import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/db_service.dart';
import '../../../models/draw_record.dart';
import '../../../widgets/empty_state.dart';

class KillNumberTool extends StatefulWidget {
  const KillNumberTool({super.key});

  @override
  State<KillNumberTool> createState() => _KillNumberToolState();
}

class _KillNumberToolState extends State<KillNumberTool> {
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
      print('KillNumberTool._loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _analyze() {
    if (_draws.isEmpty) return {};

    final recentDraws = _draws.take(_periods).toList();

    final posFreq = <int, Map<String, int>>{
      0: {for (var i = 0; i < 10; i++) i.toString(): 0},
      1: {for (var i = 0; i < 10; i++) i.toString(): 0},
      2: {for (var i = 0; i < 10; i++) i.toString(): 0},
    };
    final totalFreq = <String, int>{for (var i = 0; i < 10; i++) i.toString(): 0};
    final sumFreq = <int, int>{for (var i = 0; i <= 27; i++) i: 0};
    final spanFreq = <int, int>{for (var i = 0; i <= 9; i++) i: 0};

    for (final draw in recentDraws) {
      final nums = draw.numbers;
      if (nums.length != 3) continue;
      for (var i = 0; i < 3; i++) {
        posFreq[i]![nums[i]] = (posFreq[i]![nums[i]] ?? 0) + 1;
        totalFreq[nums[i]] = (totalFreq[nums[i]] ?? 0) + 1;
      }
      sumFreq[draw.sumValue] = (sumFreq[draw.sumValue] ?? 0) + 1;
      spanFreq[draw.span] = (spanFreq[draw.span] ?? 0) + 1;
    }

    final killByPos = <int, List<String>>{};
    for (var pos = 0; pos < 3; pos++) {
      final sorted = posFreq[pos]!.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      killByPos[pos] = sorted.take(3).map((e) => e.key).toList();
    }

    final sortedTotal = totalFreq.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final killGlobal = sortedTotal.take(3).map((e) => e.key).toList();
    final hotGlobal = sortedTotal.reversed.take(3).map((e) => e.key).toList();

    final sortedSum = sumFreq.entries.where((e) => e.value == 0).map((e) => e.key).toList()..sort();
    final killSum = sortedSum.take(5).toList();

    final sortedSpan = spanFreq.entries.where((e) => e.value == 0).map((e) => e.key).toList()..sort();
    final killSpan = sortedSpan.take(3).toList();

    return {
      'killByPos': killByPos,
      'killGlobal': killGlobal,
      'hotGlobal': hotGlobal,
      'killSum': killSum,
      'killSpan': killSpan,
      'posFreq': posFreq,
      'totalFreq': totalFreq,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));

    if (_draws.isEmpty) return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('杀码工具', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        EmptyState(message: '暂无开奖数据，请先在管理页导入', icon: Icons.content_cut),
      ]),
    );

    final analysis = _analyze();
    if (analysis.isEmpty) return const SizedBox.shrink();

    final killByPos = analysis['killByPos'] as Map<int, List<String>>;
    final killGlobal = analysis['killGlobal'] as List<String>;
    final hotGlobal = analysis['hotGlobal'] as List<String>;
    final killSum = analysis['killSum'] as List<int>;
    final killSpan = analysis['killSpan'] as List<int>;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.content_cut, size: 18, color: AppColors.danger),
            const SizedBox(width: 6),
            const Text('杀码工具', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          Row(children: [
            DropdownButton<int>(value: _periods, items: [10, 20, 30, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('${v}期', style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) { setState(() => _periods = v!); _loadData(); }),
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ]),
        const SizedBox(height: 4),
        Text('基于最近 $_periods 期数据分析，推荐杀码如下：', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _buildKillRow('百位杀码', killByPos[0] ?? [], AppColors.danger),
        const SizedBox(height: 10),
        _buildKillRow('十位杀码', killByPos[1] ?? [], AppColors.danger),
        const SizedBox(height: 10),
        _buildKillRow('个位杀码', killByPos[2] ?? [], AppColors.danger),
        const SizedBox(height: 14),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 14),
        _buildKillRow('全局杀码', killGlobal, AppColors.warning),
        const SizedBox(height: 10),
        _buildKillRow('全局热码', hotGlobal, AppColors.success),
        if (killSum.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          _buildKillRow2('杀和值', killSum.map((e) => e.toString()).toList(), AppColors.purple),
        ],
        if (killSpan.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildKillRow2('杀跨度', killSpan.map((e) => e.toString()).toList(), AppColors.cyan),
        ],
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(AppStyles.radiusXs)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(child: Text('杀码仅供参考，基于历史统计频率分析，不保证准确性', style: TextStyle(fontSize: 10, color: AppColors.warning))),
        ])),
      ]),
    );
  }

  Widget _buildKillRow(String title, List<String> digits, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 72, child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      const SizedBox(width: 8),
      Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: digits.map((d) => Container(
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Text(d, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      )).toList())),
    ]);
  }

  Widget _buildKillRow2(String title, List<String> values, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 72, child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      const SizedBox(width: 8),
      Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: values.map((v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      )).toList())),
    ]);
  }
}
