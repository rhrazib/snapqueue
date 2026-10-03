import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../upload_queue/domain/entities/upload_item.dart';
import '../../../upload_queue/domain/usecases/enqueue_batch.dart';
import '../../../upload_queue/domain/usecases/watch_upload_queue.dart';

part 'camera_event.dart';
part 'camera_state.dart';

/// The CameraController is a platform object the preview widget has to
/// render, so it lives in the state rather than behind a domain interface.
/// Everything that is business logic (queueing a batch) goes through a use case.
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraBloc(this._enqueueBatch, this._watchQueue) : super(const CameraState()) {
    // sequential() only orders events of ONE type. Started/paused/resumed/flipped
    // are different types, so each handler also goes through _serialized() to
    // make sure two CameraControllers are never opened at the same time.
    on<CameraStarted>(_onStarted, transformer: sequential());
    on<CameraPaused>(_onPaused, transformer: sequential());
    on<CameraResumed>(_onResumed, transformer: sequential());
    on<CameraFlipped>(_onFlipped, transformer: sequential());
    // pinch gestures fire dozens of events, only the latest one matters
    on<ZoomChanged>(_onZoomChanged, transformer: restartable());
    on<FocusRequested>(_onFocusRequested, transformer: restartable());
    // ignore double taps while the previous action is still running
    on<FlashToggled>(_onFlashToggled, transformer: droppable());
    on<PhotoCaptured>(_onPhotoCaptured, transformer: droppable());
    on<BatchSubmitted>(_onBatchSubmitted, transformer: droppable());
    on<PendingCountChanged>(
      (event, emit) => emit(state.copyWith(pendingCount: event.count)),
    );

    _queueSubscription = _watchQueue().listen((items) {
      final pending = items.where((i) => i.status != UploadStatus.synced);
      add(PendingCountChanged(pending.length));
    });
  }

  final EnqueueBatch _enqueueBatch;
  final WatchUploadQueue _watchQueue;
  late final StreamSubscription<List<UploadItem>> _queueSubscription;

  /// Tail of the queue of camera open/close work, see [_serialized].
  Future<void> _cameraWork = Future.value();

  /// Runs [action] only after all earlier open/close work has finished.
  ///
  /// Without this, the permission dialog on first launch (inactive -> resumed)
  /// started a second CameraController while the first was still initialising,
  /// which CameraX rejects with "No supported surface combination ... too many
  /// use cases".
  Future<void> _serialized(Future<void> Function() action) {
    final run = _cameraWork.then((_) => action());
    _cameraWork = run.catchError((_) {});
    return run;
  }

  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;

  static const _deniedCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  Future<void> _onStarted(CameraStarted event, Emitter<CameraState> emit) =>
      _serialized(() => _start(emit));

  Future<void> _start(Emitter<CameraState> emit) async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      _emitError(e, emit);
      return;
    }
    if (_cameras.isEmpty) {
      emit(state.copyWith(
        status: CameraStatus.failed,
        effect: const CameraMessage('No camera found on this device'),
      ));
      return;
    }
    await _open(_pick(_lens), emit);
  }

  CameraDescription _pick(CameraLensDirection direction) => _cameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _cameras.first,
      );

  Future<void> _open(
    CameraDescription description,
    Emitter<CameraState> emit,
  ) async {
    final old = state.controller;
    emit(state.copyWith(
      status: CameraStatus.initializing,
      clearController: true,
    ));
    await old?.dispose();

    // One retry: right after another controller was released the camera can
    // still be busy for a moment.
    for (var attempt = 0; attempt < 2; attempt++) {
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      try {
        await controller.initialize();
        final min = await controller.getMinZoomLevel();
        final max = math.min(await controller.getMaxZoomLevel(), 8.0);
        try {
          await controller.setFlashMode(FlashMode.off);
        } on CameraException {
          // no flash unit (front camera)
        }

        emit(state.copyWith(
          status: CameraStatus.ready,
          controller: controller,
          minZoom: min,
          maxZoom: max,
          zoom: 1.0.clamp(min, max).toDouble(),
          flash: FlashMode.off,
        ));
        return;
      } on CameraException catch (e) {
        await controller.dispose();
        final retry = attempt == 0 && !_deniedCodes.contains(e.code);
        if (!retry) {
          _emitError(e, emit);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  void _emitError(CameraException e, Emitter<CameraState> emit) {
    if (_deniedCodes.contains(e.code)) {
      emit(state.copyWith(status: CameraStatus.denied));
    } else {
      // The raw description can be a screen-long native stack message.
      debugPrint('Camera error ${e.code}: ${e.description}');
      emit(state.copyWith(
        status: CameraStatus.failed,
        effect: const CameraMessage('Camera could not start. Please try again.'),
      ));
    }
  }

  /// The camera is released while the app is in the background.
  Future<void> _onPaused(CameraPaused event, Emitter<CameraState> emit) =>
      _serialized(() async {
        final controller = state.controller;
        if (controller == null) return;
        emit(state.copyWith(
          status: CameraStatus.initializing,
          clearController: true,
        ));
        await controller.dispose();
      });

  Future<void> _onResumed(CameraResumed event, Emitter<CameraState> emit) =>
      _serialized(() async {
        if (state.controller == null && state.status != CameraStatus.denied) {
          await _start(emit);
        }
      });

  Future<void> _onFlipped(CameraFlipped event, Emitter<CameraState> emit) =>
      _serialized(() async {
        _lens = _lens == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;
        await _open(_pick(_lens), emit);
      });

  Future<void> _onZoomChanged(
    ZoomChanged event,
    Emitter<CameraState> emit,
  ) async {
    final controller = state.controller;
    if (controller == null) return;
    final zoom = event.zoom.clamp(state.minZoom, state.maxZoom).toDouble();
    emit(state.copyWith(zoom: zoom));
    try {
      await controller.setZoomLevel(zoom);
    } on CameraException {
      // can fail while the camera is being torn down
    }
  }

  Future<void> _onFocusRequested(
    FocusRequested event,
    Emitter<CameraState> emit,
  ) async {
    final controller = state.controller;
    if (controller == null) return;
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(event.point);
      await controller.setExposurePoint(event.point);
    } on CameraException {
      // front cameras usually have no focus control
    }
  }

  Future<void> _onFlashToggled(
    FlashToggled event,
    Emitter<CameraState> emit,
  ) async {
    final controller = state.controller;
    if (controller == null) return;
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(state.flash) + 1) % order.length];
    try {
      await controller.setFlashMode(next);
      emit(state.copyWith(flash: next));
    } on CameraException {
      emit(state.copyWith(
        effect: const CameraMessage('Flash is not available on this camera'),
      ));
    }
  }

  Future<void> _onPhotoCaptured(
    PhotoCaptured event,
    Emitter<CameraState> emit,
  ) async {
    final controller = state.controller;
    if (controller == null || controller.value.isTakingPicture) return;
    try {
      final file = await controller.takePicture();
      emit(state.copyWith(batch: [...state.batch, file.path]));
    } on CameraException catch (e) {
      debugPrint('Capture error ${e.code}: ${e.description}');
      emit(state.copyWith(
        effect: const CameraMessage('Could not take the photo. Try again.'),
      ));
    }
  }

  Future<void> _onBatchSubmitted(
    BatchSubmitted event,
    Emitter<CameraState> emit,
  ) async {
    final photos = state.batch;
    if (photos.isEmpty) return;

    emit(state.copyWith(submitting: true));
    try {
      await _enqueueBatch(photos);
      // Photos taken while the batch was being queued stay in the next batch.
      emit(state.copyWith(
        batch: state.batch.skip(photos.length).toList(),
        submitting: false,
        effect: BatchQueued(photos.length),
      ));
    } on Failure catch (f) {
      emit(state.copyWith(submitting: false, effect: CameraMessage(f.message)));
    } catch (_) {
      emit(state.copyWith(
        submitting: false,
        effect: const CameraMessage('Could not queue the batch. Try again.'),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _queueSubscription.cancel();
    await _cameraWork;
    await state.controller?.dispose();
    return super.close();
  }
}
