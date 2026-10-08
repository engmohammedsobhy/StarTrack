import 'package:itiproject/core/services/persona_label_service.dart';

class KnowledgeEntity {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? wikipediaUrl;
  final List<String> labels;

  double get displayAspectRatio =>
      (title.hashCode % 3 == 0)
          ? 0.7
          : (title.hashCode % 2 == 0)
              ? 0.75
              : 0.8;

  /// Returns explicit labels or intelligently derived persona labels
  List<String> get effectiveLabels =>
      labels.isNotEmpty ? labels : PersonaLabelService.getLabelsForPersona(title, description);

  KnowledgeEntity({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.wikipediaUrl,
    this.labels = const [],
  });

  factory KnowledgeEntity.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] as List<dynamic>?;
    return KnowledgeEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      wikipediaUrl: json['wikipediaUrl'] as String?,
      labels: rawLabels?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'wikipediaUrl': wikipediaUrl,
      'labels': labels,
    };
  }
}
