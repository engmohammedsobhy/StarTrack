class PersonaSearchResult {
  final String title;
  final String description;
  final String wikidataId;
  final String? imageUrl;

  PersonaSearchResult({
    required this.title,
    required this.description,
    required this.wikidataId,
    this.imageUrl,
  });

  factory PersonaSearchResult.fromJson(Map<String, dynamic> json) {
    return PersonaSearchResult(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      wikidataId: json['wikidata_id'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'wikidata_id': wikidataId,
      'image_url': imageUrl,
    };
  }
}
