import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../settings/app_settings.dart';
import 'motion_state.dart';

/// Landmark indices considered "required" for a full-body detection.
///
/// All of these must be present and confident before triggering is enabled
/// (PRD §2.3 – "Athlete-in-Frame Requirement").
const List<PoseLandmarkType> _requiredLandmarks = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
];

/// Minimum MLKit landmark confidence to count as "detected".
const double _minLandmarkConfidence = 0.5;

/// Encapsulates the per-frame velocity metrics that the detector computes.
class MotionVelocities {
  final double maxLimbVelocity;
  final double maxShoulderRotation;
  final double maxHipRotation;
  final double maxArmRotation;

  const MotionVelocities({
    required this.maxLimbVelocity,
    required this.maxShoulderRotation,
    required this.maxHipRotation,
    required this.maxArmRotation,
  });

  static const zero = MotionVelocities(
    maxLimbVelocity: 0,
    maxShoulderRotation: 0,
    maxHipRotation: 0,
    maxArmRotation: 0,
  );
}

/// Implements the velocity-based pose landmark motion-detection pipeline
/// described in PRD §2.3.
///
/// Usage:
/// ```dart
/// final detector = MotionDetector(settings: settings);
/// final state = await detector.processFrame(cameraImage, cameraDescription);
/// ```
///
/// The detector is **stateful**: it retains the previous frame's landmark
/// positions to compute per-frame velocities. Call [reset] when monitoring
/// stops.
class MotionDetector {
  final AppSettings settings;

  late final PoseDetector _poseDetector;

  /// Previous frame landmarks, keyed by [PoseLandmarkType].
  Map<PoseLandmarkType, PoseLandmark>? _prevLandmarks;
  DateTime? _prevTimestamp;

  /// How many consecutive frames have exceeded the trigger threshold.
  int _consecutiveTriggeredFrames = 0;

  /// How many consecutive frames have been below threshold since a trigger fired.
  int _consecutiveCalmedFrames = 0;

  bool _initialized = false;

