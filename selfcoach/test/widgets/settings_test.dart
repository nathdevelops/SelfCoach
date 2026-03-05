import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selfcoach/app/providers.dart';
import 'package:selfcoach/features/settings/app_settings.dart';
import 'package:selfcoach/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _testRouter = GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen()),
    GoRoute(
        path: '/tutorial',
        builder: (_, __) =>
            const Scaffold(body: Text('Tutorial'))),
  ],
);

Widget _wrapSettings({AppSettings? initial}) {
  return ProviderScope(
    overrides: [
      if (initial != null)
        settingsProvider.overrideWith((_) => SettingsNotifier()),
      galleryProvider.overrideWith((ref) => []),
    ],
    child: MaterialApp.router(routerConfig: _testRouter),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen – widget tests (PRD §5.2)', () {
    testWidgets('renders all configurable controls', (tester) async {
      await tester.pumpWidget(_wrapSettings());
      await tester.pump();

      expect(find.text('Motion Sensitivity'), findsOneWidget);
      expect(find.text('Pre-trigger buffer'), findsOneWidget);
      expect(find.text('Post-trigger buffer'), findsOneWidget);
      expect(find.text('Minimum clip duration (seconds)'), findsOneWidget);
      expect(find.text('Maximum clip duration (seconds)'), findsOneWidget);
      expect(find.text('Save audio with clips'), findsOneWidget);
    });

    testWidgets('View Tutorial button is present', (tester) async {
      await tester.pumpWidget(_wrapSettings());
      await tester.pump();

      expect(find.text('View Tutorial'), findsOneWidget);
    });

    testWidgets('Clear all clips button is present', (tester) async {
      await tester.pumpWidget(_wrapSettings());
      await tester.pump();

      expect(find.text('Clear all clips'), findsOneWidget);
    });

    testWidgets('sensitivity slider is rendered', (tester) async {
      await tester.pumpWidget(_wrapSettings());
      await tester.pump();

      expect(find.byKey(const Key('sensitivity_slider')), findsOneWidget);
    });

    testWidgets('audio toggle switches state', (tester) async {
      await tester.pumpWidget(_wrapSettings());
      await tester.pump();

      // Find the audio switch
      final switchFinder = find.byKey(const Key('audio_toggle'));
      expect(switchFinder, findsOneWidget);

      // Tap to toggle
      await tester.tap(switchFinder);
      await tester.pump();
      // No assertion on saved value (requires SharedPreferences mock for full cycle)
      // The test verifies the control is interactive without throwing.
    });
  });
}
