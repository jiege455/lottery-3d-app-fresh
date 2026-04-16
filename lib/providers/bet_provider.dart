import 'package:flutter/material.dart';
import '../models/bet_record.dart';
import '../services/db_service.dart';

class BetProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<BetRecord> _bets = [];
  bool _isLoading = false;
  int _totalCount = 0;

  List<BetRecord> get bets => _bets;
  bool get isLoading => _isLoading;
  int get totalCount => _totalCount;

  Future<void> loadBets({int? lotteryType}) async {
    try {
      _isLoading = true;
      notifyListeners();
      _bets = await _db.getAllBets(lotteryType: lotteryType);
      _totalCount = _bets.length;
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
      _totalCount = _bets.length;
      notifyListeners();
    } catch (e) {
      print('BetProvider.deleteBet error: $e');
    }
  }

  Future<void> deleteBetsByIds(List<int> ids) async {
    try {
      await _db.deleteBetsByIds(ids);
      _bets.removeWhere((b) => b.id != null && ids.contains(b.id));
      _totalCount = _bets.length;
      notifyListeners();
    } catch (e) {
      print('BetProvider.deleteBetsByIds error: $e');
    }
  }

  Future<void> deleteAllBets() async {
    try {
      await _db.deleteAllBets();
      _bets.clear();
      _totalCount = 0;
      notifyListeners();
    } catch (e) {
      print('BetProvider.deleteAllBets error: $e');
    }
  }

  Future<void> updateBet(BetRecord bet) async {
    try {
      await _db.updateBet(bet);
      final idx = _bets.indexWhere((b) => b.id == bet.id);
      if (idx >= 0) {
        _bets[idx] = bet;
        notifyListeners();
      } else {
        await loadBets();
      }
    } catch (e) {
      print('BetProvider.updateBet error: $e');
    }
  }

  Future<void> updateBetsBatch(List<BetRecord> bets) async {
    try {
      for (final bet in bets) {
        await _db.updateBet(bet);
      }
      await loadBets();
    } catch (e) {
      print('BetProvider.updateBetsBatch error: $e');
    }
  }

  Future<List<BetRecord>> searchBets({
    int? lotteryType,
    String? keyword,
    String? playType,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      return await _db.searchBets(
        lotteryType: lotteryType,
        keyword: keyword,
        playType: playType,
        minAmount: minAmount,
        maxAmount: maxAmount,
        startDate: startDate,
        endDate: endDate,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      print('BetProvider.searchBets error: $e');
      return [];
    }
  }

  Future<int> getSearchBetsCount({
    int? lotteryType,
    String? keyword,
    String? playType,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _db.getSearchBetsCount(
        lotteryType: lotteryType,
        keyword: keyword,
        playType: playType,
        minAmount: minAmount,
        maxAmount: maxAmount,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('BetProvider.getSearchBetsCount error: $e');
      return 0;
    }
  }

  int get totalBets => _bets.length;

  int getBetCountByPlayType(String playType) {
    return _bets.where((b) => b.playType == playType).length;
  }
}
