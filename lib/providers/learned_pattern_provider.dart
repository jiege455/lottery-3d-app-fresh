import 'package:flutter/foundation.dart';
import '../models/learned_pattern.dart';
import '../services/db_service.dart';
import '../core/utils/pattern_learner.dart';

class LearnedPatternProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<LearnedPattern> _patterns = [];
  bool _isLoaded = false;

  List<LearnedPattern> get patterns => _patterns;
  bool get isLoaded => _isLoaded;

  Future<void> loadPatterns() async {
    try {
      _patterns = await _db.getAllLearnedPatterns();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('LearnedPatternProvider.loadPatterns error: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<int> addPattern(String sampleText, String playType, String playTypeName) async {
    try {
      final learned = PatternLearner.learn(sampleText, playType, playTypeName);
      final id = await _db.insertLearnedPattern(learned);
      await loadPatterns();
      return id;
    } catch (e) {
      print('LearnedPatternProvider.addPattern error: $e');
      return -1;
    }
  }

  Future<void> deletePattern(int id) async {
    try {
      await _db.deleteLearnedPattern(id);
      _patterns.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      print('LearnedPatternProvider.deletePattern error: $e');
    }
  }

  Future<void> updatePriority(int id, int priority) async {
    try {
      final index = _patterns.indexWhere((p) => p.id == id);
      if (index == -1) return;
      final updated = LearnedPattern(
        id: id,
        sampleText: _patterns[index].sampleText,
        playType: _patterns[index].playType,
        playTypeName: _patterns[index].playTypeName,
        pattern: _patterns[index].pattern,
        priority: priority,
        createdAt: _patterns[index].createdAt,
      );
      await _db.updateLearnedPattern(updated);
      _patterns[index] = updated;
      notifyListeners();
    } catch (e) {
      print('LearnedPatternProvider.updatePriority error: $e');
    }
  }
}
