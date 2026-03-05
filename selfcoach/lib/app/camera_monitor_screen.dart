import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../features/camera/camera_preview_widget.dart';
import '../features/motion_detection/motion_state.dart';
import '../shared/permissions/permission_handler_service.dart';
import 'providers.dart';
import 'router.dart';

/// Screen 1: Home / Camera Monitor (PRD §4, Screen 1).
///
/// Full-screen camera preview with:
/// - Semi-transparent top bar: logo + settings icon
/// - Semi-transparent bottom bar: Start/Stop button, Gallery shortcut, badge
/// - Centre overlay when athlete is absent
class CameraMonitorScreen extends ConsumerStatefulWidget {
  const CameraMonitorScreen({super.key});

  @override
  ConsumerState<CameraMonitorScreen> createState() =>
      _CameraMonitorScreenState();
}

class _CameraMonitorScreenState extends ConsumerState<CameraMonitorScreen>
    with WidgetsBindingObserver {
  bool _permissionChecked = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause when backgrounded, resume on foreground (PRD §7 decision 2)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseMonitoring();
    } else if (state == AppLifecycleState.resumed) {
      _resumeMonitoring();
    }
  }

  Future<void> _checkFirstLaunch() async {
    final isFirst = await ref.read(firstLaunchProvider.future);
    if (isFirst && mounted) {
      context.go(AppRoutes.tutorial);
    }
  }

  // ---------------------------------------------------------------------------
  // Monitoring lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _startMonitoring() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    // 1. Check / request permissions
    final permService = ref.read(permissionServiceProvider);
    final result = await permService.requestAll();

    if (result != PermissionResult.granted) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PermissionDeniedScreen(result: result),
          ),
        );
      }
      setState(() => _isStarting = false);
      return;
    }

    // 2. Initialise camera
    final cameraService = ref.read(cameraServiceProvider);
    final settings = ref.read(settingsProvider);
    await cameraService.initialize(enableAudio: settings.saveAudio);

    if (!mounted) return;

    // 3. Update state → athleteAbsent (monitoring begins)
    ref.read(motionStateProvider.notifier).state = MotionState.athleteAbsent;

    // 4. Keep screen on
    await WakelockPlus.enable();

    // 5. Start frame stream → drives motion detection
    final motionDetector = ref.read(motionDetectorProvider);
    final frameBuffer = ref.read(frameBufferProvider);
    final clipRecorder = ref.read(clipRecorderProvider);

    await cameraService.startImageStream(onFrame: (image) async {
      final description = cameraService.frontCamera;
      if (description == null) return;

      frameBuffer.addFrame(image, DateTime.now());

      final currentState = ref.read(motionStateProvider);
      if (currentState == MotionState.idle) return;

      final newState =
          await motionDetector.processFrame(image, description);

      if (!mounted) return;

      final prevState = ref.read(motionStateProvider);

      switch (newState) {
        case MotionState.athleteAbsent:
          if (prevState == MotionState.recording) {
            // Athlete left mid-recording — finalise clip immediately
            await clipRecorder.finalise();
          } else if (prevState == MotionState.monitoring) {
            await clipRecorder.discardPreBuffer();
          }
          ref.read(motionStateProvider.notifier).state =
              MotionState.athleteAbsent;

        case MotionState.monitoring:
          if (prevState == MotionState.athleteAbsent) {
            // Athlete just entered frame — start pre-buffer
            await clipRecorder.startPreBuffer();
          } else if (prevState == MotionState.recording) {
            // Check if motion has ceased long enough
            if (motionDetector.hasMotionCeased()) {
              clipRecorder.schedulePostBuffer();
            } else {
              clipRecorder.cancelPostBuffer();
            }
          }
          ref.read(motionStateProvider.notifier).state = MotionState.monitoring;

        case MotionState.recording:
          if (prevState != MotionState.recording) {
            // Trigger just fired
            await clipRecorder.onTrigger();
          }
          ref.read(motionStateProvider.notifier).state = MotionState.recording;

        case MotionState.idle:
          break;
      }
    });

    setState(() => _isStarting = false);
    _permissionChecked = true;
  }

  Future<void> _stopMonitoring() async {
    final cameraService = ref.read(cameraServiceProvider);
    final clipRecorder = ref.read(clipRecorderProvider);
    final motionDetector = ref.read(motionDetectorProvider);

    await clipRecorder.stop();
    await cameraService.stopImageStream();
    await cameraService.dispose();
    motionDetector.reset();

    ref.read(motionStateProvider.notifier).state = MotionState.idle;
    await WakelockPlus.disable();
  }

  void _pauseMonitoring() {
    final state = ref.read(motionStateProvider);
    if (state != MotionState.idle) {
      _stopMonitoring();
    }
  }

  void _resumeMonitoring() {
    // Do not auto-restart; user must tap Start again.
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final motionState = ref.watch(motionStateProvider);
    final isActive = motionState.isActiveSession;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview
          if (isActive) const CameraPreviewWidget(),

          // Idle placeholder
          if (!isActive)
            const Center(
              child: Icon(Icons.videocam_off,
                  size: 80, color: Colors.white24),
            ),

          // Top bar — semi-transparent (PRD §2.6)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              onSettingsTap: () => context.push(AppRoutes.settings),
            ),
          ),

          // Athlete absent overlay (PRD §2.3)
          if (motionState == MotionState.athleteAbsent)
            const _StepIntoFrameOverlay(),

          // Bottom bar — semi-transparent (PRD §2.6)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(
              motionState: motionState,
              isStarting: _isStarting,
              onStart: _startMonitoring,
              onStop: _stopMonitoring,
              onGalleryTap: () => context.push(AppRoutes.gallery),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final VoidCallback onSettingsTap;

  const _TopBar({required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // App logo / name
              const Text(
                'SelfCoach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: onSettingsTap,
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final MotionState motionState;
  final bool isStarting;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onGalleryTap;

  const _BottomBar({
    required this.motionState,
    required this.isStarting,
    required this.onStart,
    required this.onStop,
    required this.onGalleryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = motionState.isActiveSession;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Gallery shortcut
              IconButton(
                icon: const Icon(Icons.photo_library,
                    color: Colors.white, size: 28),
                onPressed: onGalleryTap,
                tooltip: 'Gallery',
              ),
              const Spacer(),

              // Start / Stop button
              _StartStopButton(
                isActive: isActive,
                isLoading: isStarting,
                onStart: onStart,
                onStop: onStop,
              ),

              const Spacer(),

              // Motion status badge
              _MotionBadge(state: motionState),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StartStopButton({
    required this.isActive,
    required this.isLoading,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: isActive ? onStop : onStart,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.red : Colors.white,
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.red : Colors.white).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.stop : Icons.play_arrow,
          color: isActive ? Colors.white : Colors.black,
          size: 36,
        ),
      ),
    );
  }
}

class _MotionBadge extends StatefulWidget {
  final MotionState state;

  const _MotionBadge({required this.state});

  @override
  State<_MotionBadge> createState() => _MotionBadgeState();
}

class _MotionBadgeState extends State<_MotionBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.state) {
      case MotionState.idle:
        return const SizedBox(width: 56);

      case MotionState.athleteAbsent:
        return FadeTransition(
          opacity: _pulse,
          child: _badge(
            label: 'Step into frame',
            color: Colors.amber,
            icon: Icons.person_search,
          ),
        );

      case MotionState.monitoring:
        return FadeTransition(
          opacity: _pulse,
          child: _badge(
            label: 'Monitoring...',
            color: Colors.green,
            icon: Icons.radio_button_checked,
          ),
        );

      case MotionState.recording:
        return _badge(
          label: '● REC',
          color: Colors.red,
          icon: null,
          bold: true,
        );
    }
  }

  Widget _badge({
    required String label,
    required Color color,
    IconData? icon,
    bool bold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIntoFrameOverlay extends StatelessWidget {
  const _StepIntoFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person_search, color: Colors.amber, size: 48),
            SizedBox(height: 8),
            Text(
              'Step into frame',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Stand so your full body is visible',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
