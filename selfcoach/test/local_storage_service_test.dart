import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:selfcoach/features/recording/clip_metadata.dart';
import 'package:selfcoach/shared/storage/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Mock path_provider so tests can run without a real device filesystem.
// ---------------------------------------------------------------------------

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;

  _FakePathProvider(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

VideoClip _makeClip({
  String id = 'id-1',
  String name = 'Test Clip',
  List<String> tags = const [],
}) {
  return VideoClip(
    id: id,
    filePath: '/fake/clips/clip_$id.mp4',
    thumbnailPath: '/fake/clips/thumb_$id.jpg',
    createdAt: DateTime(2024, 1, 1, 10, 0),
    durationMs: 5000,
    name: name,
    tags: List<String>.from(tags),
  );
}

void main() {
  late Directory tempDir;
  late LocalStorageService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_storage_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    service = LocalStorageService();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('LocalStorageService – load / save', () {
    test('Empty gallery state handled gracefully (PRD §5.1)', () async {
      final clips = await service.loadClips();
      expect(clips, isEmpty);
    });

    test('Clip index persists across app restarts (PRD §5.1)', () async {
      final clip = _makeClip();
      await service.addClip(clip);

      // Simulate restart by creating a fresh service instance
      final service2 = LocalStorageService();
      final loaded = await service2.loadClips();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals(clip.id));
    });

    test('saveClips then loadClips returns same list', () async {
      final clips = [_makeClip(id: 'a'), _makeClip(id: 'b')];
      await service.saveClips(clips);
      final loaded = await service.loadClips();
      expect(loaded.map((c) => c.id), equals(['a', 'b']));
    });
  });

  group('LocalStorageService – addClip', () {
    test('adds clip to front of index (newest first)', () async {
      final c1 = _makeClip(id: '1', name: 'First');
      final c2 = _makeClip(id: '2', name: 'Second');
      await service.addClip(c1);
      await service.addClip(c2);
      final loaded = await service.loadClips();
      expect(loaded.first.id, equals('2')); // newest first
    });
  });

  group('LocalStorageService – updateClip', () {
    test('Clip rename updates persisted metadata (PRD §5.1)', () async {
      final original = _makeClip(id: 'x', name: 'Old Name');
      await service.addClip(original);
      final updated = original.copyWith(name: 'New Name');
      await service.updateClip(updated);

      final loaded = await service.loadClips();
      expect(loaded.first.name, equals('New Name'));
    });

    test('Clip tag add/remove updates persisted metadata (PRD §5.1)',
        () async {
      final original = _makeClip(id: 'y');
      await service.addClip(original);

      // Add tags
      final withTags =
          original.copyWith(tags: ['squat', 'legs']);
      await service.updateClip(withTags);
      var loaded = await service.loadClips();
      expect(loaded.first.tags, containsAll(['squat', 'legs']));

      // Remove a tag
      final removedTag = withTags.copyWith(tags: ['squat']);
      await service.updateClip(removedTag);
      loaded = await service.loadClips();
      expect(loaded.first.tags, equals(['squat']));
    });

    test('updating non-existent clip is a no-op', () async {
      final clip = _makeClip(id: 'missing');
      await service.updateClip(clip); // should not throw
    });
  });

  group('LocalStorageService – deleteClip', () {
    test('Clip deletion removes from index (PRD §5.1)', () async {
      final clip = _makeClip(id: 'del-1');
      await service.addClip(clip);
      await service.deleteClip(clip);
      final loaded = await service.loadClips();
      expect(loaded, isEmpty);
    });

    test('delete handles missing file gracefully', () async {
      // clip with a path that doesn't exist on disk
      final clip = _makeClip(id: 'no-file');
      await service.addClip(clip);
      // Should not throw even though the files don't exist
      await service.deleteClip(clip);
      final loaded = await service.loadClips();
      expect(loaded, isEmpty);
    });
  });

  group('LocalStorageService – clearAll', () {
    test('removes all clips from index', () async {
      await service.addClip(_makeClip(id: 'a'));
      await service.addClip(_makeClip(id: 'b'));
      await service.clearAll();
      final loaded = await service.loadClips();
      expect(loaded, isEmpty);
    });
  });

  group('LocalStorageService – path helpers', () {
    test('newClipPath returns a path ending in .mp4', () async {
      final path = await service.newClipPath();
      expect(path, endsWith('.mp4'));
    });

    test('newThumbnailPath returns a path ending in .jpg', () async {
      final path = await service.newThumbnailPath();
      expect(path, endsWith('.jpg'));
    });

    test('newTempPath returns unique paths for multiple calls', () async {
      final p1 = await service.newTempPath('prebuf');
      await Future.delayed(const Duration(milliseconds: 2));
      final p2 = await service.newTempPath('prebuf');
      expect(p1, isNot(equals(p2)));
    });
  });
}
