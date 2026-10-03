import 'package:get_it/get_it.dart';

import '../../features/camera/presentation/bloc/camera_bloc.dart';
import '../../features/upload_queue/data/local/app_database.dart';
import '../../features/upload_queue/data/local/photo_storage.dart';
import '../../features/upload_queue/data/local/upload_local_data_source.dart';
import '../../features/upload_queue/data/remote/mock_upload_gateway.dart';
import '../../features/upload_queue/data/repositories/upload_queue_repository_impl.dart';
import '../../features/upload_queue/domain/repositories/upload_gateway.dart';
import '../../features/upload_queue/domain/repositories/upload_queue_repository.dart';
import '../../features/upload_queue/domain/services/sync_scheduler.dart';
import '../../features/upload_queue/domain/usecases/clear_synced_uploads.dart';
import '../../features/upload_queue/domain/usecases/enqueue_batch.dart';
import '../../features/upload_queue/domain/usecases/retry_failed_uploads.dart';
import '../../features/upload_queue/domain/usecases/sync_upload_queue.dart';
import '../../features/upload_queue/domain/usecases/watch_upload_queue.dart';
import '../../features/upload_queue/presentation/bloc/upload_manager_bloc.dart';
import '../network/network_info.dart';
import '../sync/sync_coordinator.dart';
import '../sync/sync_scheduler_impl.dart';

final sl = GetIt.instance;

/// Safe to call more than once; the WorkManager isolate calls it too.
Future<void> configureDependencies() async {
  if (sl.isRegistered<AppDatabase>()) return;

  sl
    // core
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl())
    // data
    ..registerLazySingleton<AppDatabase>(() => AppDatabase(),
        dispose: (db) => db.close())
    ..registerLazySingleton(() => UploadLocalDataSource(sl()))
    ..registerLazySingleton(() => PhotoStorage())
    ..registerLazySingleton<UploadQueueRepository>(
        () => UploadQueueRepositoryImpl(sl(), sl()))
    ..registerLazySingleton<UploadGateway>(() => MockUploadGateway(sl()))
    // sync
    ..registerLazySingleton(() => SyncUploadQueue(sl(), sl()))
    ..registerLazySingleton(() => SyncCoordinator(sl(), sl()))
    ..registerLazySingleton<SyncScheduler>(() => SyncSchedulerImpl(sl()))
    // use cases
    ..registerLazySingleton(() => EnqueueBatch(sl(), sl()))
    ..registerLazySingleton(() => WatchUploadQueue(sl()))
    ..registerLazySingleton(() => RetryFailedUploads(sl(), sl()))
    ..registerLazySingleton(() => ClearSyncedUploads(sl()))
    // blocs
    ..registerFactory(() => CameraBloc(sl(), sl()))
    ..registerFactory(() => UploadManagerBloc(sl(), sl(), sl(), sl()));
}
