class QuickSendContactModel {
  final String id;
  final String name;
  final String? avatarUrl; // asset path or network url

  QuickSendContactModel({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory QuickSendContactModel.fromMap(String id, Map<String, dynamic> map) {
    return QuickSendContactModel(
      id: id,
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}
