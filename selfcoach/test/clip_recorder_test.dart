import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:selfcoach/features/camera/camera_controller.dart';
import 'package:selfcoach/features/recording/clip_metadata.dart';
import 'package:selfcoach/features/recording/clip_recorder.dart';
import 'package:selfcoach/features/settings/app_settings.dart';
import 'package:selfcoach/shared/storage/local_storage_service.dart';

@GenerateMocks([CameraControllerService, LocalStorageService])
import 'clip_recorder_test.mocks.dart';

void main() {
  late MockCameraControllerService mockCamera;
  late MockLocalStorageService mockStorage;
  late List<VideoClip> savedClips;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clip_recorder_test_');
    mockCamera = MockCameraControllerService();
    mockStorage = MockLocalStorageService();
    savedClips = [];

    // Default stub behaviour
    when(mockCamera.isRecording).thenReturn(false);
    when(mockCamera.isStreamingImages).thenReturn(false);
    when(mockStorage.newTempPath(any)).thenAnswer(
        (i) async => '${tempDir.path}/tmp_${i.positionalArguments[0]}.mp4');
    when(mockStorage.newClipPath()).thenAnswer(
        (_) async => '${tempDir.path}/clip_final.mp4');
    when(mockStorage.newThumbnailPath()).thenAnswer(
        (_) async => '${tempDir.path}/thumb.jpg');
    when(mockStorage.addClip(any)).thenAnswer((_) async {
      savedClips.add(_.positionalArguments[0] as VideoClip);
    });
    when(mockStorage.deleteTempFile(any)).thenAnswer((_) async {});
    when(mockCamera.startVideoRecording(any)).thenAnswer((_) async {});
    when(mockCamera.stopVideoRecording()).thenAnswer((_) async => '');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ClipRecorder _makeRecorder({
    AppSettings? settings,
    void Function(VideoClip)? onSaved,
  }) {
    return ClipRecorder(
      camera: mockCamera,
      settings: settings ?? const AppSettings(),
      storage: mockStorage,
      onClipSaved: onSaved ?? (c) => savedClips.add(c),
    );
  }

  group('ClipRecorder – pre-buffer', () {
    test('startPreBuffer calls startVideoRecording', () async {
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      verify(mockCamera.startVideoRecording(any)).called(1);
    });

    test('discardPreBuffer stops recording and deletes temp file', () async {
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      await recorder.discardPreBuffer();
      verify(mockCamera.stopVideoRecording()).called(1);
      verify(mockStorage.deleteTempFile(any)).called(greaterThanOrEqualTo(1));
    });

    test('calling startPreBuffer twice does not create a second recording',
        () async {
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      await recorder.startPreBuffer(); // second call is a no-op
      verify(mockCamera.startVideoRecording(any)).called(1);
    });
  });

  group('ClipRecorder – trigger', () {
    test('onTrigger stops pre-buffer and starts main recording', () async {
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      await recorder.onTrigger();
      // stopVideoRecording called once (for pre-buffer), then start again (main)
      verify(mockCamera.stopVideoRecording()).called(1);
      verify(mockCamera.startVideoRecording(any)).called(2);
      expect(recorder.isRecording, isTrue);
    });

    test('double-calling onTrigger is a no-op on second call', () async {
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      await recorder.onTrigger();
      await recorder.onTrigger(); // second trigger ignored
      // startVideoRecording: once for pre-buffer, once for main
      verify(mockCamera.startVideoRecording(any)).called(2);
    });
  });

  group('ClipRecorder – post-buffer scheduling', () {
    test('schedulePostBuffer registers a timer that calls finalise', () async {
      final settings = const AppSettings(
        postTriggerBufferSec: 0.1, // short for test speed
        minClipDurationSec: 0,
      );
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder(settings: settings);
      await recorder.startPreBuffer();
      await recorder.onTrigger();
      recorder.schedulePostBuffer();
      // Wait for post-buffer timer to fire
      await Future.delayed(const Duration(milliseconds: 300));
      expect(recorder.isRecording, isFalse);
    });

    test('cancelPostBuffer prevents auto-finalise', () async {
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder(
        settings: const AppSettings(postTriggerBufferSec: 0.1),
      );
      await recorder.startPreBuffer();
      await recorder.onTrigger();
      recorder.schedulePostBuffer();
      recorder.cancelPostBuffer(); // immediately cancel
      await Future.delayed(const Duration(milliseconds: 200));
      expect(recorder.isRecording, isTrue); // still recording
      // clean up
      await recorder.stop();
    });
  });

  group('ClipRecorder – stop', () {
    test('stop() resets isRecording to false', () async {
      when(mockCamera.isRecording).thenReturn(true);
      final recorder = _makeRecorder();
      await recorder.startPreBuffer();
      await recorder.onTrigger();
      await recorder.stop();
      expect(recorder.isRecording, isFalse);
    });

    test('stop() when idle is a no-op', () async {
      final recorder = _makeRecorder();
      await recorder.stop(); // should not throw
      expect(recorder.isRecording, isFalse);
    });
  });

  group('VideoClip metadata', () {
    test('Metadata written correctly – name, tags, timestamps (PRD §5.1)', () {
      final now = DateTime(2024, 6, 15, 9, 30);
      final clip = VideoClip.create(
        filePath: '/data/clips/clip_1.mp4',
        thumbnailPath: '/data/clips/thumb_1.jpg',
        createdAt: now,
        durationMs: 5000,
      );

      expect(clip.name, contains('06/15'));
      expect(clip.tags, isEmpty);
      expect(clip.durationMs, equals(5000));
      expect(clip.filePath, equals('/data/clips/clip_1.mp4'));
    });

    test('VideoClip copyWith preserves unchanged fields', () {
      final original = VideoClip.create(
        filePath: '/path.mp4',
        thumbnailPath: '/thumb.jpg',
        createdAt: DateTime.now(),
        durationMs: 3000,
      );
      final updated = original.copyWith(
        name: 'My Squat',
        tags: ['squat', 'legs'],
      );
      expect(updated.id, equals(original.id));
      expect(updated.name, equals('My Squat'));
      expect(updated.tags, equals(['squat', 'legs']));
      expect(updated.durationMs, equals(3000));
    });

    test('VideoClip JSON round-trip preserves all fields', () {
      final original = VideoClip.create(
        filePath: '/clips/vid.mp4',
        thumbnailPath: '/clips/thumb.jpg',
        createdAt: DateTime(2024, 3, 1, 14, 22),
        durationMs: 7200,
      );
      original.name = 'Back squat';
      original.tags = ['squat', 'weightlifting'];
      final restored = VideoClip.fromJson(original.toJson());

      expect(restored.id, equals(original.id));
      expect(restored.filePath, equals(original.filePath));
      expect(restored.name, equals(original.name));
      expect(restored.tags, equals(original.tags));
      expect(restored.durationMs, equals(original.durationMs));
    });
  });
}
