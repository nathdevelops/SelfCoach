import 'dart:io';

import 'package:flutter/material.dart';

import '../recording/clip_metadata.dart';

/// A single item in the clip gallery grid/list (PRD §4, Screen 2).
///
/// Displays thumbnail, clip name, duration, timestamp, and tag pills.
/// Tap → playback; long-press → options menu.
class ClipTileWidget extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onTap;
  final VoidCallback onRenameTag;
  final VoidCallback onDelete;

  const ClipTileWidget({
    super.key,
    required this.clip,
    required this.onTap,
    required this.onRenameTag,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumbnail(path: clip.thumbnailPath),
                  // Duration badge
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black75,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(clip.durationMs),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(clip.createdAt),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                  if (clip.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: clip.tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF00C853)
                                          .withOpacity(0.4)),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                      color: Color(0xFF00C853),
                                      fontSize: 10),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Rename / Tag',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onRenameTag();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int ms) {
    final secs = (ms / 1000).round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  static String _formatDate(DateTime dt) {
    return '${_two(dt.month)}/${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _Thumbnail extends StatelessWidget {
  final String path;

  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF2C2C2C),
      child: Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 36),
      ),
    );
  }
}
