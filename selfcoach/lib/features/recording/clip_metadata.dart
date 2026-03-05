import 'package:uuid/uuid.dart';

/// Data model for a recorded video clip (PRD §2.5).
class VideoClip {
  final String id;
  final String filePath;
  final String thumbnailPath;
  final DateTime createdAt;
  final int durationMs;
  String name;
  List<String> tags;

  VideoClip({
    required this.id,
    required this.filePath,
    required this.thumbnailPath,
    required this.createdAt,
    required this.durationMs,
    required this.name,
    required this.tags,
  });

  /// Factory constructor with auto-generated ID and default name.
  factory VideoClip.create({
    required String filePath,
    required String thumbnailPath,
    required DateTime createdAt,
    required int durationMs,
  }) {
    final now = createdAt;
    final defaultName =
        'Clip — ${_twoDigit(now.month)}/${_twoDigit(now.day)} '
        '${_twoDigit(now.hour)}:${_twoDigit(now.minute)}';
    return VideoClip(
      id: const Uuid().v4(),
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      createdAt: createdAt,
      durationMs: durationMs,
      name: defaultName,
      tags: [],
    );
  }

  VideoClip copyWith({
    String? name,
    List<String>? tags,
    String? thumbnailPath,
    int? durationMs,
  }) {
    return VideoClip(
      id: id,
      filePath: filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt,
      durationMs: durationMs ?? this.durationMs,
      name: name ?? this.name,
      tags: tags ?? List<String>.from(this.tags),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': durationMs,
        'name': name,
        'tags': tags,
      };

  factory VideoClip.fromJson(Map<String, dynamic> json) {
    return VideoClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationMs: json['durationMs'] as int,
      name: json['name'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VideoClip && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

String _twoDigit(int n) => n.toString().padLeft(2, '0');
