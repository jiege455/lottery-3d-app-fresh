import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/bet_record.dart';
import '../models/draw_record.dart';
import '../models/app_settings.dart';
import '../models/template_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Completer<Database>? _initCompleter;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<Database>();
    try {
      _database = await _initDB('lottery3d.db');
      _initCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      print('Database initialization error: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      _database = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bet_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL,
        play_type TEXT NOT NULL,
        play_type_name TEXT NOT NULL,
        lottery_type INTEGER DEFAULT 1,
        multiplier REAL DEFAULT 1.0,
        base_amount REAL DEFAULT 2.0,
        batch_id TEXT DEFAULT '',
        create_time TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_bet_lottery_type ON bet_records(lottery_type)');
    await db.execute('CREATE INDEX idx_bet_batch_id ON bet_records(batch_id)');
    await db.execute('CREATE INDEX idx_bet_create_time ON bet_records(create_time)');
    await db.execute('CREATE INDEX idx_bet_play_type ON bet_records(play_type)');

    await db.execute('''
      CREATE TABLE draw_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        issue TEXT NOT NULL,
        numbers TEXT NOT NULL,
        sum_value INTEGER DEFAULT 0,
        span INTEGER DEFAULT 0,
        form_type TEXT DEFAULT '',
        draw_date TEXT NOT NULL,
        lottery_type INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_draw_lottery_type ON draw_records(lottery_type)');
    await db.execute('CREATE INDEX idx_draw_date ON draw_records(draw_date)');
    await db.execute('CREATE INDEX idx_draw_issue ON draw_records(issue)');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        default_multiplier REAL DEFAULT 1.0,
        default_lottery_type INTEGER DEFAULT 1,
        last_backup_time TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE play_type_amounts (
        play_type TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        win_amount REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_format_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        template TEXT NOT NULL,
        play_type_code TEXT NOT NULL,
        default_multiplier REAL DEFAULT 1.0,
        enabled INTEGER DEFAULT 1,
        create_time TEXT NOT NULL
      )
    ''');

    await db.insert('settings', {'id': 1, 'default_multiplier': 2.0, 'default_lottery_type': 1, 'last_backup_time': ''}, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        play_type TEXT DEFAULT 'auto',
        play_type_name TEXT DEFAULT '自动识别',
        default_multiplier TEXT DEFAULT '2',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('DROP TABLE IF EXISTS custom_play_types');
      } catch (e) {
        print('Database upgrade v2 error: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await _createTableIfNotExists(db, 'settings', '''
          CREATE TABLE settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            default_multiplier REAL DEFAULT 1.0,
            default_lottery_type INTEGER DEFAULT 1,
            last_backup_time TEXT DEFAULT ''
          )
        ''');
        await _createTableIfNotExists(db, 'play_type_amounts', '''
          CREATE TABLE play_type_amounts (
            play_type TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            win_amount REAL DEFAULT 0.0
          )
        ''');
        await _ensureSettingsRow(db);
        await _createIndexIfNotExists(db, 'idx_bet_lottery_type', 'bet_records', 'lottery_type');
        await _createIndexIfNotExists(db, 'idx_bet_batch_id', 'bet_records', 'batch_id');
        await _createIndexIfNotExists(db, 'idx_bet_create_time', 'bet_records', 'create_time');
        await _createIndexIfNotExists(db, 'idx_bet_play_type', 'bet_records', 'play_type');
        await _createIndexIfNotExists(db, 'idx_draw_lottery_type', 'draw_records', 'lottery_type');
        await _createIndexIfNotExists(db, 'idx_draw_date', 'draw_records', 'draw_date');
        await _createIndexIfNotExists(db, 'idx_draw_issue', 'draw_records', 'issue');
      } catch (e) {
        print('Database upgrade v3 error: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        final result = await db.query('settings', where: 'id = 1');
        if (result.isNotEmpty) {
          final oldMult = (result.first['default_multiplier'] as num?)?.toDouble() ?? 1.0;
          final newAmount = oldMult * 2.0;
          await db.update('settings', {'default_multiplier': newAmount}, where: 'id = 1');
        }
      } catch (e) {
        print('Database upgrade v4 error: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await _createTableIfNotExists(db, 'templates', '''
          CREATE TABLE templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            content TEXT NOT NULL,
            play_type TEXT DEFAULT 'auto',
            play_type_name TEXT DEFAULT '自动识别',
            default_multiplier TEXT DEFAULT '2',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('DROP TABLE IF EXISTS custom_format_rules');
        await db.execute('''
          CREATE TABLE custom_format_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            template TEXT NOT NULL,
            play_type_code TEXT NOT NULL,
            default_multiplier REAL DEFAULT 1.0,
            enabled INTEGER DEFAULT 1,
            create_time TEXT NOT NULL
          )
        ''');
      } catch (e) {
        print('Database upgrade v5 error: $e');
      }
    }
  }

  Future<void> _createTableIfNotExists(Database db, String tableName, String createSql) async {
    try {
      final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [tableName]);
      if (result.isEmpty) {
        await db.execute(createSql);
      }
    } catch (e) {
      print('Create table $tableName error: $e');
    }
  }

  Future<void> _ensureSettingsRow(Database db) async {
    try {
      final result = await db.query('settings', where: 'id = 1');
      if (result.isEmpty) {
        await db.insert('settings', {'id': 1, 'default_multiplier': 2.0, 'default_lottery_type': 1, 'last_backup_time': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print('Ensure settings row error: $e');
    }
  }

  Future<void> _createIndexIfNotExists(Database db, String indexName, String table, String column) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS $indexName ON $table($column)');
    } catch (e) {
      print('Create index $indexName error: $e');
    }
  }

  Future<int> insertBet(BetRecord record) async {
    try {
      _validateBetRecord(record);
      final db = await database;
      return await db.insert('bet_records', record.toMap());
    } catch (e) {
      print('insertBet error: $e');
      rethrow;
    }
  }

  static void _validateBetRecord(BetRecord record) {
    if (record.number.isEmpty) {
      throw ArgumentError('投注号码不能为空');
    }
    if (record.playType.isEmpty) {
      throw ArgumentError('玩法类型不能为空');
    }
    if (record.playTypeName.isEmpty) {
      throw ArgumentError('玩法名称不能为空');
    }
    if (record.number.length > 100) {
      throw ArgumentError('投注号码长度不能超过100个字符');
    }
    if (record.multiplier <= 0 || record.multiplier > 99999) {
      throw ArgumentError('投注倍数无效');
    }
    if (record.baseAmount <= 0 || record.baseAmount > 99999) {
      throw ArgumentError('投注金额必须在 1-99999 元之间');
    }
    if (record.lotteryType < 1 || record.lotteryType > 99) {
      throw ArgumentError('彩票类型无效');
    }
  }

  Future<List<BetRecord>> getAllBets({int? lotteryType}) async {
    try {
      final db = await database;
      if (lotteryType != null) {
        final result = await db.query('bet_records', where: 'lottery_type = ?', whereArgs: [lotteryType], orderBy: 'create_time DESC');
        return result.map((e) => BetRecord.fromMap(e)).toList();
      }
      final result = await db.query('bet_records', orderBy: 'create_time DESC');
      return result.map((e) => BetRecord.fromMap(e)).toList();
    } catch (e) {
      print('getAllBets error: $e');
      return [];
    }
  }

  Future<List<BetRecord>> getBetsPaged({int? lotteryType, int page = 1, int pageSize = 50}) async {
    try {
      final db = await database;
      final offset = (page - 1) * pageSize;
      if (lotteryType != null) {
        final result = await db.query(
          'bet_records',
          where: 'lottery_type = ?',
          whereArgs: [lotteryType],
          orderBy: 'create_time DESC',
          limit: pageSize,
          offset: offset,
        );
        return result.map((e) => BetRecord.fromMap(e)).toList();
      }
      final result = await db.query(
        'bet_records',
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
      return result.map((e) => BetRecord.fromMap(e)).toList();
    } catch (e) {
      print('getBetsPaged error: $e');
      return [];
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
      final db = await database;
      final conditions = <String>[];
      final args = <dynamic>[];

      if (lotteryType != null) {
        conditions.add('lottery_type = ?');
        args.add(lotteryType);
      }
      if (keyword != null && keyword.isNotEmpty) {
        conditions.add('(number LIKE ? OR play_type_name LIKE ? OR play_type LIKE ? OR batch_id LIKE ?)');
        final pattern = '%$keyword%';
        args.addAll([pattern, pattern, pattern, pattern]);
      }
      if (playType != null && playType.isNotEmpty) {
        conditions.add('play_type = ?');
        args.add(playType);
      }
      if (minAmount != null) {
        conditions.add('(multiplier * base_amount) >= ?');
        args.add(minAmount);
      }
      if (maxAmount != null) {
        conditions.add('(multiplier * base_amount) <= ?');
        args.add(maxAmount);
      }
      if (startDate != null) {
        conditions.add('create_time >= ?');
        args.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        conditions.add('create_time <= ?');
        args.add(endDate.toIso8601String());
      }

      final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');
      final offset = (page - 1) * pageSize;

      final result = await db.query(
        'bet_records',
        where: whereClause,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
      return result.map((e) => BetRecord.fromMap(e)).toList();
    } catch (e) {
      print('searchBets error: $e');
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
      final db = await database;
      final conditions = <String>[];
      final args = <dynamic>[];

      if (lotteryType != null) {
        conditions.add('lottery_type = ?');
        args.add(lotteryType);
      }
      if (keyword != null && keyword.isNotEmpty) {
        conditions.add('(number LIKE ? OR play_type_name LIKE ? OR play_type LIKE ? OR batch_id LIKE ?)');
        final pattern = '%$keyword%';
        args.addAll([pattern, pattern, pattern, pattern]);
      }
      if (playType != null && playType.isNotEmpty) {
        conditions.add('play_type = ?');
        args.add(playType);
      }
      if (minAmount != null) {
        conditions.add('(multiplier * base_amount) >= ?');
        args.add(minAmount);
      }
      if (maxAmount != null) {
        conditions.add('(multiplier * base_amount) <= ?');
        args.add(maxAmount);
      }
      if (startDate != null) {
        conditions.add('create_time >= ?');
        args.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        conditions.add('create_time <= ?');
        args.add(endDate.toIso8601String());
      }

      final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bet_records${whereClause != null ? " WHERE $whereClause" : ""}',
        args.isEmpty ? null : args,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('getSearchBetsCount error: $e');
      return 0;
    }
  }

  Future<int> updateBet(BetRecord record) async {
    try {
      if (record.id == null) return 0;
      final db = await database;
      return await db.update('bet_records', record.toMap(), where: 'id = ?', whereArgs: [record.id]);
    } catch (e) {
      print('updateBet error: $e');
      return 0;
    }
  }

  Future<int> deleteBetsByIds(List<int> ids) async {
    try {
      if (ids.isEmpty) return 0;
      final db = await database;
      final placeholders = List.filled(ids.length, '?').join(',');
      return await db.delete('bet_records', where: 'id IN ($placeholders)', whereArgs: ids);
    } catch (e) {
      print('deleteBetsByIds error: $e');
      return 0;
    }
  }

  Future<int> getBetCount({int? lotteryType}) async {
    try {
      final db = await database;
      if (lotteryType != null) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM bet_records WHERE lottery_type = ?', [lotteryType]);
        return Sqflite.firstIntValue(result) ?? 0;
      }
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM bet_records');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('getBetCount error: $e');
      return 0;
    }
  }

  Future<int> deleteBet(int id) async {
    try {
      final db = await database;
      return await db.delete('bet_records', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('deleteBet error: $e');
      return 0;
    }
  }

  Future<int> deleteAllBets() async {
    try {
      final db = await database;
      return await db.delete('bet_records');
    } catch (e) {
      print('deleteAllBets error: $e');
      return 0;
    }
  }

  Future<int> deleteBetsByBatchId(String batchId) async {
    try {
      final db = await database;
      return await db.delete('bet_records', where: 'batch_id = ?', whereArgs: [batchId]);
    } catch (e) {
      print('deleteBetsByBatchId error: $e');
      return 0;
    }
  }

  Future<int> deleteAllDraws() async {
    try {
      final db = await database;
      return await db.delete('draw_records');
    } catch (e) {
      print('deleteAllDraws error: $e');
      return 0;
    }
  }

  Future<void> insertBetsBatch(List<BetRecord> records) async {
    try {
      if (records.isEmpty) return;
      for (final record in records) {
        _validateBetRecord(record);
      }
      final db = await database;
      final batch = db.batch();
      for (final record in records) {
        batch.insert('bet_records', record.toMap());
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('insertBetsBatch error: $e');
      rethrow;
    }
  }

  Future<int> insertDraw(DrawRecord record) async {
    try {
      _validateDrawRecord(record);
      final db = await database;
      return await db.insert('draw_records', record.toMap());
    } catch (e) {
      print('insertDraw error: $e');
      rethrow;
    }
  }

  static void _validateDrawRecord(DrawRecord record) {
    if (record.issue.isEmpty) {
      throw ArgumentError('开奖期号不能为空');
    }
    if (record.numbers.isEmpty) {
      throw ArgumentError('开奖号码不能为空');
    }
    if (record.numbers.length != 3) {
      throw ArgumentError('开奖号码必须是3位数字');
    }
    if (!RegExp(r'^[0-9]{3}$').hasMatch(record.numbers)) {
      throw ArgumentError('开奖号码格式无效，必须是3位数字');
    }
  }

  Future<List<DrawRecord>> getAllDraws({int? lotteryType, int? limit}) async {
    try {
      final db = await database;
      String query = 'SELECT * FROM draw_records';
      List<dynamic> args = [];
      if (lotteryType != null) {
        query += ' WHERE lottery_type = ?';
        args.add(lotteryType);
      }
      query += ' ORDER BY draw_date DESC';
      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }
      final result = await db.rawQuery(query, args.isEmpty ? null : args);
      return result.map((e) => DrawRecord.fromMap(e)).toList();
    } catch (e) {
      print('getAllDraws error: $e');
      return [];
    }
  }

  Future<int> deleteDraw(int id) async {
    try {
      final db = await database;
      return await db.delete('draw_records', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('deleteDraw error: $e');
      return 0;
    }
  }

  Future<AppSettings> getSettings() async {
    try {
      final db = await database;
      final result = await db.query('settings', where: 'id = 1');
      if (result.isNotEmpty) {
        return AppSettings.fromMap(result.first);
      }
      await db.insert('settings', {'id': 1, 'default_multiplier': 1.0, 'default_lottery_type': 1, 'last_backup_time': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
      return AppSettings();
    } catch (e) {
      print('getSettings error: $e');
      return AppSettings();
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    try {
      final db = await database;
      await db.update('settings', settings.toMap(), where: 'id = 1');
    } catch (e) {
      print('updateSettings error: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> getPlayTypeStats({int? lotteryType}) async {
    try {
      final db = await database;
      String query = 'SELECT play_type, play_type_name, COUNT(*) as count, SUM(multiplier * base_amount) as total_amount FROM bet_records';
      if (lotteryType != null) {
        query += ' WHERE lottery_type = ?';
      }
      query += ' GROUP BY play_type, play_type_name ORDER BY count DESC';
      final result = await db.rawQuery(query, lotteryType != null ? [lotteryType] : null);
      Map<String, Map<String, dynamic>> stats = {};
      for (final row in result) {
        final playType = row['play_type'];
        final count = row['count'];
        final totalAmount = row['total_amount'];
        if (playType != null && count != null) {
          stats[playType as String] = {
            'count': count as int,
            'totalAmount': (totalAmount is num ? totalAmount.toDouble() : (double.tryParse(totalAmount?.toString() ?? '0') ?? 0.0)),
          };
        }
      }
      return stats;
    } catch (e) {
      print('getPlayTypeStats error: $e');
      return {};
    }
  }

  Future<Map<String, int>> getDigitFrequency({int? lotteryType}) async {
    try {
      final db = await database;
      String query = 'SELECT number FROM bet_records';
      if (lotteryType != null) {
        query += ' WHERE lottery_type = ?';
      }
      final result = await db.rawQuery(query, lotteryType != null ? [lotteryType] : null);
      Map<String, int> freq = {};
      for (var i = 0; i < 10; i++) {
        freq[i.toString()] = 0;
      }
      for (final row in result) {
        final num = row['number'];
        if (num == null) continue;
        final numStr = num as String;
        for (final char in numStr.split('')) {
          if (RegExp(r'[0-9]').hasMatch(char)) {
            freq[char] = (freq[char] ?? 0) + 1;
          }
        }
      }
      return freq;
    } catch (e) {
      print('getDigitFrequency error: $e');
      return {};
    }
  }

  Future<Map<String, double>> getPlayTypeAmounts() async {
    try {
      final db = await database;
      final result = await db.query('play_type_amounts');
      Map<String, double> amounts = {};
      for (final row in result) {
        final playType = row['play_type'] as String?;
        final amount = row['amount'] is num ? (row['amount'] as num).toDouble() : (double.tryParse(row['amount']?.toString() ?? '') ?? 0.0);
        if (playType != null) {
          amounts[playType] = amount;
        }
      }
      return amounts;
    } catch (e) {
      print('getPlayTypeAmounts error: $e');
      return {};
    }
  }

  Future<Map<String, double>> getPlayTypeWinAmounts() async {
    try {
      final db = await database;
      final result = await db.query('play_type_amounts');
      Map<String, double> amounts = {};
      for (final row in result) {
        final playType = row['play_type'] as String?;
        final winAmount = row['win_amount'] is num ? (row['win_amount'] as num).toDouble() : (double.tryParse(row['win_amount']?.toString() ?? '') ?? 0.0);
        if (playType != null) {
          amounts[playType] = winAmount;
        }
      }
      return amounts;
    } catch (e) {
      print('getPlayTypeWinAmounts error: $e');
      return {};
    }
  }

  Future<({Map<String, double> amounts, Map<String, double> winAmounts})> getPlayTypeAmountsAndWinAmounts() async {
    try {
      final db = await database;
      final result = await db.query('play_type_amounts');
      Map<String, double> amounts = {};
      Map<String, double> winAmounts = {};
      for (final row in result) {
        final playType = row['play_type'] as String?;
        if (playType == null) continue;
        final amount = row['amount'] is num ? (row['amount'] as num).toDouble() : (double.tryParse(row['amount']?.toString() ?? '') ?? 0.0);
        final winAmount = row['win_amount'] is num ? (row['win_amount'] as num).toDouble() : (double.tryParse(row['win_amount']?.toString() ?? '') ?? 0.0);
        amounts[playType] = amount;
        winAmounts[playType] = winAmount;
      }
      return (amounts: amounts, winAmounts: winAmounts);
    } catch (e) {
      print('getPlayTypeAmountsAndWinAmounts error: $e');
      return (amounts: <String, double>{}, winAmounts: <String, double>{});
    }
  }

  Future<void> setPlayTypeAmount(String playType, double amount, double winAmount) async {
    try {
      final db = await database;
      await db.insert('play_type_amounts', {'play_type': playType, 'amount': amount, 'win_amount': winAmount}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('setPlayTypeAmount error: $e');
    }
  }

  Future<void> resetPlayTypeAmounts() async {
    try {
      final db = await database;
      await db.delete('play_type_amounts');
    } catch (e) {
      print('resetPlayTypeAmounts error: $e');
    }
  }

  Future<List<TemplateRecord>> getAllTemplates() async {
    try {
      final db = await database;
      final result = await db.query('templates', orderBy: 'updated_at DESC');
      return result.map((e) => TemplateRecord.fromMap(e)).toList();
    } catch (e) {
      print('getAllTemplates error: $e');
      return [];
    }
  }

  Future<int> insertTemplate(TemplateRecord template) async {
    try {
      final db = await database;
      return await db.insert('templates', template.toMap());
    } catch (e) {
      print('insertTemplate error: $e');
      return -1;
    }
  }

  Future<int> updateTemplate(TemplateRecord template) async {
    try {
      if (template.id == null) return 0;
      final db = await database;
      return await db.update('templates', template.toMap(), where: 'id = ?', whereArgs: [template.id]);
    } catch (e) {
      print('updateTemplate error: $e');
      return 0;
    }
  }

  Future<int> deleteTemplate(int id) async {
    try {
      final db = await database;
      return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('deleteTemplate error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomFormatRules() async {
    try {
      final db = await database;
      return await db.query('custom_format_rules', orderBy: 'create_time DESC');
    } catch (e) {
      print('getCustomFormatRules error: $e');
      return [];
    }
  }

  Future<void> saveCustomFormatRules(List<Map<String, dynamic>> rules) async {
    try {
      final db = await database;
      await db.delete('custom_format_rules');
      for (final rule in rules) {
        await db.insert('custom_format_rules', rule);
      }
    } catch (e) {
      print('saveCustomFormatRules error: $e');
    }
  }

  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        _initCompleter = null;
      }
    } catch (e) {
      print('close error: $e');
    }
  }
}
