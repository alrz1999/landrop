import 'package:flutter/material.dart';

import 'ui/app.dart';
import 'ui/app_config.dart';
import 'ui/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LanDropApp(
      core: createCore(
          sharesStorePath: await SettingsStore.sharesPath(),
          identityDir: await SettingsStore.identityPath())));
}
