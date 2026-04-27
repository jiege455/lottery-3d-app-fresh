import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/play_types.dart';
import '../../core/utils/pattern_learner.dart';
import '../../models/learned_pattern.dart';
import '../../providers/learned_pattern_provider.dart';
import '../../widgets/toast.dart';

class PatternManagePage extends StatefulWidget {
  const PatternManagePage({super.key});

  @override
  State<PatternManagePage> createState() => _PatternManagePageState();
}

class _PatternManagePageState extends State<PatternManagePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<LearnedPatternProvider>(context, listen: false).loadPatterns();
      }
    });
  }

  void _showAddPatternDialog() {
    final sampleCtrl = TextEditingController();
    String selectedPlayType = 'single';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加识别案例'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('示例文本:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: sampleCtrl,
                  decoration: const InputDecoration(
                    hintText: '输入您的投注文本，如：358-2倍',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('这段文本应该识别为:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final sample = sampleCtrl.text.trim();
                if (sample.isEmpty) {
                  ToastUtil.warning(ctx, '请输入示例文本');
                  return;
                }
                Navigator.pop(ctx);
                final config = PlayTypes.getByCode(selectedPlayType);
                if (config == null) return;
                final id = await Provider.of<LearnedPatternProvider>(context, listen: false).addPattern(
                  sample,
                  selectedPlayType,
                  config.name,
                );
                if (id > 0) {
                  if (mounted) ToastUtil.success(context, '已添加：${config.name}格式');
                } else {
                  if (mounted) ToastUtil.error(context, '添加失败');
                }
              },
              child: const Text('确认添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPatternDialog(LearnedPattern pattern) {
    final sampleCtrl = TextEditingController(text: pattern.sampleText);
    String selectedPlayType = pattern.playType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑识别案例'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('示例文本:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: sampleCtrl,
                  decoration: const InputDecoration(
                    hintText: '输入您的投注文本',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('这段文本应该识别为:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final sample = sampleCtrl.text.trim();
                if (sample.isEmpty) {
                  ToastUtil.warning(ctx, '请输入示例文本');
                  return;
                }
                Navigator.pop(ctx);
                final config = PlayTypes.getByCode(selectedPlayType);
                if (config == null) return;

                // 删除旧的，添加新的
                if (pattern.id != null) {
                  await Provider.of<LearnedPatternProvider>(context, listen: false).deletePattern(pattern.id!);
                }
                final id = await Provider.of<LearnedPatternProvider>(context, listen: false).addPattern(
                  sample,
                  selectedPlayType,
                  config.name,
                );
                if (id > 0) {
                  if (mounted) ToastUtil.success(context, '已更新：${config.name}格式');
                } else {
                  if (mounted) ToastUtil.error(context, '更新失败');
                }
              },
              child: const Text('确认更新'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePattern(LearnedPattern pattern) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除案例'),
        content: Text('确认删除案例"${pattern.sampleText}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              if (pattern.id != null) {
                await Provider.of<LearnedPatternProvider>(context, listen: false).deletePattern(pattern.id!);
                if (mounted) ToastUtil.success(context, '已删除');
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _testPattern(LearnedPattern pattern) {
    final testCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('测试识别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('案例: ${pattern.sampleText}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: testCtrl,
              decoration: const InputDecoration(
                hintText: '输入测试文本',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final testText = testCtrl.text.trim();
              if (testText.isEmpty) return;
              Navigator.pop(ctx);

              final result = PatternLearner.tryMatch(testText, pattern);
              if (result != null) {
                ToastUtil.success(context, '匹配成功！识别为：${result.playTypeName}');
              } else {
                ToastUtil.warning(context, '未能匹配，文本格式与案例不符');
              }
            },
            child: const Text('测试'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('识别管理', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('开发者：杰哥网络科技', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '添加您的投注文本案例，系统会学习识别类似格式。每个人的输入习惯不同，可以添加多个案例来提高识别准确率。',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddPatternDialog,
                icon: const Icon(Icons.add),
                label: const Text('添加新案例'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<LearnedPatternProvider>(
              builder: (context, provider, child) {
                if (!provider.isLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patterns = provider.patterns;

                if (patterns.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        const Text('暂无识别案例', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        const Text('点击上方按钮添加您的第一个案例', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: patterns.length,
                  itemBuilder: (_, index) {
                    final pattern = patterns[index];
                    final config = PlayTypes.getByCode(pattern.playType);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (config?.color ?? AppColors.primary).withAlpha(26),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            pattern.playTypeName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: config?.color ?? AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '优先级: ${pattern.priority}',
                                          style: TextStyle(fontSize: 11, color: AppColors.textLight),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      pattern.sampleText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '模式: ${pattern.pattern}',
                                      style: TextStyle(fontSize: 10, color: AppColors.textLight, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  if (action == 'test') {
                                    _testPattern(pattern);
                                  } else if (action == 'edit') {
                                    _showEditPatternDialog(pattern);
                                  } else if (action == 'delete') {
                                    _deletePattern(pattern);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'test', child: Row(children: [Icon(Icons.play_arrow, size: 18), SizedBox(width: 8), Text('测试识别')])),
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('编辑')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.danger), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.danger))])),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
