part of 'camera_bloc.dart';

sealed class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class CameraStarted extends CameraEvent {
  const CameraStarted();
}

class CameraPaused extends CameraEvent {
  const CameraPaused();
}

class CameraResumed extends CameraEvent {
  const CameraResumed();
}

class CameraFlipped extends CameraEvent {
  const CameraFlipped();
}

class ZoomChanged extends CameraEvent {
  const ZoomChanged(this.zoom);
  final double zoom;

  @override
  List<Object?> get props => [zoom];
}

/// [point] is normalised (0..1) inside the preview.
class FocusRequested extends CameraEvent {
  const FocusRequested(this.point);
  final Offset point;

  @override
  List<Object?> get props => [point];
}

class FlashToggled extends CameraEvent {
  const FlashToggled();
}

class PhotoCaptured extends CameraEvent {
  const PhotoCaptured();
}

class BatchSubmitted extends CameraEvent {
  const BatchSubmitted();
}

/// Fed by the queue stream; drives the badge on the upload button.
class PendingCountChanged extends CameraEvent {
  const PendingCountChanged(this.count);
  final int count;

  @override
  List<Object?> get props => [count];
}
