import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../app/providers.dart';
import '../recording/clip_metadata.dart';
import '../gallery/clip_rename_tag_sheet.dart';

/// Screen 3: Clip Playback (PRD §4, Screen 3).
///
/// Full-screen video player with:
/// - Playback controls (play/pause, seek)
/// - Back button, delete (with confirmation)
/// - Clip name, tags, date, duration
/// - Edit button → rename/tag bottom sheet
class ClipPlaybackScreen extends ConsumerStatefulWidget {
  final VideoClip clip;

  const ClipPlaybackScreen({super.key, required this.clip});

  @override
  ConsumerState<ClipPlaybackScreen> createState() =>
      _ClipPlaybackScreenState();
}

class _ClipPlaybackScreenState extends ConsumerState<ClipPlaybackScreen> {
  late VideoPlayerController _videoController;
  late VideoClip _clip;
  bool _initialized = false;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _clip = widget.clip;
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(_clip.filePath));
    await _videoController.initialize();
    _videoController.addListener(_onVideoUpdate);
    if (mounted) setState(() => _initialized = true);
    await _videoController.play();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoUpdate);
    _videoController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  Future<void> _openRenameTag() async {
    final updated = await showRenameTagSheet(context, _clip);
    if (updated != null && mounted) {
      setState(() => _clip = updated);
    }
  }

  Future<void> _deleteClip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete clip?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${_clip.name}".',
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
    if (confirmed == true && mounted) {
      await ref.read(galleryProvider.notifier).deleteClip(_clip);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          GestureDetector(
            onTap: _toggleControls,
            child: Center(
              child: _initialized
                  ? AspectRatio(
                      aspectRatio: _videoController.value.aspectRatio,
                      child: VideoPlayer(_videoController),
                    )
                  : const CircularProgressIndicator(color: Colors.white30),
            ),
          ),

          // Controls overlay
          if (_controlsVisible) ...[
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            _clip.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'Edit name/tags',
                          onPressed: _openRenameTag,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete clip',
                          onPressed: _deleteClip,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seek bar
                      if (_initialized)
                        VideoProgressIndicator(
                          _videoController,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF00C853),
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),

                      // Play/Pause + duration
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Play/Pause
                            IconButton(
                              icon: Icon(
                                _videoController.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: () {
                                setState(() {
                                  _videoController.value.isPlaying
                                      ? _videoController.pause()
                                      : _videoController.play();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            // Position / duration
                            if (_initialized) ...[
                              Text(
                                _formatDuration(
                                    _videoController.value.position),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13),
                              ),
                              const Text(' / ',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13)),
                              Text(
                                _formatDuration(
                                    _videoController.value.duration),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13),
                              ),
                            ],
                            const Spacer(),
                            // Replay
                            IconButton(
                              icon: const Icon(Icons.replay,
                                  color: Colors.white70),
                              onPressed: () =>
                                  _videoController.seekTo(Duration.zero),
                            ),
                          ],
                        ),
                      ),

                      // Metadata bar
                      _MetadataBar(clip: _clip),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _MetadataBar extends StatelessWidget {
  final VideoClip clip;

  const _MetadataBar({required this.clip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatDate(clip.createdAt)}  •  ${_formatDuration(clip.durationMs)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (clip.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: clip.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                                  const Color(0xFF00C853).withOpacity(0.4)),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                color: Color(0xFF00C853),
                                fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _formatDuration(int ms) {
    final secs = (ms / 1000).round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
