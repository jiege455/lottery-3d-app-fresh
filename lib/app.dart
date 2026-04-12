import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/bet_provider.dart';
import 'providers/settings_provider.dart';
import 'pages/home/entry_page.dart' as entry;
import 'pages/stats/stats_page.dart' as stats;
import 'pages/check/check_page.dart' as check;
import 'pages/manage/manage_page.dart' as manage;

class Lottery3DApp extends StatelessWidget {
  const Lottery3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('[Lottery3DApp] Building MultiProvider...');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          print('[Lottery3DApp] Creating BetProvider...');
          return BetProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          print('[Lottery3DApp] Creating SettingsProvider...');
          return SettingsProvider();
        }),
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
  String? _initError;

  @override
  void initState() {
    super.initState();
    print('[MainScaffold] initState called');
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    if (!mounted) return;
    print('[MainScaffold] Starting provider initialization...');
    try {
      final betProvider = Provider.of<BetProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      print('[MainScaffold] Loading settings...');
      await settingsProvider.loadSettings();
      if (!mounted) return;
      print('[MainScaffold] Settings loaded successfully');

      print('[MainScaffold] Loading bets...');
      await betProvider.loadBets();
      if (!mounted) return;
      print('[MainScaffold] Bets loaded successfully');

      if (mounted) {
        print('[MainScaffold] Setting initialized to true');
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, stack) {
      print('[MainScaffold] Provider initialization error: $e');
      print('[MainScaffold] Stack trace: $stack');
      if (mounted) {
        setState(() {
          _initialized = true;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      print('[MainScaffold] Showing loading screen...');
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

    if (_initError != null) {
      print('[MainScaffold] Showing error screen: $_initError');
    }

    print('[MainScaffold] Building main scaffold, currentIndex: $_currentIndex');
    return Scaffold(
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '录入'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_outlined), label: '校验'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: '管理'),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    try {
      print('[MainScaffold] Building page at index: $index');
      switch (index) {
        case 0:
          print('[MainScaffold] Creating EntryPage...');
          return const entry.EntryPage();
        case 1:
          print('[MainScaffold] Creating StatsPage...');
          return const stats.StatsPage();
        case 2:
          print('[MainScaffold] Creating CheckPage...');
          return const check.CheckPage();
        case 3:
          print('[MainScaffold] Creating ManagePage...');
          return const manage.ManagePage();
        default:
          print('[MainScaffold] Creating default EntryPage...');
          return const entry.EntryPage();
      }
    } catch (e, stack) {
      print('[MainScaffold] Page build error: $e');
      print('[MainScaffold] Stack trace: $stack');
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
