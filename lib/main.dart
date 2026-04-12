import 'package:flutter/material.dart';
import 'dart:async';
import 'app.dart';
import 'services/db_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('应用加载异常', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text('请重启应用或联系开发者\nQQ: 2711793818', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Text('错误详情: ${details.exception}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          ),
        ),
      );
    };

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      print('FlutterError: ${details.exceptionAsString()}');
      print('Stack: ${details.stack}');
    };

    try {
      print('[App] Starting database initialization...');
      await DatabaseHelper.instance.database;
      print('[App] Database initialized successfully');
    } catch (e, stack) {
      print('[App] Database initialization failed: $e');
      print('[App] Stack trace: $stack');
      print('[App] Continuing with limited functionality...');
    }

    print('[App] Starting Lottery3DApp...');
    runApp(const Lottery3DApp());
    print('[App] runApp completed');
  }, (error, stack) {
    print('[App] Unhandled error: $error');
    print('[App] Stack: $stack');
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'main.dart',
      context: ErrorDescription('Unhandled error in main'),
    ));
  });
}
