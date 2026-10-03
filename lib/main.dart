import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/constants/app_config.dart';
import 'services/api_client.dart';
import 'services/local_store.dart';
import 'services/realtime_client.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadEnv();

  // Mobile convention: Portrait-only orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final store = await LocalStore.create();
  final initialUrl = store.serverUrl?.trim().isNotEmpty == true
      ? store.serverUrl!
      : AppConfig.defaultServerUrl;

  final api = ApiClient(baseUrl: initialUrl, token: store.token);
  final realtime = RealtimeClient(baseUrl: initialUrl, token: store.token);

  final controller = AppController(
    api: api,
    realtime: realtime,
    store: store,
  );

  // Read stored identity and connect
  await controller.bootstrap();

  runApp(
    AppScope(
      controller: controller,
      child: const FunDiceApp(),
    ),
  );
}
