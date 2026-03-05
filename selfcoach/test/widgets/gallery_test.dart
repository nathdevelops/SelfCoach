import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selfcoach/app/providers.dart';
import 'package:selfcoach/features/gallery/clip_gallery_screen.dart';
import 'package:selfcoach/features/recording/clip_metadata.dart';

final _testRouter = GoRouter(
  initialLocation: '/gallery',
  routes: [
    GoRoute(
        path: '/gallery',
        builder: (_, __) => const ClipGalleryScreen()),
    GoRoute(
        path: '/playback',
        builder: (context, state) {
          final clip = state.extra as VideoClip;
          return Scaffold(body: Text('Playback: ${clip.name}'));
        }),
  ],
);

Widget _wrapWithClips(List<VideoClip> clips) {
  return ProviderScope(
    overrides: [
      galleryProvider.overrideWith((ref) => clips),
    ],
    child: MaterialApp.router(routerConfig: _testRouter),
  );
}

VideoClip _clip({
  String id = '1',
  String name = 'Test Clip',
  List<String> tags = const [],
  int durationMs = 4000,
}) =>
    VideoClip(
      id: id,
      filePath: '/fake/clip_$id.mp4',
      thumbnailPath: '/fake/thumb_$id.jpg',
      createdAt: DateTime(2024, 6, 15, 9, 30),
      durationMs: durationMs,
      name: name,
      tags: List<String>.from(tags),
    );

void main() {
  group('ClipGalleryScreen – widget tests (PRD §5.2)', () {
    testWidgets('renders empty state when no clips exist (PRD §5.2)',
        (tester) async {
      await tester.pumpWidget(_wrapWithClips([]));
      await tester.pump();

      expect(find.text('No clips yet'), findsOneWidget);
    });

    testWidgets('renders clip tile with name, duration, timestamp (PRD §5.2)',
        (tester) async {
      final clip =
          _clip(name: 'Front squat', durationMs: 5000, tags: ['squat']);
      await tester.pumpWidget(_wrapWithClips([clip]));
      await tester.pump();

      expect(find.text('Front squat'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget); // duration
      expect(find.text('squat'), findsOneWidget); // tag pill
    });

    testWidgets('renders multiple clips in grid', (tester) async {
      final clips = [
        _clip(id: '1', name: 'Clip One'),
        _clip(id: '2', name: 'Clip Two'),
        _clip(id: '3', name: 'Clip Three'),
      ];
      await tester.pumpWidget(_wrapWithClips(clips));
      await tester.pump();

      expect(find.text('Clip One'), findsOneWidget);
      expect(find.text('Clip Two'), findsOneWidget);
      expect(find.text('Clip Three'), findsOneWidget);
    });

    testWidgets('tapping clip tile navigates to playback', (tester) async {
      final clip = _clip(name: 'Golf Swing');
      await tester.pumpWidget(_wrapWithClips([clip]));
      await tester.pump();

      await tester.tap(find.text('Golf Swing'));
      await tester.pumpAndSettle();

      expect(find.text('Playback: Golf Swing'), findsOneWidget);
    });
  });
}
