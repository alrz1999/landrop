import 'dart:io';

import '../core/api.dart';
import '../core/landrop_core.dart';
import 'fake_core.dart';

/// Single switch between the simulated core (fake peers, simulated progress)
/// and the real network core.
const bool useFake = false;

LanDropCore createCore() => useFake
    ? FakeCore()
    : LanDropCoreImpl(LanDropCoreOptions(
        deviceType:
            Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop'));
