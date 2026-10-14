import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/theme_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes/app_router.dart';
import 'routes/router_push_target.dart';
import 'theme/app_theme.dart';
import 'widgets/dismiss_keyboard_on_tap.dart';

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key, this.themeController});
  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? ThemeController.instance;
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp.router(
              title: 'Uziy',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: controller.mode,
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                value: Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: DismissKeyboardOnTap(child: child!),
              ),
              routerConfig: appRouter,
              scaffoldMessengerKey: rootMessengerKey,
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
            ));
  }
}
