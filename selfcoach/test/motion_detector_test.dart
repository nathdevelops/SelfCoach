import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:selfcoach/features/motion_detection/motion_state.dart';
import 'package:selfcoach/features/settings/app_settings.dart';

// ---------------------------------------------------------------------------
// Helpers – build mock PoseLandmarks
// ---------------------------------------------------------------------------

PoseLandmark _lm(
  PoseLandmarkType type, {
  double x = 0,
  double y = 0,
  double z = 0,
  double likelihood = 0.95,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: z,
    likelihood: likelihood,
  );
}

/// All required full-body landmarks placed at sensible default positions.
List<PoseLandmark> _fullBodyLandmarks({
  double wristX = 50,
  double wristY = 50,
}) {
  return [
    _lm(PoseLandmarkType.nose, x: 100, y: 20),
    _lm(PoseLandmarkType.leftShoulder, x: 80, y: 80),
    _lm(PoseLandmarkType.rightShoulder, x: 120, y: 80),
    _lm(PoseLandmarkType.leftElbow, x: 70, y: 130),
    _lm(PoseLandmarkType.rightElbow, x: 130, y: 130),
    _lm(PoseLandmarkType.leftWrist, x: wristX, y: wristY),
    _lm(PoseLandmarkType.rightWrist, x: 200 - wristX, y: wristY),
    _lm(PoseLandmarkType.leftHip, x: 85, y: 180),
    _lm(PoseLandmarkType.rightHip, x: 115, y: 180),
    _lm(PoseLandmarkType.leftKnee, x: 83, y: 250),
    _lm(PoseLandmarkType.rightKnee, x: 117, y: 250),
    _lm(PoseLandmarkType.leftAnkle, x: 82, y: 320),
    _lm(PoseLandmarkType.rightAnkle, x: 118, y: 320),
  ];
}

// ---------------------------------------------------------------------------
// Tests for threshold derivation and motion state logic (unit, no MLKit calls)
// ---------------------------------------------------------------------------

/// We test the *logic* of the motion detector in isolation by testing the
/// AppSettings threshold derivation and the MotionState enum directly,
/// since calling MotionDetector.processFrame() requires a real CameraImage
/// and live MLKit session (device-only).
///
/// The MotionDetector integration is covered in the integration tests.
void main() {
  group('AppSettings – threshold scaling', () {
    test('at default sensitivity (0.5) returns base values', () {
      const s = AppSettings(motionSensitivity: 0.5);
      // At sensitivity=0.5 the scale factor is 3^0 = 1.0
      expect(s.limbVelocityThreshold, closeTo(0.8, 0.05));
      expect(s.rotationThreshold, closeTo(1.5, 0.1));
      expect(s.armRotationThreshold, closeTo(2.0, 0.1));
    });

    test('at max sensitivity (1.0) thresholds are lower (easier to trigger)',
        () {
      const low = AppSettings(motionSensitivity: 1.0);
      const def = AppSettings(motionSensitivity: 0.5);
      expect(low.limbVelocityThreshold,
          lessThan(def.limbVelocityThreshold));
      expect(low.rotationThreshold, lessThan(def.rotationThreshold));
      expect(low.armRotationThreshold,
          lessThan(def.armRotationThreshold));
    });

    test('at min sensitivity (0.0) thresholds are higher (harder to trigger)',
        () {
      const high = AppSettings(motionSensitivity: 0.0);
      const def = AppSettings(motionSensitivity: 0.5);
      expect(high.limbVelocityThreshold,
          greaterThan(def.limbVelocityThreshold));
      expect(high.rotationThreshold, greaterThan(def.rotationThreshold));
      expect(high.armRotationThreshold,
          greaterThan(def.armRotationThreshold));
    });

    test('thresholds are always positive', () {
      for (final s in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final settings = AppSettings(motionSensitivity: s);
        expect(settings.limbVelocityThreshold, greaterThan(0));
        expect(settings.rotationThreshold, greaterThan(0));
        expect(settings.armRotationThreshold, greaterThan(0));
      }
    });
  });

  group('MotionState', () {
    test('idle is not an active session', () {
      expect(MotionState.idle.isActiveSession, isFalse);
    });

    test('athleteAbsent IS an active session', () {
      expect(MotionState.athleteAbsent.isActiveSession, isTrue);
    });

    test('monitoring IS an active session', () {
      expect(MotionState.monitoring.isActiveSession, isTrue);
    });

    test('recording IS an active session', () {
      expect(MotionState.recording.isActiveSession, isTrue);
    });
  });

  group('AppSettings – serialization', () {
    test('round-trips through JSON without data loss', () {
      const original = AppSettings(
        motionSensitivity: 0.7,
        preTriggerBufferSec: 2.0,
        postTriggerBufferSec: 1.0,
        minClipDurationSec: 3,
        maxClipDurationSec: 45,
        motionEndDebounceSec: 0.8,
        saveAudio: false,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('fromJson handles missing keys with defaults', () {
      final s = AppSettings.fromJson({});
      expect(s, equals(const AppSettings()));
    });
  });

  group('AppSettings – requiredConsecutiveFrames', () {
    test('returns 3 (prevents single-frame false positives)', () {
      expect(const AppSettings().requiredConsecutiveFrames, equals(3));
    });
  });
}
