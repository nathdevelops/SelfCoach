/// All user-configurable thresholds for the motion detection pipeline (PRD §2.3).
class AppSettings {
  /// 0.0–1.0. Higher = more sensitive (lower velocity needed to trigger).
  final double motionSensitivity;

  /// Seconds of video to include before the trigger. Default 1.5 s.
  final double preTriggerBufferSec;

  /// Seconds of video to continue recording after motion ceases. Default 1.5 s.
  final double postTriggerBufferSec;

  /// Minimum valid clip length in seconds. Clips shorter than this are discarded.
  final int minClipDurationSec;

  /// Maximum clip length in seconds. Recording is force-stopped at this limit.
  final int maxClipDurationSec;

  /// Seconds velocity must stay below thresholds before motion is considered ended.
  final double motionEndDebounceSec;

  /// Whether to record microphone audio into clips.
  final bool saveAudio;

  const AppSettings({
    this.motionSensitivity = 0.5,
    this.preTriggerBufferSec = 1.5,
    this.postTriggerBufferSec = 1.5,
    this.minClipDurationSec = 2,
    this.maxClipDurationSec = 30,
    this.motionEndDebounceSec = 0.5,
    this.saveAudio = true,
  });

  // ---------------------------------------------------------------------------
  // Derived thresholds (PRD §2.3)
  // Sensitivity 0.0 → hardest to trigger (highest threshold values)
  // Sensitivity 1.0 → easiest to trigger (lowest threshold values)
  // ---------------------------------------------------------------------------

  /// Normalised displacement per second for wrist/ankle relative to shoulder/hip.
  double get limbVelocityThreshold =>
      _scaleThreshold(0.8, motionSensitivity);

  /// Radians per second for shoulder-to-shoulder or hip-to-hip axis rotation.
  double get rotationThreshold =>
      _scaleThreshold(1.5, motionSensitivity);

  /// Radians per second for upper-arm rotation about the shoulder joint.
  double get armRotationThreshold =>
      _scaleThreshold(2.0, motionSensitivity);

  /// Number of consecutive frames that must exceed the threshold before
  /// a trigger fires (reduces false positives).
  int get requiredConsecutiveFrames => 3;

  // threshold(s) = base * 3^(1 - 2*s)
  // At s=0.0 → base * 3.0  (very insensitive)
  // At s=0.5 → base * 1.0  (default)
  // At s=1.0 → base * 0.33 (very sensitive)
  static double _scaleThreshold(double base, double sensitivity) {
    final exponent = 1.0 - 2.0 * sensitivity;
    return base * _pow3(exponent);
  }

  static double _pow3(double exponent) {
    // 3^x using natural log: e^(x * ln3)
    const ln3 = 1.0986122886681098;
    return _exp(exponent * ln3);
  }

  // Simple exponential (dart:math not imported here to stay model-pure)
  static double _exp(double x) {
    // Taylor series: good enough for |x| < 2
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 15; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  AppSettings copyWith({
    double? motionSensitivity,
    double? preTriggerBufferSec,
    double? postTriggerBufferSec,
    int? minClipDurationSec,
    int? maxClipDurationSec,
    double? motionEndDebounceSec,
    bool? saveAudio,
  }) {
    return AppSettings(
      motionSensitivity: motionSensitivity ?? this.motionSensitivity,
      preTriggerBufferSec: preTriggerBufferSec ?? this.preTriggerBufferSec,
      postTriggerBufferSec: postTriggerBufferSec ?? this.postTriggerBufferSec,
      minClipDurationSec: minClipDurationSec ?? this.minClipDurationSec,
      maxClipDurationSec: maxClipDurationSec ?? this.maxClipDurationSec,
      motionEndDebounceSec: motionEndDebounceSec ?? this.motionEndDebounceSec,
      saveAudio: saveAudio ?? this.saveAudio,
    );
  }

  Map<String, dynamic> toJson() => {
        'motionSensitivity': motionSensitivity,
        'preTriggerBufferSec': preTriggerBufferSec,
        'postTriggerBufferSec': postTriggerBufferSec,
        'minClipDurationSec': minClipDurationSec,
        'maxClipDurationSec': maxClipDurationSec,
        'motionEndDebounceSec': motionEndDebounceSec,
        'saveAudio': saveAudio,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      motionSensitivity:
          (json['motionSensitivity'] as num?)?.toDouble() ?? 0.5,
      preTriggerBufferSec:
          (json['preTriggerBufferSec'] as num?)?.toDouble() ?? 1.5,
      postTriggerBufferSec:
          (json['postTriggerBufferSec'] as num?)?.toDouble() ?? 1.5,
      minClipDurationSec: (json['minClipDurationSec'] as int?) ?? 2,
      maxClipDurationSec: (json['maxClipDurationSec'] as int?) ?? 30,
      motionEndDebounceSec:
          (json['motionEndDebounceSec'] as num?)?.toDouble() ?? 0.5,
      saveAudio: (json['saveAudio'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettings &&
          other.motionSensitivity == motionSensitivity &&
          other.preTriggerBufferSec == preTriggerBufferSec &&
          other.postTriggerBufferSec == postTriggerBufferSec &&
          other.minClipDurationSec == minClipDurationSec &&
          other.maxClipDurationSec == maxClipDurationSec &&
          other.motionEndDebounceSec == motionEndDebounceSec &&
          other.saveAudio == saveAudio);

  @override
  int get hashCode => Object.hash(
        motionSensitivity,
        preTriggerBufferSec,
        postTriggerBufferSec,
        minClipDurationSec,
        maxClipDurationSec,
        motionEndDebounceSec,
        saveAudio,
      );
}
