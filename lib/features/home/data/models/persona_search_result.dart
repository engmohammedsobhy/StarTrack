class PersonaSearchResult {
  final String title;
  final String description;
  final String wikidataId;
  final String? imageUrl;
  final List<String> labels;

  PersonaSearchResult({
    required this.title,
    required this.description,
    required this.wikidataId,
    this.imageUrl,
    this.labels = const [],
  });

  factory PersonaSearchResult.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] as List<dynamic>?;
    return PersonaSearchResult(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      wikidataId: (json['wikidata_id'] ?? json['wikidataId'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? json['thumbnailUrl'])?.toString(),
      labels: rawLabels?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'wikidata_id': wikidataId,
      'image_url': imageUrl,
      'labels': labels,
    };
  }
}
