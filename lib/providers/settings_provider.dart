import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/db_service.dart';
import '../core/constants/play_types.dart';

class SettingsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  AppSettings _settings = AppSettings();
  bool _isLoaded = false;
  Map<String, double> _playTypeAmounts = {};
  Map<String, double> _defaultAmounts = {};
  Map<String, double> _playTypeWinAmounts = {};

  AppSettings get settings => _settings;
  double get defaultMultiplier => _settings.defaultMultiplier;
  int get defaultLotteryType => _settings.defaultLotteryType;
  bool get isLoaded => _isLoaded;
  Map<String, double> get playTypeAmounts => _playTypeAmounts;
  Map<String, double> get playTypeWinAmounts => _playTypeWinAmounts;

  SettingsProvider() {
    _initDefaultAmounts();
  }

  void _initDefaultAmounts() {
    _defaultAmounts = {};
    for (final pt in PlayTypes.all) {
      _defaultAmounts[pt.code] = pt.baseAmount;
    }
  }

  double getPlayTypeAmount(String playType) {
    return _playTypeAmounts[playType] ?? _defaultAmounts[playType] ?? 2.0;
  }

  double getPlayTypeWinAmount(String playType) {
    return _playTypeWinAmounts[playType] ?? 0.0;
  }

  Future<void> loadSettings() async {
    try {
      _settings = await _db.getSettings();
      final result = await _db.getPlayTypeAmountsAndWinAmounts();
      _playTypeAmounts = result.amounts;
      _playTypeWinAmounts = result.winAmounts;
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.loadSettings error: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> updateMultiplier(double value) async {
    try {
      _settings.defaultMultiplier = value;
      await _db.updateSettings(_settings);
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.updateMultiplier error: $e');
      notifyListeners();
    }
  }

  Future<void> updateLotteryType(int value) async {
    try {
      _settings.defaultLotteryType = value;
      await _db.updateSettings(_settings);
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.updateLotteryType error: $e');
      notifyListeners();
    }
  }

  Future<void> updateBackupTime(String time) async {
    try {
      _settings.lastBackupTime = time;
      await _db.updateSettings(_settings);
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.updateBackupTime error: $e');
      notifyListeners();
    }
  }

  Future<void> updatePlayTypeAmount(String playType, double amount, double winAmount) async {
    try {
      await _db.setPlayTypeAmount(playType, amount, winAmount);
      _playTypeAmounts[playType] = amount;
      _playTypeWinAmounts[playType] = winAmount;
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.updatePlayTypeAmount error: $e');
      notifyListeners();
    }
  }

  Future<void> resetPlayTypeAmounts() async {
    try {
      await _db.resetPlayTypeAmounts();
      _playTypeAmounts.clear();
      _playTypeWinAmounts.clear();
      notifyListeners();
    } catch (e) {
      print('SettingsProvider.resetPlayTypeAmounts error: $e');
      notifyListeners();
    }
  }
}
