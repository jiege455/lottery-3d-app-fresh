import 'package:flutter/material.dart';
import '../models/bet_record.dart';
import '../services/db_service.dart';

class BetProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<BetRecord> _bets = [];
  bool _isLoading = false;

  List<BetRecord> get bets => _bets;
  bool get isLoading => _isLoading;

  Future<void> loadBets({int? lotteryType}) async {
    try {
      _isLoading = true;
      notifyListeners();
      _bets = await _db.getAllBets(lotteryType: lotteryType);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('BetProvider.loadBets error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> addBet(BetRecord bet) async {
    try {
      final id = await _db.insertBet(bet);
      await loadBets();
      return id;
    } catch (e) {
      print('BetProvider.addBet error: $e');
      return -1;
    }
  }

  Future<void> addBetsBatch(List<BetRecord> bets) async {
    try {
      await _db.insertBetsBatch(bets);
      await loadBets();
    } catch (e) {
      print('BetProvider.addBetsBatch error: $e');
    }
  }

  Future<void> deleteBet(int id) async {
    try {
      await _db.deleteBet(id);
      _bets.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      print('BetProvider.deleteBet error: $e');
    }
  }

  Future<void> deleteAllBets() async {
    try {
      await _db.deleteAllBets();
      _bets.clear();
      notifyListeners();
    } catch (e) {
      print('BetProvider.deleteAllBets error: $e');
    }
  }

  int get totalBets => _bets.length;

  int getBetCountByPlayType(String playType) {
    return _bets.where((b) => b.playType == playType).length;
  }
}
