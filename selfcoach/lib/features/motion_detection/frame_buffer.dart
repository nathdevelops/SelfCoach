import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// A single buffered camera frame with its capture timestamp.
///
/// [image] may be null in test contexts (when only timestamp behaviour is
/// being exercised). Production code always provides a non-null image.
class BufferedFrame {
  final CameraImage? image;
  final DateTime timestamp;

  const BufferedFrame({this.image, required this.timestamp});
}

/// Circular buffer of [CameraImage] frames used to feed the pose-detection
/// pipeline and to determine the temporal window before a trigger fires (PRD §2.3).
///
/// The buffer stores at most [maxFrames] items. When full the oldest frame is
/// evicted on every new addition.
class FrameBuffer {
  final int maxFrames;
  final List<BufferedFrame> _frames = [];

  FrameBuffer({this.maxFrames = 60});

  /// Adds a frame to the buffer, evicting the oldest if necessary.
  void addFrame(CameraImage image, DateTime timestamp) {
    _frames.add(BufferedFrame(image: image, timestamp: timestamp));
    if (_frames.length > maxFrames) {
      _frames.removeAt(0);
    }
  }

  /// Returns an unmodifiable view of all buffered frames, oldest first.
  List<BufferedFrame> get frames => List.unmodifiable(_frames);

  /// Returns frames captured within the last [durationSec] seconds.
  List<BufferedFrame> getFramesForDuration(double durationSec) {
    if (_frames.isEmpty) return [];
    final cutoff = DateTime.now()
        .subtract(Duration(milliseconds: (durationSec * 1000).round()));
    return _frames.where((f) => f.timestamp.isAfter(cutoff)).toList();
  }

  /// The timestamp of the oldest frame in the buffer, or null if empty.
  DateTime? get oldestTimestamp =>
      _frames.isEmpty ? null : _frames.first.timestamp;

  /// The timestamp of the most recently added frame, or null if empty.
  DateTime? get newestTimestamp =>
      _frames.isEmpty ? null : _frames.last.timestamp;

  int get length => _frames.length;

  bool get isEmpty => _frames.isEmpty;

  /// Clears all frames (e.g. when a recording clip is finalised and a new
  /// monitoring window begins).
  void clear() => _frames.clear();

  // ---------------------------------------------------------------------------
  // Test-only helper
  // ---------------------------------------------------------------------------

  /// Adds a frame entry with only a [timestamp] and no image payload.
  ///
  /// **For unit tests only.** This allows timestamp-based logic to be exercised
  /// without a real [CameraImage] (which requires the native camera plugin).
  @visibleForTesting
  void addTimestampOnlyForTest(DateTime timestamp) {
    _frames.add(BufferedFrame(timestamp: timestamp));
    if (_frames.length > maxFrames) {
      _frames.removeAt(0);
    }
  }
}
