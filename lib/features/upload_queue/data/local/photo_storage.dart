import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredPhoto {
  const StoredPhoto(this.path, this.sizeBytes, this.source);
  final String path;
  final int sizeBytes;

  /// Where the photo came from, so a failed enqueue can put it back.
  final String source;
}

/// Owns the files of queued photos (app documents, not the camera cache).
class PhotoStorage {
  /// Moves all photos or none: on failure the ones already moved are put back.
  Future<List<StoredPhoto>> moveIntoBatch(
    String batchId,
    List<String> sources,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'pending', batchId));
    await dir.create(recursive: true);

    final stored = <StoredPhoto>[];
    try {
      for (var i = 0; i < sources.length; i++) {
        final n = (i + 1).toString().padLeft(2, '0');
        final target = File(p.join(dir.path, 'IMG_${batchId}_$n.jpg'));
        await _move(File(sources[i]), target);
        stored.add(StoredPhoto(target.path, await target.length(), sources[i]));
      }
    } catch (_) {
      await restore(stored);
      await _removeIfEmpty(dir);
      rethrow;
    }
    return stored;
  }

  /// Best-effort undo of [moveIntoBatch].
  Future<void> restore(List<StoredPhoto> photos) async {
    for (final photo in photos) {
      try {
        await _move(File(photo.path), File(photo.source));
      } on FileSystemException {
        // nothing more we can do for this one
      }
    }
    if (photos.isNotEmpty) {
      await _removeIfEmpty(File(photos.first.path).parent);
    }
  }

  /// Deletes the files and their batch folder once it is empty.
  Future<void> deleteAll(Iterable<String> paths) async {
    final dirs = <Directory>{};
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      dirs.add(file.parent);
    }
    for (final dir in dirs) {
      await _removeIfEmpty(dir);
    }
  }

  Future<void> _removeIfEmpty(Directory dir) async {
    try {
      if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
    } on FileSystemException {
      // not worth failing for
    }
  }

  Future<void> _move(File source, File target) async {
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // rename fails across volumes, fall back to copy + delete
      await source.copy(target.path);
      await source.delete();
    }
  }
}
