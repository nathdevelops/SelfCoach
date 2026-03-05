import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../recording/clip_metadata.dart';

/// Bottom sheet for renaming a clip and editing its tags (PRD §4, Screen 2 & 3).
///
/// Used from:
/// - Gallery long-press → "Rename/Tag"
/// - Playback screen → Edit button
class ClipRenameTagSheet extends ConsumerStatefulWidget {
  final VideoClip clip;

  const ClipRenameTagSheet({super.key, required this.clip});

  @override
  ConsumerState<ClipRenameTagSheet> createState() =>
      _ClipRenameTagSheetState();
}

class _ClipRenameTagSheetState extends ConsumerState<ClipRenameTagSheet> {
  late TextEditingController _nameController;
  late TextEditingController _tagInputController;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clip.name);
    _tagInputController = TextEditingController();
    _tags = List<String>.from(widget.clip.tags);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _save() async {
    final updated = widget.clip.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.clip.name
          : _nameController.text.trim(),
      tags: _tags,
    );
    await ref.read(galleryProvider.notifier).updateClip(updated);
    if (mounted) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rename & Tag',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              key: const Key('rename_name_field'),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Clip name',
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Color(0xFF00C853), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tag input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    key: const Key('rename_tag_field'),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Add a tag',
                      labelStyle: const TextStyle(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Color(0xFF00C853), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: Color(0xFF00C853), size: 32),
                  onPressed: () => _addTag(_tagInputController.text),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tags
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _tags
                    .map((tag) => Chip(
                          label: Text(tag,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.white12,
                          deleteIcon: const Icon(Icons.close,
                              size: 16, color: Colors.white60),
                          onDeleted: () => _removeTag(tag),
                        ))
                    .toList(),
              ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('rename_save_button'),
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [ClipRenameTagSheet] as a modal bottom sheet.
Future<VideoClip?> showRenameTagSheet(
    BuildContext context, VideoClip clip) async {
  return showModalBottomSheet<VideoClip>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ClipRenameTagSheet(clip: clip),
  );
}
