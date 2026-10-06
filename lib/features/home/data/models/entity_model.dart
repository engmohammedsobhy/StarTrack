class KnowledgeEntity {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? wikipediaUrl;

  double get displayAspectRatio =>
      (title.hashCode % 3 == 0)
          ? 0.7
          : (title.hashCode % 2 == 0)
              ? 0.75
              : 0.8;

  KnowledgeEntity({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.wikipediaUrl,
  });

  factory KnowledgeEntity.fromJson(Map<String, dynamic> json) {
    return KnowledgeEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      wikipediaUrl: json['wikipediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'wikipediaUrl': wikipediaUrl,
    };
  }
}
