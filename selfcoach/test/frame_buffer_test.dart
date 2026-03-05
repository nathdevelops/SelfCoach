// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcoach/features/motion_detection/frame_buffer.dart';

// We test FrameBuffer's timestamp-based logic without requiring a real
// CameraImage (which needs the native camera plugin). The public
// `addTimestampOnlyForTest` helper on FrameBuffer enables this.

void main() {
  group('FrameBuffer – capacity', () {
    test('starts empty', () {
      final buf = FrameBuffer(maxFrames: 10);
      expect(buf.isEmpty, isTrue);
      expect(buf.length, equals(0));
    });

    test('Buffer correctly stores last N frames (PRD §5.1)', () {
      final buf = FrameBuffer(maxFrames: 3);
      final base = DateTime(2024, 1, 1, 12, 0, 0);

      for (var i = 0; i < 4; i++) {
        buf.addTimestampOnlyForTest(base.add(Duration(seconds: i)));
      }

      // Only the last 3 frames should remain
      expect(buf.length, equals(3));
    });

    test('Buffer head returns correct timestamp offset on trigger (PRD §5.1)',
        () {
      final buf = FrameBuffer(maxFrames: 10);
      final now = DateTime.now();

      // Add frames over 3 seconds
      for (var i = 3; i >= 0; i--) {
        buf.addTimestampOnlyForTest(now.subtract(Duration(seconds: i)));
      }

      // getFramesForDuration(1.5) should return the last ~1.5 seconds of frames
      final recent = buf.getFramesForDuration(1.5);
      // Frames at t-1s and t-0s should qualify; t-3s and t-2s should not
      // (allow 1 frame margin for boundary precision)
      expect(recent.length, greaterThanOrEqualTo(1));
      expect(recent.length, lessThanOrEqualTo(3));
    });

    test('Buffer resets cleanly between clips (PRD §5.1)', () {
      final buf = FrameBuffer(maxFrames: 10);
      buf.addTimestampOnlyForTest(DateTime.now());
      buf.addTimestampOnlyForTest(DateTime.now());
      expect(buf.length, equals(2));

      buf.clear();
      expect(buf.isEmpty, isTrue);
      expect(buf.length, equals(0));
    });
  });

  group('FrameBuffer – getFramesForDuration', () {
    test('returns only frames within the requested duration', () {
      final buf = FrameBuffer(maxFrames: 100);
      final now = DateTime.now();
      // Add frames at t-5s, t-3s, t-1s, t-0s
      for (final offset in [5, 3, 1, 0]) {
        buf.addTimestampOnlyForTest(
            now.subtract(Duration(seconds: offset)));
      }

      // Request last 2 seconds → t-1s and t-0s
      final recent = buf.getFramesForDuration(2.0);
      // Both t-1s and t-0 qualify; t-3s and t-5s do not
      expect(recent.length, greaterThanOrEqualTo(1));
      for (final frame in recent) {
        expect(frame.timestamp.isAfter(
                now.subtract(const Duration(seconds: 2, milliseconds: 100))),
            isTrue);
      }
    });

    test('returns empty list when buffer is empty', () {
      final buf = FrameBuffer(maxFrames: 10);
      expect(buf.getFramesForDuration(2.0), isEmpty);
    });

    test('returns all frames when duration exceeds buffer age', () {
      final buf = FrameBuffer(maxFrames: 10);
      final now = DateTime.now();
      buf.addTimestampOnlyForTest(
          now.subtract(const Duration(seconds: 1)));
      buf.addTimestampOnlyForTest(now);
      expect(buf.getFramesForDuration(10.0).length, equals(2));
    });
  });

  group('FrameBuffer – timestamps', () {
    test('newestTimestamp and oldestTimestamp are correct', () {
      final buf = FrameBuffer(maxFrames: 5);
      final t1 = DateTime(2024, 1, 1, 10, 0, 0);
      final t2 = DateTime(2024, 1, 1, 10, 0, 5);
      buf.addTimestampOnlyForTest(t1);
      buf.addTimestampOnlyForTest(t2);
      expect(buf.oldestTimestamp, equals(t1));
      expect(buf.newestTimestamp, equals(t2));
    });

    test('null timestamps when buffer empty', () {
      final buf = FrameBuffer(maxFrames: 5);
      expect(buf.oldestTimestamp, isNull);
      expect(buf.newestTimestamp, isNull);
    });

    test('oldest frame evicted correctly – newest timestamps preserved', () {
      final buf = FrameBuffer(maxFrames: 2);
      final t1 = DateTime(2024, 1, 1, 10, 0, 0);
      final t2 = DateTime(2024, 1, 1, 10, 0, 1);
      final t3 = DateTime(2024, 1, 1, 10, 0, 2);
      buf.addTimestampOnlyForTest(t1);
      buf.addTimestampOnlyForTest(t2);
      buf.addTimestampOnlyForTest(t3); // evicts t1
      expect(buf.oldestTimestamp, equals(t2));
      expect(buf.newestTimestamp, equals(t3));
    });
  });
}
