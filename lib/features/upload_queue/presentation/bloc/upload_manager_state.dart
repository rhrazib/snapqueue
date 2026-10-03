part of 'upload_manager_bloc.dart';

class UploadManagerState extends Equatable {
  const UploadManagerState({this.items = const [], this.online = true});

  final List<UploadItem> items;
  final bool online;

  int get total => items.length;
  int get syncedCount =>
      items.where((i) => i.status == UploadStatus.synced).length;
  int get pendingCount => total - syncedCount;
  bool get hasFailed => items.any((i) => i.status == UploadStatus.failed);

  int get totalBytes => items.fold<int>(0, (sum, i) => sum + i.sizeBytes);

  int get doneBytes => items.fold<int>(0, (sum, i) {
        return sum +
            switch (i.status) {
              UploadStatus.synced => i.sizeBytes,
              UploadStatus.uploading => (i.sizeBytes * i.progress).round(),
              _ => 0,
            };
      });

  /// Share of bytes uploaded, like the "2.4 GB / 3.2 GB" line in the design.
  double get progress => totalBytes == 0 ? 0 : doneBytes / totalBytes;

  UploadManagerState copyWith({List<UploadItem>? items, bool? online}) =>
      UploadManagerState(
        items: items ?? this.items,
        online: online ?? this.online,
      );

  @override
  List<Object?> get props => [items, online];
}
