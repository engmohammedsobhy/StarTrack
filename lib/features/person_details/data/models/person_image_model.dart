class PersonImages {
  final List<PersonImage> profiles;

  PersonImages({required this.profiles});

  factory PersonImages.fromJson(Map<String, dynamic> json) {
    return PersonImages(
      profiles:
          (json['profiles'] as List?)
              ?.map((i) => PersonImage.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class PersonImage {
  final String filePath;
  final double? aspectRatio;
  final int? height;
  final int? width;

  PersonImage({
    required this.filePath,
    this.aspectRatio,
    this.height,
    this.width,
  });

  factory PersonImage.fromJson(Map<String, dynamic> json) {
    return PersonImage(
      filePath: json['file_path'] ?? '',
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble(),
      height: json['height'],
      width: json['width'],
    );
  }
}
