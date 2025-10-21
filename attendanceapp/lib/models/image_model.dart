class ImageModel {
  final String id;
  final String base64Data;

  ImageModel({
    required this.id,
    required this.base64Data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': base64Data,
  };

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'],
      base64Data: json['data'],
    );
  }
}
