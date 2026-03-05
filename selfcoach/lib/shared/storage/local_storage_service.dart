import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/recording/clip_metadata.dart';

/// Persists the clip index and manages clip files on local storage (PRD §2.5).
///
/// The clip index is stored as a JSON array in
/// `{documents}/selfcoach/clips/index.json`.
/// Video files and thumbnails are stored alongside it in that directory.
class LocalStorageService {
  static const _indexFileName = 'index.json';
  static const _clipsSubdir = 'selfcoach/clips';

  // ---------------------------------------------------------------------------
  // Directory helpers
  // ---------------------------------------------------------------------------

  Future<Directory> get _clipsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _clipsSubdir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _indexFile async {
    final dir = await _clipsDir;
    return File(p.join(dir.path, _indexFileName));
  }

  /// Returns a path for a new video clip file.
  Future<String> newClipPath() async {
    final dir = await _clipsDir;
    final name = 'clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return p.join(dir.path, name);
  }

  /// Returns a path for a new thumbnail file.
  Future<String> newThumbnailPath() async {
    final dir = await _clipsDir;
    final name = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return p.join(dir.path, name);
  }

  /// Returns a path for a temporary pre-buffer recording file.
  Future<String> newTempPath(String suffix) async {
    final dir = await _clipsDir;
    final name = 'tmp_${suffix}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return p.join(dir.path, name);
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Loads the full clip index from disk. Returns an empty list if none found.
  Future<List<VideoClip>> loadClips() async {
    final file = await _indexFile;
    if (!file.existsSync()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => VideoClip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt index — start fresh.
      return [];
    }
  }

  /// Persists [clips] to the index file, replacing whatever was there.
  Future<void> saveClips(List<VideoClip> clips) async {
    final file = await _indexFile;
    final json = jsonEncode(clips.map((c) => c.toJson()).toList());
    await file.writeAsString(json, flush: true);
  }

  /// Appends [clip] to the persisted index.
  Future<void> addClip(VideoClip clip) async {
    final clips = await loadClips();
    clips.insert(0, clip); // newest first
    await saveClips(clips);
  }

  /// Updates the mutable fields (name, tags) for [clip] in the persisted index.
  Future<void> updateClip(VideoClip clip) async {
    final clips = await loadClips();
    final idx = clips.indexWhere((c) => c.id == clip.id);
    if (idx == -1) return;
    clips[idx] = clip;
    await saveClips(clips);
  }

  /// Deletes a clip: removes its video file, thumbnail, and index entry.
  Future<void> deleteClip(VideoClip clip) async {
    // Delete video file
    final videoFile = File(clip.filePath);
    if (videoFile.existsSync()) await videoFile.delete();

    // Delete thumbnail
    final thumbFile = File(clip.thumbnailPath);
    if (thumbFile.existsSync()) await thumbFile.delete();

    // Remove from index
    final clips = await loadClips();
    clips.removeWhere((c) => c.id == clip.id);
    await saveClips(clips);
  }

  /// Deletes all clips and clears the index (used by Settings → "Clear all").
  Future<void> clearAll() async {
    final clips = await loadClips();
    for (final clip in clips) {
      final videoFile = File(clip.filePath);
      if (videoFile.existsSync()) await videoFile.delete();
      final thumbFile = File(clip.thumbnailPath);
      if (thumbFile.existsSync()) await thumbFile.delete();
    }
    await saveClips([]);
  }

  /// Deletes a temporary file if it exists (e.g. pre-buffer temp file).
  Future<void> deleteTempFile(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}
