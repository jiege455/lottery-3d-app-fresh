import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class DevBar extends StatelessWidget {
  const DevBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('开发者：杰哥网络科技', style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}
