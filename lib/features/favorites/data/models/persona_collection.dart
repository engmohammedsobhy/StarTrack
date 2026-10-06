import '../../../home/data/models/entity_model.dart';

class PersonaCollection {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<KnowledgeEntity> entities;

  const PersonaCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.entities = const [],
  });

  List<String> get entityIds => entities.map((e) => e.id).toList();

  PersonaCollection copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<KnowledgeEntity>? entities,
  }) {
    return PersonaCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      entities: entities ?? this.entities,
    );
  }

  factory PersonaCollection.fromJson(Map<String, dynamic> json) {
    final rawEntities = json['entities'] as List<dynamic>? ?? [];
    final entitiesList = rawEntities
        .map((e) => KnowledgeEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    return PersonaCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      entities: entitiesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'entities': entities.map((e) => e.toJson()).toList(),
    };
  }
}
