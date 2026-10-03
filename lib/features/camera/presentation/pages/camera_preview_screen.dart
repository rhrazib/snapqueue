import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../upload_queue/presentation/bloc/upload_manager_bloc.dart';
import '../../../upload_queue/presentation/pages/upload_manager_page.dart';
import '../bloc/camera_bloc.dart';
import '../widgets/camera_controls.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  double _zoomAtGestureStart = 1;
  Offset? _focusPoint;
  bool _focusVisible = false;
  Timer? _focusTimer;

  /// Short white flash that confirms a capture.
  late final AnimationController _shutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _flash = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.55), weight: 25),
    TweenSequenceItem(tween: Tween<double>(begin: 0.55, end: 0), weight: 75),
  ]).animate(_shutter);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _shutter.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<CameraBloc>();
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        bloc.add(const CameraPaused());
      case AppLifecycleState.resumed:
        bloc.add(const CameraResumed());
      default:
        break;
    }
  }

  void _onTapPreview(Offset local, Size size) {
    HapticFeedback.selectionClick();
    context.read<CameraBloc>().add(
          FocusRequested(Offset(local.dx / size.width, local.dy / size.height)),
        );
    setState(() {
      _focusPoint = local;
      _focusVisible = true;
    });
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusVisible = false);
    });
  }

  void _onShutter() {
    HapticFeedback.mediumImpact();
    _shutter.forward(from: 0);
    context.read<CameraBloc>().add(const PhotoCaptured());
  }

  void _openUploadManager() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => sl<UploadManagerBloc>()..add(const UploadManagerStarted()),
        child: const UploadManagerPage(),
      ),
    ));
  }

  void _onEffect(BuildContext context, CameraState state) {
    switch (state.effect) {
      case CameraMessage(:final text):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      case BatchQueued():
        _openUploadManager();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CameraBloc, CameraState>(
      listenWhen: (prev, curr) => curr.effect != null && prev.effect != curr.effect,
      listener: _onEffect,
      builder: (context, state) {
        final bloc = context.read<CameraBloc>();
        return Scaffold(
          backgroundColor: Colors.black,
          body: switch (state.status) {
            CameraStatus.initializing => const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            CameraStatus.denied => _Problem(
                icon: Icons.no_photography_outlined,
                title: 'Camera access is off',
                message: 'Allow camera access in your phone settings, '
                    'then come back and try again.',
                onRetry: () => bloc.add(const CameraStarted()),
              ),
            CameraStatus.failed => _Problem(
                icon: Icons.error_outline,
                title: 'Camera unavailable',
                message: 'The camera could not be started. '
                    'Close other apps that use it and try again.',
                onRetry: () => bloc.add(const CameraStarted()),
              ),
            CameraStatus.ready => _buildCamera(state, bloc),
          },
        );
      },
    );
  }

  Widget _buildCamera(CameraState state, CameraBloc bloc) {
    final controller = state.controller!;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 1 / controller.value.aspectRatio,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _zoomAtGestureStart = bloc.state.zoom,
                onScaleUpdate: (d) {
                  if (d.pointerCount > 1) {
                    bloc.add(ZoomChanged(_zoomAtGestureStart * d.scale));
                  }
                },
                onTapUp: (d) => _onTapPreview(d.localPosition, box.biggest),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    if (_focusPoint != null)
                      FocusRing(position: _focusPoint!, visible: _focusVisible),
                  ],
                ),
              ),
            ),
          ),
        ),

        // soft scrims keep the controls readable on bright scenes
        const _Scrim(top: true, height: 150),
        const _Scrim(top: false, height: 320),

        IgnorePointer(
          child: FadeTransition(
            opacity: _flash,
            child: const ColoredBox(color: Colors.white),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlassIconButton(
                    icon: Icons.cloud_upload_outlined,
                    tooltip: 'Upload manager',
                    badgeCount: state.pendingCount,
                    onTap: _openUploadManager,
                  ),
                  GlassIconButton(
                    icon: switch (state.flash) {
                      FlashMode.always => Icons.flash_on,
                      FlashMode.auto => Icons.flash_auto,
                      _ => Icons.flash_off,
                    },
                    tooltip: 'Flash',
                    onTap: () => bloc.add(const FlashToggled()),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (state.maxZoom > state.minZoom)
          Align(
            alignment: const Alignment(1, -0.1),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                height: 220,
                child: VerticalZoomSlider(
                  state: state,
                  onChanged: (z) => bloc.add(ZoomChanged(z)),
                ),
              ),
            ),
          ),

        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZoomPresetRow(
                    state: state,
                    onSelect: (z) => bloc.add(ZoomChanged(z)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BatchThumbnail(batch: state.batch),
                      ShutterButton(onTap: _onShutter),
                      GlassIconButton(
                        icon: Icons.flip_camera_android_outlined,
                        tooltip: 'Switch camera',
                        onTap: () => bloc.add(const CameraFlipped()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.batch.isEmpty || state.submitting
                          ? null
                          : () => bloc.add(const BatchSubmitted()),
                      icon: state.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 20),
                      label: Text('UPLOAD BATCH (${state.batch.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.height});

  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceHigh,
            ),
            child: Icon(icon, size: 38, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }
}
