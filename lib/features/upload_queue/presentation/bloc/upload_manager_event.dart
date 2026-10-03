part of 'upload_manager_bloc.dart';

sealed class UploadManagerEvent extends Equatable {
  const UploadManagerEvent();

  @override
  List<Object?> get props => [];
}

class UploadManagerStarted extends UploadManagerEvent {
  const UploadManagerStarted();
}

class RetryFailedPressed extends UploadManagerEvent {
  const RetryFailedPressed();
}

class ClearSyncedPressed extends UploadManagerEvent {
  const ClearSyncedPressed();
}
