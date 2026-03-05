import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

import '../camera/camera_controller.dart';
import '../settings/app_settings.dart';
import 'clip_metadata.dart';
import '../../shared/storage/local_storage_service.dart';

/// Encapsulates the state machine for recording a single clip with
/// pre-trigger and post-trigger buffers (PRD §2.3).
///
/// Pre-trigger approach:
/// - When [startPreBuffer] is called (athlete enters frame) a "standby"
///   recording begins into a temp file.  This acts as the pre-buffer.
/// - When a motion trigger fires, [onTrigger] is called:
///     1. The standby recording is stopped and the file is kept.
///     2. A new main recording begins immediately.
/// - When motion ceases + [settings.postTriggerBufferSec] elapses, [finalise]
///   is called:
///     1. The main recording is stopped.
///     2. FFmpeg trims the pre-buffer file to the last [preTriggerBufferSec]
///        and concatenates it with the main recording to produce the final clip.
///     3. The final clip is saved and metadata is persisted.
///     4. A new standby recording begins for the next trigger.
class ClipRecorder {
  final CameraControllerService camera;
  final AppSettings settings;
  final LocalStorageService storage;

  /// Called when a clip is successfully finalised.
  final void Function(VideoClip)? onClipSaved;

  // Internal state
  String? _preBufferPath;
  DateTime? _preBufferStartTime;

  String? _mainRecordingPath;
  DateTime? _triggerTime;

  Timer? _postBufferTimer;
  Timer? _maxDurationTimer;

  bool _isRecording = false;
  bool _isFinalising = false;

  ClipRecorder({
    required this.camera,
    required this.settings,
    required this.storage,
    this.onClipSaved,
  });

  bool get isRecording => _isRecording;

  // ---------------------------------------------------------------------------
  // Pre-buffer management
  // ---------------------------------------------------------------------------

  /// Starts (or restarts) the standby pre-buffer recording.
  /// Call this when the athlete enters the frame.
  Future<void> startPreBuffer() async {
    if (_preBufferPath != null) return; // already running
    _preBufferPath = await storage.newTempPath('prebuf');
    _preBufferStartTime = DateTime.now();
    await camera.startVideoRecording(_preBufferPath!);
  }

  /// Stops and discards the pre-buffer recording without saving a clip.
  /// Call when the athlete leaves the frame while NOT in recording state.
  Future<void> discardPreBuffer() async {
    if (_preBufferPath == null) return;
    final path = _preBufferPath!;
    _preBufferPath = null;
    _preBufferStartTime = null;
    if (camera.isRecording) {
      await camera.stopVideoRecording(); // discard
    }
    await storage.deleteTempFile(path);
  }

  // ---------------------------------------------------------------------------
  // Trigger / recording
  // ---------------------------------------------------------------------------

  /// Called when the motion trigger fires.
  ///
  /// Stops the standby recording to lock in the pre-buffer, then immediately
  /// starts the main clip recording.
  Future<void> onTrigger() async {
    if (_isRecording || _isFinalising) return;
    _isRecording = true;
    _triggerTime = DateTime.now();

    // Stop the standby recording (pre-buffer now locked in _preBufferPath)
    if (camera.isRecording) {
      await camera.stopVideoRecording();
    }

    // Start main recording
    _mainRecordingPath = await storage.newTempPath('main');
    await camera.startVideoRecording(_mainRecordingPath!);

    // Safety: force-stop at MAX_CLIP_DURATION
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(
      Duration(seconds: settings.maxClipDurationSec),
      () => finalise(),
    );
  }

  /// Called every frame after [onTrigger] when motion appears to have ceased.
  ///
  /// Starts the post-trigger buffer timer (only once). When it elapses, the
  /// clip is finalised.
  void schedulePostBuffer() {
    if (_postBufferTimer != null || !_isRecording) return;
    _postBufferTimer = Timer(
      Duration(milliseconds: (settings.postTriggerBufferSec * 1000).round()),
      () => finalise(),
    );
  }

