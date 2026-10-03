String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 1 -> "1x", 1.74 -> "1.7x"
String formatZoom(double z) {
  final rounded = double.parse(z.toStringAsFixed(1));
  final whole = rounded == rounded.roundToDouble();
  return '${whole ? rounded.toInt() : rounded}x';
}
