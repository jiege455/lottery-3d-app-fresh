import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/draw_record.dart';
import '../../providers/bet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/check_service.dart';
import '../../services/lottery_api_service.dart';
import '../../services/db_service.dart';
import '../../widgets/toast.dart';

class CheckPage extends StatefulWidget {
  const CheckPage({super.key});

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  List<CheckResult> _results = [];
  bool _checking = false;
  bool _betsLoaded = false;
  bool _syncing = false;
  bool _loseExpanded = false;
  static const int _collapsedLoseCount = 10;
  List<DrawRecord> _recentDraws = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_betsLoaded) {
        _betsLoaded = true;
        _initData();
      }
    });
  }

  Future<void> _initData() async {
    try {
      Provider.of<BetProvider>(context, listen: false).loadBets();
    } catch (e) {
      print('CheckPage._initData error: $e');
    }
    _loadRecentDraws();
  }

  Future<void> _loadRecentDraws() async {
    try {
      final draws = await DatabaseHelper.instance.getAllDraws(limit: 10);
      if (mounted) setState(() => _recentDraws = draws);
    } catch (e) {
      print('CheckPage._loadRecentDraws error: $e');
    }
  }

  Future<void> _syncFromApi() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      int totalCount = 0;
      totalCount += await LotteryApiService.syncDraws(lotteryType: 1, count: 7);
      totalCount += await LotteryApiService.syncDraws(lotteryType: 2, count: 7);
      await _loadRecentDraws();
      if (mounted) {
        if (totalCount > 0) {
          ToastUtil.success(context, '同步成功，新增 $totalCount 条开奖数据');
        } else {
          ToastUtil.success(context, '已同步，暂无新数据');
        }
      }
    } catch (e) {
      if (mounted) ToastUtil.error(context, '同步失败: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _selectDraw(DrawRecord draw) {
    _issueController.text = draw.issue;
    _numberController.text = draw.numbers;
  }

  void _startCheck() {
    final issue = _issueController.text.trim();
    final numbers = _numberController.text.trim();

    if (numbers.length != 3 || !RegExp(r'^[0-9]{3}$').hasMatch(numbers)) {
      ToastUtil.warning(context, '请输入 3 位有效开奖号码');
      return;
    }

    final bets = Provider.of<BetProvider>(context, listen: false).bets;
    if (bets.isEmpty) {
      ToastUtil.warning(context, '暂无投注记录');
      return;
    }

    setState(() {
      _checking = true;
      _loseExpanded = false;
    });

    final draw = DrawRecord(
      issue: issue.isEmpty ? '手动录入' : issue,
      numbers: numbers,
      sumValue: DrawRecord.getSumValue(numbers),
      span: DrawRecord.getSpan(numbers),
      formType: DrawRecord.getFormType(numbers),
      drawDate: DateTime.now(),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final winAmounts = <String, double>{};
      for (final bet in bets) {
        winAmounts[bet.playType] = settings.getPlayTypeWinAmount(bet.playType);
      }
      final results = CheckService.checkAll(bets, draw, winAmounts);
      setState(() {
        _results = results;
        _checking = false;
      });
    });
  }

  @override
  void dispose() {
    _issueController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('中奖校验', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('开发者：杰哥网络科技', style: TextStyle(fontSize: 10, color: AppColors.textLight))])),
        _buildSyncCard(),
        const SizedBox(height: 8),
        _buildInputCard(),
        if (_checking) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        if (!_checking && _results.isNotEmpty) ...[
          _buildSummaryCard(),
          const SizedBox(height: 8),
          ..._buildResultList(),
        ],
        if (!_checking && _results.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Center(child: Icon(Icons.verified_outlined, size: 64, color: AppColors.textLight)),
            const SizedBox(height: 12),
            Center(child: Text('输入开奖号码开始校验', style: TextStyle(fontSize: 15, color: AppColors.textSecondary))),
          ])),
      ]),
    ));
  }

  Widget _buildSyncCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.cloud_download, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('开奖数据同步', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          ElevatedButton.icon(
            onPressed: _syncing ? null : _syncFromApi,
            icon: _syncing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync, size: 16),
            label: Text(_syncing ? '同步中...' : '同步开奖', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          ),
        ]),
        if (_recentDraws.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('最近开奖（点击自动填入）', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: _recentDraws.map((d) => GestureDetector(
            onTap: () => _selectDraw(d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withAlpha(51))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(d.issue, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                Text(d.numbers, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'monospace')),
              ]),
            ),
          )).toList()),
        ] else ...[
          const SizedBox(height: 6),
          Text('暂无开奖数据，点击同步获取', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ]),
    );
  }

  Widget _buildInputCard() {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]), child: Column(children: [
      Row(children: [
        Expanded(child: TextField(controller: _issueController, decoration: InputDecoration(hintText: '期号(可选)', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)))),
        const SizedBox(width: 12),
        SizedBox(width: 120, child: TextField(controller: _numberController, maxLength: 3, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 6), decoration: InputDecoration(hintText: '号码', counterText: '', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)))),
      ]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _startCheck, icon: Icon(_checking ? Icons.hourglass_empty : Icons.search, size: 18), label: Text(_checking ? '校验中...' : '开始校验', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
    ]));
  }

  Widget _buildSummaryCard() {
    final totalBet = _results.fold<double>(0, (sum, r) => sum + r.betAmount);
    final totalWin = _results.fold<double>(0, (sum, r) => sum + r.winAmount);
    final profit = totalBet - totalWin;
    final winCount = CheckService.getWinCount(_results);
    final loseCount = CheckService.getLoseCount(_results);

    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildStatItem('总投注', '${totalBet.toStringAsFixed(1)} 元', AppColors.primary),
        _buildStatItem('总赔付', '${totalWin.toStringAsFixed(1)} 元', AppColors.danger),
        _buildStatItem(profit >= 0 ? '盈利' : '亏损', '${profit.abs().toStringAsFixed(1)} 元', profit >= 0 ? AppColors.success : AppColors.danger),
      ]),
      const Divider(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildStatItem2('$winCount', '中奖注数', AppColors.success),
        _buildStatItem2('$loseCount', '未中注数', AppColors.textLight),
        _buildStatItem2('${_results.length}', '总注数', AppColors.primary),
      ]),
    ]));
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  Widget _buildStatItem2(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }

  List<Widget> _buildResultList() {
    final winResults = _results.where((r) => r.isWin).toList();
    final loseResults = _results.where((r) => !r.isWin).toList();
    final needCollapse = loseResults.length > _collapsedLoseCount;
    final displayLose = (_loseExpanded || !needCollapse) ? loseResults : loseResults.sublist(0, _collapsedLoseCount);

    return [
      if (winResults.isNotEmpty) ...[
        _buildSectionHeader('🎉 中奖记录 (${winResults.length})', AppColors.success),
        ...winResults.map((r) => _buildResultItem(r, true)),
      ],
      if (loseResults.isNotEmpty) ...[
        _buildSectionHeader('❌ 未中记录 (${loseResults.length})', AppColors.textLight),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: displayLose.map((r) => _buildLoseResultItem(r)).toList(),
          ),
        ),
        if (needCollapse) ...[
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => setState(() => _loseExpanded = !_loseExpanded),
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
                      _loseExpanded ? '收起未中记录' : '展开全部 (${loseResults.length}条)',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _loseExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ];
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(margin: const EdgeInsets.fromLTRB(16, 12, 16, 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(AppStyles.radiusXs)), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)));
  }

  Widget _buildResultItem(CheckResult result, bool isWin) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isWin ? AppColors.success.withAlpha(15) : Colors.transparent, borderRadius: BorderRadius.circular(AppStyles.radiusXs)), child: Row(children: [
      Expanded(flex: 2, child: Text(result.bet.number, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
      Expanded(flex: 2, child: Text(result.bet.playTypeName, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
      Expanded(child: Text('${result.betAmount.toStringAsFixed(1)} 元', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
      if (isWin) ...[
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withAlpha(38), borderRadius: BorderRadius.circular(6)), child: Text('+${result.winAmount.toStringAsFixed(1)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success))),
      ] else ...[
        const SizedBox(width: 8),
        Expanded(child: Text('-${result.betAmount.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: AppColors.textLight), textAlign: TextAlign.right)),
      ],
    ]));
  }

  Widget _buildLoseResultItem(CheckResult result) {
    final itemWidth = (MediaQuery.of(context).size.width - 44) / 2;
    return Container(
      width: itemWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.textLight.withAlpha(10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(result.bet.number, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(result.bet.playTypeName, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('-${result.betAmount.toStringAsFixed(1)}元', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              if (result.bet.multiplier != 1.0) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('×${result.bet.multiplier}', style: TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