  MotionDetector({required this.settings}) {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Processes a single camera frame and returns the resulting [MotionState].
  ///
  /// [imageWidth] and [imageHeight] are used to normalise landmark coordinates.
  Future<MotionState> processFrame(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    final inputImage = _toInputImage(image, cameraDescription);
    if (inputImage == null) return MotionState.athleteAbsent;

    final poses = await _poseDetector.processImage(inputImage);

    if (poses.isEmpty) {
      _resetVelocityTracking();
      return MotionState.athleteAbsent;
    }

    final pose = poses.first;
    final landmarkMap = {for (final l in pose.landmarks) l.type: l};

    // 1. Full-body check
    if (!_hasRequiredLandmarks(landmarkMap)) {
      _resetVelocityTracking();
      return MotionState.athleteAbsent;
    }

    // 2. First frame — just store landmarks, can't compute velocity yet
    if (_prevLandmarks == null) {
      _prevLandmarks = landmarkMap;
      _prevTimestamp = DateTime.now();
      return MotionState.monitoring;
    }

    final now = DateTime.now();
    final dt = now.difference(_prevTimestamp!).inMicroseconds / 1e6; // seconds

    // Avoid division by zero on very fast consecutive calls
    if (dt < 0.001) {
      return MotionState.monitoring;
    }

    // 3. Compute velocity metrics
    final velocities = _computeVelocities(
      landmarkMap,
      _prevLandmarks!,
      image.width.toDouble(),
      image.height.toDouble(),
      dt,
    );

    // 4. Update landmark history
    _prevLandmarks = landmarkMap;
    _prevTimestamp = now;

    // 5. Evaluate against thresholds
    final triggered = _exceedsThresholds(velocities);

    if (triggered) {
      _consecutiveTriggeredFrames++;
      _consecutiveCalmedFrames = 0;
      if (_consecutiveTriggeredFrames >= settings.requiredConsecutiveFrames) {
        return MotionState.recording;
      }
    } else {
      _consecutiveCalmedFrames++;
      _consecutiveTriggeredFrames = 0;
    }

    return MotionState.monitoring;
  }

  /// Returns true when motion has ceased long enough to end the current clip.
  ///
  /// Should be called every frame during [MotionState.recording].
  bool hasMotionCeased() {
    final requiredCalmedFrames =
        (settings.motionEndDebounceSec * 15).round(); // at 15 fps
    return _consecutiveCalmedFrames >= requiredCalmedFrames;
  }

  /// Resets all velocity-tracking state. Call this when:
  /// - Monitoring stops
  /// - A clip is finalised
  /// - The athlete leaves the frame
  void reset() {
    _resetVelocityTracking();
  }

  /// Releases the MLKit [PoseDetector]. Call once when the service is no longer
  /// needed.
  Future<void> dispose() async {
    await _poseDetector.close();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Landmark helpers
  // ---------------------------------------------------------------------------

  bool _hasRequiredLandmarks(Map<PoseLandmarkType, PoseLandmark> map) {
    for (final type in _requiredLandmarks) {
      final lm = map[type];
      if (lm == null || lm.likelihood < _minLandmarkConfidence) return false;
    }
    return true;
  }

  void _resetVelocityTracking() {
    _prevLandmarks = null;
    _prevTimestamp = null;
    _consecutiveTriggeredFrames = 0;
    _consecutiveCalmedFrames = 0;
  }

  // ---------------------------------------------------------------------------
  // Velocity computation (PRD §2.3)
  // ---------------------------------------------------------------------------

  MotionVelocities _computeVelocities(
    Map<PoseLandmarkType, PoseLandmark> curr,
    Map<PoseLandmarkType, PoseLandmark> prev,
    double imgW,
    double imgH,
    double dt,
  ) {
    // 1. Limb velocity: wrist/ankle relative to shoulder/hip
    final limbVelocities = <double>[
      _relativeLimbVelocity(
          curr[PoseLandmarkType.leftWrist],
          curr[PoseLandmarkType.leftShoulder],
          prev[PoseLandmarkType.leftWrist],
          prev[PoseLandmarkType.leftShoulder],
          imgW,
          imgH,
          dt),
      _relativeLimbVelocity(
          curr[PoseLandmarkType.rightWrist],
          curr[PoseLandmarkType.rightShoulder],
          prev[PoseLandmarkType.rightWrist],
          prev[PoseLandmarkType.rightShoulder],
          imgW,
          imgH,
          dt),
      _relativeLimbVelocity(
          curr[PoseLandmarkType.leftAnkle],
          curr[PoseLandmarkType.leftHip],
          prev[PoseLandmarkType.leftAnkle],
          prev[PoseLandmarkType.leftHip],
          imgW,
          imgH,
          dt),
      _relativeLimbVelocity(
          curr[PoseLandmarkType.rightAnkle],
          curr[PoseLandmarkType.rightHip],
          prev[PoseLandmarkType.rightAnkle],
          prev[PoseLandmarkType.rightHip],
          imgW,
          imgH,
          dt),
    ];

    // 2. Shoulder rotation
    final shoulderRotation = _axisRotationVelocity(
      curr[PoseLandmarkType.leftShoulder],
      curr[PoseLandmarkType.rightShoulder],
      prev[PoseLandmarkType.leftShoulder],
      prev[PoseLandmarkType.rightShoulder],
      imgW,
      imgH,
      dt,
    );

    // 3. Hip rotation
    final hipRotation = _axisRotationVelocity(
      curr[PoseLandmarkType.leftHip],
      curr[PoseLandmarkType.rightHip],
      prev[PoseLandmarkType.leftHip],
      prev[PoseLandmarkType.rightHip],
      imgW,
      imgH,
      dt,
    );

    // 4. Arm rotation (both arms, take max)
    final leftArmRot = _armRotationVelocity(
      curr[PoseLandmarkType.leftShoulder],
      curr[PoseLandmarkType.leftElbow],
      prev[PoseLandmarkType.leftShoulder],
      prev[PoseLandmarkType.leftElbow],
      imgW,
      imgH,
      dt,
    );
    final rightArmRot = _armRotationVelocity(
      curr[PoseLandmarkType.rightShoulder],
      curr[PoseLandmarkType.rightElbow],
      prev[PoseLandmarkType.rightShoulder],
      prev[PoseLandmarkType.rightElbow],
      imgW,
      imgH,
      dt,
    );

    return MotionVelocities(
      maxLimbVelocity:
          limbVelocities.fold(0.0, (max, v) => v > max ? v : max),
      maxShoulderRotation: shoulderRotation,
      maxHipRotation: hipRotation,
      maxArmRotation: math.max(leftArmRot, rightArmRot),
    );
  }

  /// Velocity of [distal] relative to [proximal] (normalised by image dims).
  double _relativeLimbVelocity(
    PoseLandmark? currDistal,
    PoseLandmark? currProximal,
    PoseLandmark? prevDistal,
    PoseLandmark? prevProximal,
    double imgW,
    double imgH,
    double dt,
  ) {
    if (currDistal == null ||
        currProximal == null ||
        prevDistal == null ||
        prevProximal == null) return 0;

    final currRelX = (currDistal.x - currProximal.x) / imgW;
    final currRelY = (currDistal.y - currProximal.y) / imgH;
    final prevRelX = (prevDistal.x - prevProximal.x) / imgW;
    final prevRelY = (prevDistal.y - prevProximal.y) / imgH;
    final dx = currRelX - prevRelX;
    final dy = currRelY - prevRelY;
    return math.sqrt(dx * dx + dy * dy) / dt;
  }

  /// Angular velocity of the axis defined by [left]–[right] in radians/second.
  double _axisRotationVelocity(
    PoseLandmark? currLeft,
    PoseLandmark? currRight,
    PoseLandmark? prevLeft,
    PoseLandmark? prevRight,
    double imgW,
    double imgH,
    double dt,
  ) {
    if (currLeft == null ||
        currRight == null ||
        prevLeft == null ||
        prevRight == null) return 0;

    final currAngle =
        math.atan2(currRight.y / imgH - currLeft.y / imgH,
            currRight.x / imgW - currLeft.x / imgW);
    final prevAngle =
        math.atan2(prevRight.y / imgH - prevLeft.y / imgH,
            prevRight.x / imgW - prevLeft.x / imgW);

    var diff = (currAngle - prevAngle).abs();
    if (diff > math.pi) diff = 2 * math.pi - diff;
    return diff / dt;
  }

  /// Angular velocity of the upper arm (shoulder → elbow) in radians/second.
  double _armRotationVelocity(
    PoseLandmark? currShoulder,
    PoseLandmark? currElbow,
    PoseLandmark? prevShoulder,
    PoseLandmark? prevElbow,
    double imgW,
    double imgH,
    double dt,
  ) {
    if (currShoulder == null ||
        currElbow == null ||
        prevShoulder == null ||
        prevElbow == null) return 0;

    final currAngle = math.atan2(
      (currElbow.y - currShoulder.y) / imgH,
      (currElbow.x - currShoulder.x) / imgW,
    );
    final prevAngle = math.atan2(
      (prevElbow.y - prevShoulder.y) / imgH,
      (prevElbow.x - prevShoulder.x) / imgW,
    );

    var diff = (currAngle - prevAngle).abs();
    if (diff > math.pi) diff = 2 * math.pi - diff;
    return diff / dt;
  }

  // ---------------------------------------------------------------------------
  // Threshold evaluation
  // ---------------------------------------------------------------------------

  bool _exceedsThresholds(MotionVelocities v) {
    return v.maxLimbVelocity > settings.limbVelocityThreshold ||
        v.maxShoulderRotation > settings.rotationThreshold ||
        v.maxHipRotation > settings.rotationThreshold ||
        v.maxArmRotation > settings.armRotationThreshold;
  }

  // ---------------------------------------------------------------------------
  // InputImage conversion
  // ---------------------------------------------------------------------------

  static const Map<DeviceOrientation, int> _orientationAngles = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _toInputImage(
      CameraImage image, CameraDescription cameraDesc) {
    // Determine rotation
    final sensorOrientation = cameraDesc.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // Front camera: compensate both sensor and device orientation
      var compensated =
          (sensorOrientation + 0) % 360; // device orientation = 0 for portrait
      if (cameraDesc.lensDirection == CameraLensDirection.front) {
        compensated = (sensorOrientation + 0) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensated);
    }
    rotation ??= InputImageRotation.rotation0deg;

    // Determine format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Build InputImage from the first plane (suitable for NV21/BGRA8888)
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
