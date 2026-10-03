import 'package:flutter/material.dart';

/// Single source of truth for colour. Screens never hard-code a hex value.
abstract final class AppColors {
  // surfaces (dark, slightly blue-tinted neutrals)
  static const background = Color(0xFF080B12);
  static const surface = Color(0xFF111620);
  static const surfaceHigh = Color(0xFF1A2130);
  static const outline = Color(0xFF263044);

  // brand
  static const primary = Color(0xFF2F6FED); // 4.6:1 against white text
  static const primaryLight = Color(0xFF7BA4FF); // for text/icons on dark

  // semantic
  static const success = Color(0xFF2EC27E);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFFF5C6C);

  // text
  static const textPrimary = Color(0xFFF3F6FB);
  static const textSecondary = Color(0xFF9AA7BD);
  static const textMuted = Color(0xFF6B788E);

  // camera overlay
  static const glass = Color(0x73000000); // 45% black
  static const glassBorder = Color(0x29FFFFFF); // 16% white
  static const accent = Color(0xFFFFD166); // focus ring, active zoom
}
