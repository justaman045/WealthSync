class CategoryModel {
  final String id;
  final String name;
  final String? icon; // existing emoji/url
  final int? iconCode; // new for IconData codePoint
  final int? color; // new for Color value

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.iconCode,
    this.color,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'],
      iconCode: map['iconCode'],
      color: map['color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'icon': icon, 'iconCode': iconCode, 'color': color};
  }
}
