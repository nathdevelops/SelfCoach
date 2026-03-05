import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcoach/app/providers.dart';
import 'package:selfcoach/features/motion_detection/motion_state.dart';

// ---------------------------------------------------------------------------
// We test the motion-state overlay behaviour by injecting a known
// motionStateProvider value and verifying the correct UI is rendered.
// The full CameraMonitorScreen is used but with the camera preview
// conditionally skipped (camera never initialised in tests).
// ---------------------------------------------------------------------------

import 'package:selfcoach/app/camera_monitor_screen.dart';
import 'package:go_router/go_router.dart';

final _testRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => const CameraMonitorScreen()),
    GoRoute(
        path: '/settings',
        builder: (_, __) =>
            const Scaffold(body: Text('Settings'))),
    GoRoute(
        path: '/gallery',
        builder: (_, __) =>
            const Scaffold(body: Text('Gallery'))),
    GoRoute(
        path: '/tutorial',
        builder: (_, __) =>
            const Scaffold(body: Text('Tutorial'))),
  ],
);

Widget _wrapWithState(MotionState state) {
  return ProviderScope(
    overrides: [
      motionStateProvider.overrideWith((ref) => state),
      // Override firstLaunchProvider so we don't redirect to tutorial
      firstLaunchProvider.overrideWith((_) async => false),
    ],
    child: MaterialApp.router(routerConfig: _testRouter),
  );
}

void main() {
  group('CameraMonitorScreen – motion state overlay (PRD §5.2)', () {
    testWidgets(
        'shows "Step into frame" overlay when in ATHLETE_ABSENT state',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithState(MotionState.athleteAbsent));
      await tester.pump();

      expect(find.text('Step into frame'), findsOneWidget);
    });

    testWidgets(
        'does not show "Step into frame" overlay in MONITORING state',
        (tester) async {
      await tester.pumpWidget(_wrapWithState(MotionState.monitoring));
      await tester.pump();

      expect(find.text('Step into frame'), findsNothing);
    });

    testWidgets(
        'shows "Monitoring..." badge in MONITORING state (PRD §5.2)',
        (tester) async {
      await tester.pumpWidget(_wrapWithState(MotionState.monitoring));
      await tester.pump();

      expect(find.text('Monitoring...'), findsOneWidget);
    });

    testWidgets('shows "● REC" badge in RECORDING state (PRD §5.2)',
        (tester) async {
      await tester.pumpWidget(_wrapWithState(MotionState.recording));
      await tester.pump();

      expect(find.text('● REC'), findsOneWidget);
    });

    testWidgets('shows Start button when idle', (tester) async {
      await tester.pumpWidget(_wrapWithState(MotionState.idle));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows Stop button when monitoring', (tester) async {
      await tester.pumpWidget(_wrapWithState(MotionState.monitoring));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
    });
  });
}
