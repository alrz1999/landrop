import 'dart:io';

import '../core/api.dart';
import '../core/landrop_core.dart';
import 'fake_core.dart';

/// Single switch between the simulated core (fake peers, simulated progress)
/// and the real network core.
const bool useFake = false;

/// [sharesStorePath]: where shares are kept across restarts (null: memory
/// only). [identityDir]: where the device certificate and key live (the app
/// support folder; null: inside the save folder).
LanDropCore createCore({String? sharesStorePath, String? identityDir}) =>
    useFake
    ? FakeCore()
    : LanDropCoreImpl(LanDropCoreOptions(
        deviceType:
            Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop',
        sharesStorePath: sharesStorePath,
        identityDir: identityDir,
        mdnsEnabled: true));
