class PersonDetails {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final String? profilePath;
  final String? knownForDepartment;
  final double? popularity;

  PersonDetails({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.placeOfBirth,
    this.profilePath,
    this.knownForDepartment,
    this.popularity,
  });

  PersonDetails copyWith({
    int? id,
    String? name,
    String? biography,
    String? birthday,
    String? placeOfBirth,
    String? profilePath,
    String? knownForDepartment,
    double? popularity,
  }) {
    return PersonDetails(
      id: id ?? this.id,
      name: name ?? this.name,
      biography: biography ?? this.biography,
      birthday: birthday ?? this.birthday,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      profilePath: profilePath ?? this.profilePath,
      knownForDepartment: knownForDepartment ?? this.knownForDepartment,
      popularity: popularity ?? this.popularity,
    );
  }

  factory PersonDetails.fromJson(Map<String, dynamic> json) {
    return PersonDetails(
      id: json['id'],
      name: json['name'] ?? '',
      biography: json['biography'],
      birthday: json['birthday'],
      placeOfBirth: json['place_of_birth'],
      profilePath: json['profile_path'],
      knownForDepartment: json['known_for_department'],
      popularity: (json['popularity'] as num?)?.toDouble(),
    );
  }
}
