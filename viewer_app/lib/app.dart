import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Uziy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      // Force Mongolian for the entire app: showDatePicker, showTimePicker,
      // "Cancel/OK" buttons, weekday abbreviations, back-button tooltips,
      // etc. Falls back to English if a specific string hasn't been
      // translated in flutter_localizations for `mn`.
      locale: const Locale('mn'),
      supportedLocales: const [
        Locale('mn'), // Mongolian (primary)
        Locale('en'), // English fallback
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
