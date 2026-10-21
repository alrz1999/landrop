import 'dart:io';

import '../core/api.dart';
import '../core/landrop_core.dart';
import 'fake_core.dart';

/// Single switch between the simulated core (fake peers, simulated progress)
/// and the real network core.
const bool useFake = false;

/// [sharesStorePath]: where shares are kept across restarts (null: memory
/// only).
LanDropCore createCore({String? sharesStorePath}) => useFake
    ? FakeCore()
    : LanDropCoreImpl(LanDropCoreOptions(
        deviceType:
            Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop',
        sharesStorePath: sharesStorePath,
        mdnsEnabled: true));
