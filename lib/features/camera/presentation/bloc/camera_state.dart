part of 'camera_bloc.dart';

enum CameraStatus { initializing, ready, denied, failed }

/// One-shot UI reactions (snackbar, navigation). Cleared by the next emit.
sealed class CameraEffect extends Equatable {
  const CameraEffect();

  @override
  List<Object?> get props => [];
}

class CameraMessage extends CameraEffect {
  const CameraMessage(this.text);
  final String text;

  @override
  List<Object?> get props => [text];
}

class BatchQueued extends CameraEffect {
  const BatchQueued(this.count);
  final int count;

  @override
  List<Object?> get props => [count];
}

class CameraState extends Equatable {
  const CameraState({
    this.status = CameraStatus.initializing,
    this.controller,
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.flash = FlashMode.off,
    this.batch = const [],
    this.submitting = false,
    this.pendingCount = 0,
    this.effect,
  });

  final CameraStatus status;
  final CameraController? controller;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final FlashMode flash;

  /// Photos taken since the last "Upload batch".
  final List<String> batch;
  final bool submitting;

  /// Photos still waiting to be uploaded (all batches).
  final int pendingCount;
  final CameraEffect? effect;

  /// Quick-zoom buttons, limited to what this camera can actually do.
  /// Phones with an ultra-wide lens report a min zoom below 1.
  List<double> get presets => [
        if (minZoom < 0.95) minZoom,
        1.0,
        if (maxZoom >= 2) 2.0,
        if (maxZoom >= 5) 5.0,
      ];

  CameraState copyWith({
    CameraStatus? status,
    CameraController? controller,
    bool clearController = false,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    FlashMode? flash,
    List<String>? batch,
    bool? submitting,
    int? pendingCount,
    CameraEffect? effect,
  }) {
    return CameraState(
      status: status ?? this.status,
      controller: clearController ? null : (controller ?? this.controller),
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      flash: flash ?? this.flash,
      batch: batch ?? this.batch,
      submitting: submitting ?? this.submitting,
      pendingCount: pendingCount ?? this.pendingCount,
      effect: effect, // deliberately not carried over
    );
  }

  @override
  List<Object?> get props => [
        status,
        controller,
        zoom,
        minZoom,
        maxZoom,
        flash,
        batch,
        submitting,
        pendingCount,
        effect,
      ];
}
