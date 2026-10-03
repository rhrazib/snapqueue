import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../bloc/camera_bloc.dart';

/// Round translucent button that stays readable on any preview.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: AppColors.glass,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.glassBorder),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Icon(icon, size: 22, color: Colors.white),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: CountBadge(count: badgeCount),
              ),
          ],
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.background, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class ShutterButton extends StatefulWidget {
  const ShutterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pressed ? Colors.white70 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Last photo of the current batch with a count badge.
class BatchThumbnail extends StatelessWidget {
  const BatchThumbnail({super.key, required this.batch});

  final List<String> batch;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      label: '${batch.length} photos in this batch',
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: AppColors.glass,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: batch.isEmpty
                      ? const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white54,
                          size: 22,
                        )
                      : Image.file(
                          File(batch.last),
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                        ),
                ),
              ),
            ),
            if (batch.isNotEmpty)
              Positioned(
                top: -6,
                right: -6,
                child: CountBadge(count: batch.length),
              ),
          ],
        ),
      ),
    );
  }
}

/// 0.5x / 1x / 2x ... pill. The active button shows the live zoom value.
class ZoomPresetRow extends StatelessWidget {
  const ZoomPresetRow({super.key, required this.state, required this.onSelect});

  final CameraState state;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    final presets = state.presets;
    var active = 0;
    for (var i = 1; i < presets.length; i++) {
      if ((presets[i] - state.zoom).abs() < (presets[active] - state.zoom).abs()) {
        active = i;
      }
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < presets.length; i++)
            _PresetButton(
              label: formatZoom(i == active ? state.zoom : presets[i]),
              active: i == active,
              onTap: () => onSelect(presets[i]),
            ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Zoom $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: active ? 50 : 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.black54 : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: active ? 13 : 12,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.accent : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class VerticalZoomSlider extends StatelessWidget {
  const VerticalZoomSlider({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final CameraState state;
  final ValueChanged<double> onChanged;

  static const _label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(formatZoom(state.maxZoom), style: _label),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  min: state.minZoom,
                  max: state.maxZoom,
                  value: state.zoom.clamp(state.minZoom, state.maxZoom),
                  semanticFormatterCallback: formatZoom,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Text(formatZoom(state.minZoom), style: _label),
        ],
      ),
    );
  }
}

/// Square that pops in at the tap point after tap-to-focus, then fades.
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.position, required this.visible});

  final Offset position;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(position),
            tween: Tween(begin: 1.4, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
