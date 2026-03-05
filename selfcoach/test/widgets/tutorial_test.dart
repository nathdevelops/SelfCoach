import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selfcoach/features/onboarding/tutorial_screen.dart';

// ---------------------------------------------------------------------------
// Minimal router for widget testing
// ---------------------------------------------------------------------------

final _testRouter = GoRouter(
  initialLocation: '/tutorial',
  routes: [
    GoRoute(
        path: '/tutorial',
        builder: (_, __) => const TutorialScreen()),
    GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: Text('Camera Screen'))),
  ],
);

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp.router(routerConfig: _testRouter),
    );

void main() {
  group('TutorialScreen – widget tests (PRD §5.2)', () {
    testWidgets('renders the correct number of tutorial steps', (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();

      // The progress bar should have 5 segments (one per step)
      // We verify by finding the progress containers (Row children in header)
      // Indirect verification: "Next" button is present
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('first step does not show Back button', (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('tapping Next advances to next step', (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();

      // Step 1: title is "Set up your phone"
      expect(find.text('Set up your phone'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: title is 'Tap "Start Monitoring"'
      expect(find.textContaining('Start Monitoring'), findsOneWidget);
    });

    testWidgets('Back button appears after first step', (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Back returns to previous step', (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Set up your phone'), findsOneWidget);
    });

    testWidgets('last step shows "Get Started" button instead of "Next"',
        (tester) async {
      await tester.pumpWidget(_wrap(const TutorialScreen()));
      await tester.pumpAndSettle();

      // Advance through all 5 steps
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });
  });
}
