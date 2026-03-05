import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/gallery/clip_gallery_screen.dart';
import '../features/onboarding/tutorial_screen.dart';
import '../features/playback/clip_playback_screen.dart';
import '../features/recording/clip_metadata.dart';
import '../features/settings/settings_screen.dart';
import 'camera_monitor_screen.dart';

/// Named route paths used throughout the app.
class AppRoutes {
  static const tutorial = '/tutorial';
  static const cameraMonitor = '/';
  static const gallery = '/gallery';
  static const playback = '/playback';
  static const settings = '/settings';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.cameraMonitor,
  routes: [
    GoRoute(
      path: AppRoutes.tutorial,
      builder: (_, __) => const TutorialScreen(),
    ),
    GoRoute(
      path: AppRoutes.cameraMonitor,
      builder: (_, __) => const CameraMonitorScreen(),
    ),
    GoRoute(
      path: AppRoutes.gallery,
      builder: (_, __) => const ClipGalleryScreen(),
    ),
    GoRoute(
      path: AppRoutes.playback,
      builder: (context, state) {
        final clip = state.extra as VideoClip;
        return ClipPlaybackScreen(clip: clip);
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
);
