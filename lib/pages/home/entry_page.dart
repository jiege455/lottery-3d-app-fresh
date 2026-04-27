import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/utils/batch_parser.dart';
import '../../models/bet_record.dart';
import '../../providers/bet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/template_provider.dart';
import '../../providers/learned_pattern_provider.dart';
import '../../models/template_record.dart';
import '../../models/learned_pattern.dart';
import '../../core/utils/pattern_learner.dart';
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
      Provider.of<TemplateProvider>(context, listen: false).loadTemplates();
      Provider.of<LearnedPatternProvider>(context, listen: false).loadPatterns();
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
      final learnedPatterns = Provider.of<LearnedPatternProvider>(context, listen: false).patterns;
      setState(() {
        _parsedItems = BatchParser.parse(value, forcePlayType: _selectedPlayType == 'auto' ? null : _selectedPlayType, defaultMultiplier: 1.0, learnedPatterns: learnedPatterns);
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

  void _saveAsTemplate() {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) {
      ToastUtil.warning(context, '请先输入投注内容');
      return;
    }
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: '输入模板名称（如：快手直选模板）',
                labelText: '模板名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('模板内容:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(inputText, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ToastUtil.warning(context, '请输入模板名称');
                return;
              }
              Navigator.pop(ctx);
              final template = TemplateRecord(
                name: name,
                content: inputText,
                playType: _selectedPlayType,
                playTypeName: _selectedPlayType == 'auto' ? '自动识别' : (PlayTypes.getByCode(_selectedPlayType)?.name ?? '自动识别'),
                defaultMultiplier: _multiplierController.text,
              );
              await Provider.of<TemplateProvider>(context, listen: false).addTemplate(template);
              if (mounted) ToastUtil.success(context, '模板已保存');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _applyTemplate(TemplateRecord template) {
    _inputController.text = template.content;
    if (template.playType != 'auto') {
      _selectedPlayType = template.playType;
    }
    _multiplierController.text = template.defaultMultiplier;
    _onInputChanged(template.content);
    if (mounted) setState(() {});
    ToastUtil.success(context, '已加载模板: ${template.name}');
  }

  void _showLearnPatternDialog() {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) {
      ToastUtil.warning(context, '请先输入一段投注文本');
      return;
    }

    // 取第一行非空文本作为样本
    final lines = inputText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final sample = lines.isNotEmpty ? lines.first.trim() : '';

    if (sample.isEmpty) {
      ToastUtil.warning(context, '无法提取有效样本');
      return;
    }

    String selectedPlayType = 'single';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('教它识别这种格式'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('样本文本:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(sample, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                ),
                const SizedBox(height: 16),
                const Text('这段文本应该识别为:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Column(
                      children: PlayTypes.all.map((pt) => RadioListTile<String>(
                        title: Text(pt.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(pt.ruleText, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                        value: pt.code,
                        groupValue: selectedPlayType,
                        onChanged: (v) => setState(() => selectedPlayType = v!),
                        dense: true,
                        activeColor: pt.color,
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 提示：系统会分析这段文本的特征，以后遇到类似格式会自动识别为此玩法。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final config = PlayTypes.getByCode(selectedPlayType);
                if (config == null) return;
                final id = await Provider.of<LearnedPatternProvider>(context, listen: false).addPattern(
                  sample,
                  selectedPlayType,
                  config.name,
                );
                if (id > 0) {
                  if (mounted) ToastUtil.success(context, '已学会：${config.name}格式');
                  // 重新解析当前输入
                  _onInputChanged(_inputController.text);
                } else {
                  if (mounted) ToastUtil.error(context, '学习失败');
                }
              },
              child: const Text('确认学习'),
            ),
          ],
        ),
      ),
    );
  }

  void _manageTemplates() {
    final templates = Provider.of<TemplateProvider>(context, listen: false).templates;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('管理模板', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${templates.length} 个模板', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: templates.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bookmark_outline, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text('暂无模板', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('输入内容后可保存为模板', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    ]))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: templates.length,
                      itemBuilder: (_, index) {
                        final t = templates[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppStyles.radiusXs),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.primary.withAlpha(26), borderRadius: BorderRadius.circular(4)), child: Text(t.playTypeName, style: TextStyle(fontSize: 9, color: AppColors.primary))),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(t.content, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) async {
                                  if (action == 'apply') {
                                    Navigator.pop(ctx);
                                    _applyTemplate(t);
                                  } else if (action == 'delete') {
                                    Navigator.pop(ctx);
                                    showDialog(
                                      context: context,
                                      builder: (dctx) => AlertDialog(
                                        title: const Text('删除模板'),
                                        content: Text('确认删除模板"${t.name}"？'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('取消')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                            onPressed: () async {
                                              Navigator.pop(dctx);
                                              if (t.id != null) {
                                                await Provider.of<TemplateProvider>(context, listen: false).deleteTemplate(t.id!);
                                              }
                                            },
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'apply', child: Row(children: [Icon(Icons.play_arrow, size: 18), SizedBox(width: 8), Text('使用模板')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.danger), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.danger))])),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
            ),
          ],
        ),
      ),
    );
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
            _buildTemplateBar(),
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

  Widget _buildTemplateBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveAsTemplate,
              icon: const Icon(Icons.bookmark_add, size: 16),
              label: const Text('保存为模板', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _manageTemplates,
              icon: const Icon(Icons.bookmark, size: 16),
              label: const Text('管理模板', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showLearnPatternDialog,
              icon: const Icon(Icons.psychology, size: 16),
              label: const Text('教它识别', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
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

