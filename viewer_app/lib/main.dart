import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'routes/app_router.dart';
import 'routes/router_push_target.dart';
import 'services/push/push_runtime.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // Rehydrate the persisted JWT into Dio's headers so /viewer/* calls made
  // during splash / early screens don't 401.
  await AuthService.instance.restore();
  // Auth must tell the backend to forget this device before the JWT goes.
  AuthService.instance.onBeforeLogout = PushRuntime.instance.onLogout;
  // Push is optional: a failure here (no Firebase config yet) disables it.
  await PushRuntime.instance.init(
    target: RouterPushTarget(appRouter),
    videoRoute: Routes.video,
    surveyRoute: Routes.survey,
  );
  runApp(const ProviderScope(child: ViewerApp()));
}
