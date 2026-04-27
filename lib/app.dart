import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/bet_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/template_provider.dart';
import 'providers/learned_pattern_provider.dart';
import 'pages/home/entry_page.dart' as entry;
import 'pages/filter/filter_page.dart' as filter;
import 'pages/stats/stats_page.dart' as stats;
import 'pages/check/check_page.dart' as check;
import 'pages/manage/manage_page.dart' as manage;
import 'pages/pattern/pattern_manage_page.dart' as pattern;

class Lottery3DApp extends StatelessWidget {
  const Lottery3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BetProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TemplateProvider()),
        ChangeNotifierProvider(create: (_) => LearnedPatternProvider()),
      ],
      child: MaterialApp(
        title: '福彩 3D 助手',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainScaffold(),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    if (!mounted) return;
    try {
      final betProvider = Provider.of<BetProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      await settingsProvider.loadSettings();
      if (!mounted) return;

      await betProvider.loadBets();
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, stack) {
      print('Provider initialization error: $e\n$stack');
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('加载中...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '录入'),
          BottomNavigationBarItem(icon: Icon(Icons.filter_alt), label: '缩水'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_outlined), label: '校验'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: '管理'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: '识别'),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    try {
      switch (index) {
        case 0:
          return const entry.EntryPage();
        case 1:
          return const filter.FilterPage();
        case 2:
          return const stats.StatsPage();
        case 3:
          return const check.CheckPage();
        case 4:
          return const manage.ManagePage();
        case 5:
          return const pattern.PatternManagePage();
        default:
          return const entry.EntryPage();
      }
    } catch (e, stack) {
      print('Page build error: $e\n$stack');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('页面加载异常', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('错误: $e', style: TextStyle(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
          ],
        ),
      );
    }
  }
}
