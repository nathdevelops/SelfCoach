import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/camera/camera_controller.dart';
import '../features/motion_detection/frame_buffer.dart';
import '../features/motion_detection/motion_detector.dart';
import '../features/motion_detection/motion_state.dart';
import '../features/recording/clip_metadata.dart';
import '../features/recording/clip_recorder.dart';
import '../features/settings/app_settings.dart';
import '../shared/permissions/permission_handler_service.dart';
import '../shared/storage/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _prefsKey = 'selfcoach_settings';

  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        state = AppSettings.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        state = const AppSettings();
      }
    }
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(),
);

// ---------------------------------------------------------------------------
// Gallery (clip list)
// ---------------------------------------------------------------------------

class GalleryNotifier extends StateNotifier<List<VideoClip>> {
  final LocalStorageService _storage;

  GalleryNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.loadClips();
  }

  Future<void> addClip(VideoClip clip) async {
    state = [clip, ...state];
  }

  Future<void> updateClip(VideoClip clip) async {
    await _storage.updateClip(clip);
    state = [
      for (final c in state)
        if (c.id == clip.id) clip else c
    ];
  }

  Future<void> deleteClip(VideoClip clip) async {
    await _storage.deleteClip(clip);
    state = state.where((c) => c.id != clip.id).toList();
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    state = [];
  }

  Future<void> reload() async {
    state = await _storage.loadClips();
  }
}

final localStorageProvider = Provider((_) => LocalStorageService());

final galleryProvider =
    StateNotifierProvider<GalleryNotifier, List<VideoClip>>(
  (ref) => GalleryNotifier(ref.read(localStorageProvider)),
);

// ---------------------------------------------------------------------------
// Motion state
// ---------------------------------------------------------------------------

final motionStateProvider = StateProvider<MotionState>((_) => MotionState.idle);

// ---------------------------------------------------------------------------
// Camera controller service
// ---------------------------------------------------------------------------

final cameraServiceProvider = Provider((_) => CameraControllerService());

// ---------------------------------------------------------------------------
// Frame buffer
// ---------------------------------------------------------------------------

final frameBufferProvider = Provider((_) => FrameBuffer(maxFrames: 90));

// ---------------------------------------------------------------------------
// Motion detector
// ---------------------------------------------------------------------------

final motionDetectorProvider = Provider<MotionDetector>((ref) {
  final settings = ref.watch(settingsProvider);
  return MotionDetector(settings: settings);
});

// ---------------------------------------------------------------------------
// Clip recorder
// ---------------------------------------------------------------------------

final clipRecorderProvider = Provider<ClipRecorder>((ref) {
  return ClipRecorder(
    camera: ref.read(cameraServiceProvider),
    settings: ref.read(settingsProvider),
    storage: ref.read(localStorageProvider),
    onClipSaved: (clip) {
      ref.read(galleryProvider.notifier).addClip(clip);
    },
  );
});

// ---------------------------------------------------------------------------
// Permissions
// ---------------------------------------------------------------------------

final permissionServiceProvider = Provider((_) => PermissionHandlerService());

// ---------------------------------------------------------------------------
// First-launch flag
// ---------------------------------------------------------------------------

final firstLaunchProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('selfcoach_first_launch') ?? true;
});

Future<void> markTutorialComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('selfcoach_first_launch', false);
}
