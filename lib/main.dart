import 'package:flutter/material.dart';

import 'ui/app.dart';
import 'ui/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LanDropApp(core: createCore()));
}
