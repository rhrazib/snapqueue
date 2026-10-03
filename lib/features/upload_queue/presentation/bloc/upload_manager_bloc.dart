import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_info.dart';
import '../../domain/entities/upload_item.dart';
import '../../domain/usecases/clear_synced_uploads.dart';
import '../../domain/usecases/retry_failed_uploads.dart';
import '../../domain/usecases/watch_upload_queue.dart';

part 'upload_manager_event.dart';
part 'upload_manager_state.dart';

class UploadManagerBloc extends Bloc<UploadManagerEvent, UploadManagerState> {
  UploadManagerBloc(
    this._watchQueue,
    this._retryFailed,
    this._clearSynced,
    this._network,
  ) : super(const UploadManagerState()) {
    on<UploadManagerStarted>(_onStarted);
    on<RetryFailedPressed>((_, __) => _retryFailed());
    on<ClearSyncedPressed>((_, __) => _clearSynced());
  }

  final WatchUploadQueue _watchQueue;
  final RetryFailedUploads _retryFailed;
  final ClearSyncedUploads _clearSynced;
  final NetworkInfo _network;

  Future<void> _onStarted(
    UploadManagerStarted event,
    Emitter<UploadManagerState> emit,
  ) async {
    emit(state.copyWith(online: await _network.isOnline));

    // Both streams live as long as the bloc. The queue stream also fires
    // for rows written by the WorkManager isolate (see AppDatabase).
    await Future.wait([
      emit.forEach<List<UploadItem>>(
        _watchQueue(),
        onData: (items) => state.copyWith(items: items),
      ),
      emit.forEach<bool>(
        _network.onStatusChange,
        onData: (online) => state.copyWith(online: online),
      ),
    ]);
  }
}
