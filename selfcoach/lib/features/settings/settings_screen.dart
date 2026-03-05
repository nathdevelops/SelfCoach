import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import 'app_settings.dart';

/// Screen 4: Settings (PRD §4, Screen 4).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local copies of settings for editing; committed on field-change
  late AppSettings _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(settingsProvider);
  }

  Future<void> _commit(AppSettings updated) async {
    setState(() => _local = updated);
    await ref.read(settingsProvider.notifier).update(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Motion Sensitivity
          _SectionHeader('Motion Detection'),
          _SliderTile(
            key: const Key('sensitivity_slider'),
            label: 'Motion Sensitivity',
            subtitle: 'Higher = easier to trigger recording',
            value: _local.motionSensitivity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            displayValue: _local.motionSensitivity.toStringAsFixed(2),
            onChanged: (v) =>
                _commit(_local.copyWith(motionSensitivity: v)),
          ),

          // Pre-trigger buffer
          _SectionHeader('Buffer Durations'),
          _SliderTile(
            key: const Key('pre_buffer_slider'),
            label: 'Pre-trigger buffer',
            subtitle: 'Seconds of video kept before the motion trigger',
            value: _local.preTriggerBufferSec,
            min: 0.5,
            max: 5.0,
            divisions: 18,
            displayValue: '${_local.preTriggerBufferSec.toStringAsFixed(1)}s',
            onChanged: (v) =>
                _commit(_local.copyWith(preTriggerBufferSec: v)),
          ),

          // Post-trigger buffer
          _SliderTile(
            key: const Key('post_buffer_slider'),
            label: 'Post-trigger buffer',
            subtitle: 'Seconds to continue recording after motion stops',
            value: _local.postTriggerBufferSec,
            min: 0.5,
            max: 5.0,
            divisions: 18,
            displayValue:
                '${_local.postTriggerBufferSec.toStringAsFixed(1)}s',
            onChanged: (v) =>
                _commit(_local.copyWith(postTriggerBufferSec: v)),
          ),

          // Min / Max clip duration
          _SectionHeader('Clip Duration'),
          _IntInputTile(
            key: const Key('min_clip_input'),
            label: 'Minimum clip duration (seconds)',
            value: _local.minClipDurationSec,
            min: 1,
            max: 10,
            onChanged: (v) =>
                _commit(_local.copyWith(minClipDurationSec: v)),
          ),
          _IntInputTile(
            key: const Key('max_clip_input'),
            label: 'Maximum clip duration (seconds)',
            value: _local.maxClipDurationSec,
            min: 5,
            max: 120,
            onChanged: (v) =>
                _commit(_local.copyWith(maxClipDurationSec: v)),
          ),

          // Audio
          _SectionHeader('Audio'),
          SwitchListTile(
            key: const Key('audio_toggle'),
            title: const Text('Save audio with clips',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Records microphone audio into each clip',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: _local.saveAudio,
            activeColor: const Color(0xFF00C853),
            onChanged: (v) => _commit(_local.copyWith(saveAudio: v)),
          ),

          // Actions
          _SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: Colors.white70),
            title: const Text('View Tutorial',
                style: TextStyle(color: Colors.white)),
            onTap: () => context.push(AppRoutes.tutorial),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.red),
            title: const Text('Clear all clips',
                style: TextStyle(color: Colors.red)),
            onTap: () => _confirmClearAll(context),
          ),

          const SizedBox(height: 32),
          // Version info
          const Center(
            child: Text(
              'SelfCoach v1.0.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Clear all clips?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'All saved clips and their files will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(galleryProvider.notifier).clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All clips deleted')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF00C853),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF00C853),
          inactiveColor: Colors.white12,
          onChanged: onChanged,
        ),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }
}

class _IntInputTile extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntInputTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_IntInputTile> createState() => _IntInputTileState();
}

class _IntInputTileState extends State<_IntInputTile> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_IntInputTile old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final v = int.tryParse(raw);
    if (v == null) return;
    final clamped = v.clamp(widget.min, widget.max);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text('${widget.min}–${widget.max} seconds',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: SizedBox(
        width: 64,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF00C853),
              fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                  color: Color(0xFF00C853), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onSubmitted: _submit,
        ),
      ),
    );
  }
}
