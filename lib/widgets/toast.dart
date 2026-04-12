import 'package:flutter/material.dart';

class ToastUtil {
  static OverlayEntry? _currentToast;

  static void show(BuildContext context, String message, {Color? color}) {
    _currentToast?.remove();
    _currentToast = null;

    try {
      final overlay = Overlay.of(context);
      _currentToast = OverlayEntry(builder: (context) => _ToastWidget(message: message, color: color));
      overlay.insert(_currentToast!);
      Future.delayed(const Duration(seconds: 2), () {
        _currentToast?.remove();
        _currentToast = null;
      });
    } catch (e) {
      _showSnackBar(context, message, color);
    }
  }

  static void _showSnackBar(BuildContext context, String message, Color? color) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color ?? const Color(0xFF111827),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {}
  }

  static void success(BuildContext context, String message) => show(context, message, color: const Color(0xFF059669));
  static void error(BuildContext context, String message) => show(context, message, color: const Color(0xFFDC2626));
  static void warning(BuildContext context, String message) => show(context, message, color: const Color(0xFFF59E0B));
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final Color? color;
  const _ToastWidget({required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color ?? const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(38), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.white.withAlpha(230)),
              const SizedBox(width: 8),
              Flexible(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
  }
}
