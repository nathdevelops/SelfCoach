import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../recording/clip_metadata.dart';
import 'clip_rename_tag_sheet.dart';
import 'clip_tile_widget.dart';

/// Screen 2: Gallery — grid of saved clips (PRD §4, Screen 2).
class ClipGalleryScreen extends ConsumerWidget {
  const ClipGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gallery',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        actions: [
          if (clips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all clips',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: clips.isEmpty
          ? const _EmptyGallery()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.56,
              ),
              itemCount: clips.length,
              itemBuilder: (context, index) {
                final clip = clips[index];
                return ClipTileWidget(
                  key: ValueKey(clip.id),
                  clip: clip,
                  onTap: () => context.push(AppRoutes.playback, extra: clip),
                  onRenameTag: () => _openRenameTag(context, clip),
                  onDelete: () => _confirmDelete(context, ref, clip),
                );
              },
            ),
    );
  }

  Future<void> _openRenameTag(BuildContext context, VideoClip clip) async {
    await showRenameTagSheet(context, clip);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, VideoClip clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete clip?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${clip.name}".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(galleryProvider.notifier).deleteClip(clip);
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Clear all clips?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all saved clips.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(galleryProvider.notifier).clearAll();
    }
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.video_library_outlined,
              size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No clips yet',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Start monitoring to auto-capture your first clip.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
