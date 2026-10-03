import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import '../../features/upload_queue/domain/usecases/sync_upload_queue.dart';
import '../di/injection.dart';

const _syncTask = 'snapqueue.sync';

/// Entry point of the WorkManager isolate. It has its own GetIt instance,
/// so dependencies are wired again here.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      await configureDependencies();
      final outcome = await sl<SyncUploadQueue>()();
      // false => WorkManager reschedules with exponential backoff
      return outcome == SyncOutcome.complete;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundSync {
  static final _needsNetwork = Constraints(networkType: NetworkType.connected);

  static Future<void> init() =>
      Workmanager().initialize(backgroundDispatcher);

  /// One-off job: runs as soon as the device has a network.
  static Future<void> scheduleOneOff() => Workmanager().registerOneOffTask(
        'snapqueue.sync.oneoff',
        _syncTask,
        constraints: _needsNetwork,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );

  /// Periodic job (15 min is Android's minimum) in case a one-off is lost.
  static Future<void> registerSafetyNet() => Workmanager().registerPeriodicTask(
        'snapqueue.sync.periodic',
        _syncTask,
        frequency: const Duration(minutes: 15),
        constraints: _needsNetwork,
      );
}
