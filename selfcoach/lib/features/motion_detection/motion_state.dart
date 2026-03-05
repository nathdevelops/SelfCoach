/// Represents the current operational state of the motion-detection pipeline.
///
/// State transitions (PRD §2.3, §2.6):
///   idle           → user has not started monitoring
///   athleteAbsent  → monitoring active but required landmarks not detected
///   monitoring     → all required landmarks detected; awaiting trigger
///   recording      → motion trigger fired; actively recording a clip
enum MotionState {
  idle,
  athleteAbsent,
  monitoring,
  recording;

  bool get isActiveSession =>
      this == MotionState.athleteAbsent ||
      this == MotionState.monitoring ||
      this == MotionState.recording;
}
