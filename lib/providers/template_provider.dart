import 'package:flutter/foundation.dart';
import '../models/template_record.dart';
import '../services/db_service.dart';

class TemplateProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<TemplateRecord> _templates = [];
  bool _isLoaded = false;

  List<TemplateRecord> get templates => _templates;
  bool get isLoaded => _isLoaded;

  Future<void> loadTemplates() async {
    try {
      _templates = await _db.getAllTemplates();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('TemplateProvider.loadTemplates error: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<int> addTemplate(TemplateRecord template) async {
    try {
      final id = await _db.insertTemplate(template);
      await loadTemplates();
      return id;
    } catch (e) {
      print('TemplateProvider.addTemplate error: $e');
      return -1;
    }
  }

  Future<void> updateTemplate(TemplateRecord template) async {
    try {
      await _db.updateTemplate(template);
      await loadTemplates();
    } catch (e) {
      print('TemplateProvider.updateTemplate error: $e');
    }
  }

  Future<void> deleteTemplate(int id) async {
    try {
      await _db.deleteTemplate(id);
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      print('TemplateProvider.deleteTemplate error: $e');
    }
  }
}
