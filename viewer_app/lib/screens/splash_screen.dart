import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // TODO: replace with real auth-token check via AuthService.
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      context.go(Routes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 128,
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 44,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'Uziy',
          ),
        ),
      ),
    );
  }
}
