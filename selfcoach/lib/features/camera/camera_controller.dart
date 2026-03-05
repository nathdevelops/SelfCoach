import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Wraps the Flutter `camera` plugin to provide a single front-facing camera
/// controller for SelfCoach (PRD §2.6).
///
/// Lifecycle:
/// 1. Call [initialize] once to set up the [CameraController].
/// 2. Access [controller] for the live preview widget.
/// 3. Use [startImageStream] / [stopImageStream] to feed pose detection.
/// 4. Use [startVideoRecording] / [stopVideoRecording] for clip capture.
/// 5. Call [dispose] when done (e.g. when the camera screen is destroyed).
class CameraControllerService {
  CameraController? _controller;
  CameraDescription? _frontCamera;

  CameraController? get controller => _controller;

  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  bool get isRecording =>
      _controller != null && _controller!.value.isRecordingVideo;

  bool get isStreamingImages =>
      _controller != null && _controller!.value.isStreamingImages;

  /// Finds the front camera and initialises the [CameraController].
  ///
  /// Must be called before any other method. Safe to call again after [dispose].
  Future<void> initialize({bool enableAudio = true}) async {
    final cameras = await availableCameras();
    _frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _frontCamera!,
      ResolutionPreset.high,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.nv21, // best for MLKit on Android
    );

    await _controller!.initialize();

    // Lock to portrait (PRD §2.6)
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
  }

  /// Starts the image stream and calls [onFrame] for each camera image.
  ///
  /// Frames are throttled to approximately [targetFps] (default 15) to
  /// conserve battery (PRD §2.3).
  Future<void> startImageStream({
    required void Function(CameraImage) onFrame,
    int targetFps = 15,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    final intervalMs = (1000 / targetFps).round();
    DateTime? lastFrameTime;

    await _controller!.startImageStream((image) {
      final now = DateTime.now();
      if (lastFrameTime != null &&
          now.difference(lastFrameTime!).inMilliseconds < intervalMs) {
        return; // skip frame to maintain target fps
      }
      lastFrameTime = now;
      onFrame(image);
    });
  }

  /// Stops the image stream.
  Future<void> stopImageStream() async {
    if (_controller == null) return;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  /// Starts recording a video clip to [outputPath].
  Future<void> startVideoRecording(String outputPath) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;

    // Image stream must be stopped before video recording can start.
    await stopImageStream();
    await _controller!.startVideoRecording();
  }

  /// Stops video recording and returns the file path to the recorded clip.
  Future<String?> stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return null;
    }
    final file = await _controller!.stopVideoRecording();
    return file.path;
  }

  CameraDescription? get frontCamera => _frontCamera;

  /// Releases the underlying [CameraController].
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