  /// Cancels the post-buffer timer (motion resumed before it elapsed).
  void cancelPostBuffer() {
    _postBufferTimer?.cancel();
    _postBufferTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Finalisation
  // ---------------------------------------------------------------------------

  /// Stops recording and assembles the final clip file.
  ///
  /// If the assembled clip is shorter than [AppSettings.minClipDurationSec]
  /// it is discarded instead of saved.
  Future<void> finalise() async {
    if (!_isRecording || _isFinalising) return;
    _isFinalising = true;
    _postBufferTimer?.cancel();
    _postBufferTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    // Stop main recording
    if (camera.isRecording) {
      await camera.stopVideoRecording();
    }

    final mainPath = _mainRecordingPath;
    final prePath = _preBufferPath;
    final triggerTime = _triggerTime!;

    // Clear state before async work
    _mainRecordingPath = null;
    _preBufferPath = null;
    _preBufferStartTime = null;
    _triggerTime = null;
    _isRecording = false;
    _isFinalising = false;

    if (mainPath == null) return;

    // Assemble final clip
    await _assembleClip(
      preBufferPath: prePath,
      mainPath: mainPath,
      triggerTime: triggerTime,
    );

    // Re-start pre-buffer for the next trigger
    await startPreBuffer();
  }

  /// Force-stops everything (e.g. when monitoring is stopped by the user).
  Future<void> stop() async {
    _postBufferTimer?.cancel();
    _maxDurationTimer?.cancel();
    _postBufferTimer = null;
    _maxDurationTimer = null;
    _isRecording = false;
    _isFinalising = false;

    if (camera.isRecording) {
      await camera.stopVideoRecording();
    }

    if (_mainRecordingPath != null) {
      await storage.deleteTempFile(_mainRecordingPath!);
      _mainRecordingPath = null;
    }
    if (_preBufferPath != null) {
      await storage.deleteTempFile(_preBufferPath!);
      _preBufferPath = null;
    }
    _preBufferStartTime = null;
    _triggerTime = null;
  }

  // ---------------------------------------------------------------------------
  // Private: clip assembly via FFmpeg
  // ---------------------------------------------------------------------------

  Future<void> _assembleClip({
    required String? preBufferPath,
    required String mainPath,
    required DateTime triggerTime,
  }) async {
    final outputPath = await storage.newClipPath();

    // Determine how much of the pre-buffer to keep
    bool hasPre = false;
    if (preBufferPath != null && File(preBufferPath).existsSync()) {
      hasPre = true;
    }

    String finalPath;

    if (hasPre) {
      // Trim pre-buffer to the last preTriggerBufferSec seconds using FFmpeg
      final trimmedPrePath =
          outputPath.replaceAll('.mp4', '_pretrim.mp4');

      final trimCmd =
          '-sseof -${settings.preTriggerBufferSec} -i "$preBufferPath" '
          '-c copy "$trimmedPrePath"';
      final trimSession = await FFmpegKit.execute(trimCmd);
      final trimRc = await trimSession.getReturnCode();

      if (ReturnCode.isSuccess(trimRc) &&
          File(trimmedPrePath).existsSync()) {
        // Concatenate trimmed pre-buffer + main recording
        final concatListPath = outputPath.replaceAll('.mp4', '_list.txt');
        final concatContent =
            "file '${trimmedPrePath.replaceAll("'", "\\'")}'\n"
            "file '${mainPath.replaceAll("'", "\\'")}'\n";
        await File(concatListPath).writeAsString(concatContent);

        final concatCmd =
            '-f concat -safe 0 -i "$concatListPath" -c copy "$outputPath"';
        final concatSession = await FFmpegKit.execute(concatCmd);
        final concatRc = await concatSession.getReturnCode();

        if (ReturnCode.isSuccess(concatRc)) {
          finalPath = outputPath;
        } else {
          // Fallback: use main recording only
          finalPath = mainPath;
        }

        // Cleanup temporaries
        await storage.deleteTempFile(trimmedPrePath);
        await storage.deleteTempFile(concatListPath);
      } else {
        // Trim failed — use main recording only
        finalPath = mainPath;
      }

      await storage.deleteTempFile(preBufferPath!);
    } else {
      // No pre-buffer — rename main recording as output
      await File(mainPath).rename(outputPath);
      finalPath = outputPath;
    }

    // Measure duration
    final durationMs =
        await _probeDurationMs(finalPath) ?? _estimateDurationMs(triggerTime);

    // Discard clips shorter than the minimum (PRD §2.3)
    if (durationMs < settings.minClipDurationSec * 1000) {
      await storage.deleteTempFile(finalPath);
      if (mainPath != finalPath) await storage.deleteTempFile(mainPath);
      return;
    }

    // Generate thumbnail
    final thumbPath = await storage.newThumbnailPath();
    await VideoThumbnail.thumbnailFile(
      video: finalPath,
      thumbnailPath: thumbPath,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );

    // Build metadata and persist
    final clip = VideoClip.create(
      filePath: finalPath,
      thumbnailPath: thumbPath,
      createdAt: triggerTime,
      durationMs: durationMs,
    );
    await storage.addClip(clip);
    onClipSaved?.call(clip);

    // Cleanup the main temp file if it was moved/replaced
    if (mainPath != finalPath && File(mainPath).existsSync()) {
      await storage.deleteTempFile(mainPath);
    }
  }

  Future<int?> _probeDurationMs(String path) async {
    try {
      final session = await FFmpegKit.execute(
          '-v quiet -print_format json -show_streams "$path"');
      final output = await session.getOutput();
      if (output == null) return null;
      // Quick parse: look for "duration":"X.XX"
      final match = RegExp(r'"duration"\s*:\s*"([\d.]+)"').firstMatch(output);
      if (match == null) return null;
      final secs = double.tryParse(match.group(1)!);
      return secs != null ? (secs * 1000).round() : null;
    } catch (_) {
      return null;
    }
  }

  int _estimateDurationMs(DateTime start) =>
      DateTime.now().difference(start).inMilliseconds;
}
