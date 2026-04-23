import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/utils/batch_parser.dart';
import '../../models/bet_record.dart';
import '../../providers/bet_provider.dart';
import '../../providers/settings_provider.dart';
import 'widgets/play_type_chips.dart';
import 'widgets/rule_hint_box.dart';
import 'widgets/batch_input.dart';
import 'widgets/preview_list.dart';
import 'widgets/bet_history_list.dart';
import '../../widgets/toast.dart';
import '../../core/constants/play_types.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  String _selectedPlayType = 'auto';
  TextEditingController _inputController = TextEditingController();
  TextEditingController _multiplierController = TextEditingController(text: '2');
  List<ParsedItem> _parsedItems = [];
  Timer? _debounce;
  bool _syncedMultiplier = false;

  @override
  void initState() {
    super.initState();
    _multiplierController.addListener(_onMultiplierChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initData();
    });
  }

  void _initData() {
    try {
      Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    } catch (e) {
      print('EntryPage._initData error: $e');
    }
  }

  void _onMultiplierChanged() {
    if (!mounted) return;
    final amount = double.tryParse(_multiplierController.text);
    if (amount != null && amount > 0) {
      try {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        settings.updateMultiplier(amount);
        setState(() {
          if (_parsedItems.isNotEmpty) {
            for (final item in _parsedItems) {
              if (!item.isMultiplierCustomized) {
                item.baseAmount = settings.getPlayTypeAmount(item.playType);
                item.multiplier = item.baseAmount > 0 ? amount / item.baseAmount : 1.0;
              }
            }
          }
        });
      } catch (_) {}
    }
  }

  void _onInputChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final perBetAmount = double.tryParse(_multiplierController.text) ?? 2.0;
      setState(() {
        _parsedItems = BatchParser.parse(value, forcePlayType: _selectedPlayType == 'auto' ? null : _selectedPlayType, defaultMultiplier: 1.0);
        for (final item in _parsedItems) {
          item.baseAmount = settings.getPlayTypeAmount(item.playType);
          if (!item.isMultiplierCustomized && (item.multiplier - 1.0).abs() < 0.001) {
            item.multiplier = item.baseAmount > 0 ? perBetAmount / item.baseAmount : 1.0;
          } else if (!item.isMultiplierCustomized) {
            item.isMultiplierCustomized = true;
          }
        }
      });
    });
  }

  int get _totalBetCount => _parsedItems.length;

  double get _totalAmount {
    double total = 0;
    for (final item in _parsedItems) {
      total += item.multiplier * item.baseAmount;
    }
    return total;
  }

  Future<void> _saveBets() async {
    if (_parsedItems.isEmpty) {
      if (!mounted) return;
      ToastUtil.warning(context, '请先输入投注内容');
      return;
    }
    try {
      final lotteryType = Provider.of<SettingsProvider>(context, listen: false).defaultLotteryType;
      final batchId = 'B${DateTime.now().millisecondsSinceEpoch}';
      final bets = _parsedItems.map((item) => BetRecord(
        number: item.number,
        playType: item.playType,
        playTypeName: item.playTypeName,
        lotteryType: lotteryType,
        multiplier: item.multiplier,
        baseAmount: item.baseAmount,
        batchId: batchId,
      )).toList();
      await Provider.of<BetProvider>(context, listen: false).addBetsBatch(bets);
      if (!mounted) return;
      ToastUtil.success(context, '成功保存 ${bets.length} 条记录');
      _inputController.clear();
      if (mounted) setState(() => _parsedItems = []);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(context, '保存失败: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_syncedMultiplier || _multiplierController.text.isEmpty) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _syncedMultiplier = true;
      _multiplierController.text = settings.defaultMultiplier.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

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
                  const Text('投注录入', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('开发者：杰哥网络科技', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                ],
              ),
            ),
            _buildLotterySwitcher(),
            const SizedBox(height: 4),
            PlayTypeChips(selectedPlayType: _selectedPlayType, onChanged: (code) {
              setState(() {
                _selectedPlayType = code;
                final settings = Provider.of<SettingsProvider>(context, listen: false);
                final perBetAmount = double.tryParse(_multiplierController.text) ?? 2.0;
                for (final item in _parsedItems) {
                  item.baseAmount = settings.getPlayTypeAmount(item.playType);
                  if (!item.isMultiplierCustomized) {
                    item.multiplier = item.baseAmount > 0 ? perBetAmount / item.baseAmount : 1.0;
                  }
                }
              });
            }),
            RuleHintBox(playTypeCode: _selectedPlayType),
            BatchInput(controller: _inputController, onChanged: _onInputChanged),
            const SizedBox(height: 4),
            _buildMultiplierSection(),
            const SizedBox(height: 12),
            PreviewList(items: _parsedItems, onItemUpdated: (index, item) {
              setState(() {});
            }),
            if (_parsedItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSummaryCard(),
            ],
            const SizedBox(height: 12),
            _buildSaveButton(),
            const SizedBox(height: 24),
            const BetHistoryList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppStyles.radiusXs),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [
            Text('$_totalBetCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            Text('总注数', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          Container(width: 1, height: 30, color: AppColors.border),
          Column(children: [
            Text('${_totalAmount.toStringAsFixed(2)} 元', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.danger)),
            Text('总金额', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLotterySwitcher() {
    final lotteryType = Provider.of<SettingsProvider>(context).defaultLotteryType;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm)),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => Provider.of<SettingsProvider>(context, listen: false).updateLotteryType(1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: lotteryType == 1 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(AppStyles.radiusXs)),
            child: Text('福彩 3D', textAlign: TextAlign.center, style: TextStyle(color: lotteryType == 1 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => Provider.of<SettingsProvider>(context, listen: false).updateLotteryType(2),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: lotteryType == 2 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(AppStyles.radiusXs)),
            child: Text('排列三', textAlign: TextAlign.center, style: TextStyle(color: lotteryType == 2 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        )),
      ]),
    );
  }

  Widget _buildMultiplierSection() {
    final perBetAmount = double.tryParse(_multiplierController.text) ?? 2.0;
    String amountHint = '';
    if (_selectedPlayType != 'auto') {
      final config = PlayTypes.getByCode(_selectedPlayType);
      if (config != null) {
        final base = config.baseAmount;
        final multiplier = base > 0 ? perBetAmount / base : 1.0;
        amountHint = '(${multiplier.toStringAsFixed(2)}倍)';
      }
    } else {
      amountHint = '(倍数根据玩法自动计算)';
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppStyles.radiusSm), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('每注金额(元)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(
            children: [
              SizedBox(width: 80, height: 36, child: TextField(controller: _multiplierController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), isDense: true))),
              const SizedBox(width: 8),
              Text(amountHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: ['2', '5', '10', '0.1', '0.2', '0.05'].map((m) => ActionChip(label: Text('${m}元'), labelStyle: const TextStyle(fontSize: 12), onPressed: () => _multiplierController.text = m)).toList()),
      ]),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _saveBets,
        icon: const Icon(Icons.save, size: 18),
        label: Text('保存投注 (${_parsedItems.length} 注 / ${_totalAmount.toStringAsFixed(2)} 元)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      )),
    );
  }
}

