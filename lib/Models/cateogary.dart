class CategoryModel {
  final String id;
  final String name;
  final String? icon; // existing emoji/url
  final int? iconCode; // new for IconData codePoint
  final int? color; // new for Color value

  /// Per-category override for the Smart Daily Limit: `'fixed'`, `'ignored'`,
  /// or null/absent for Auto (the keyword classifier decides). See
  /// `resolveDailyLimitRole` in `Utils/wealth_math.dart`.
  final String? treatmentOverride;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.iconCode,
    this.color,
    this.treatmentOverride,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'],
      iconCode: (map['iconCode'] as num?)?.toInt(),
      color: (map['color'] as num?)?.toInt(),
      treatmentOverride: map['treatmentOverride'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'iconCode': iconCode,
      'color': color,
      // Always written (null clears it) so a reset back to Auto persists.
      'treatmentOverride': treatmentOverride,
    };
  }
}

/// Builds the `resolveDailyLimitRole` override map from loaded categories:
/// lowercased, trimmed name -> `'fixed'`/`'ignored'`. Auto (null) entries are
/// omitted so the keyword classifier still applies to them.
Map<String, String> buildTreatmentOverrides(Iterable<CategoryModel> categories) {
  final map = <String, String>{};
  for (final category in categories) {
    final override = category.treatmentOverride;
    if (override == null || override.isEmpty) continue;
    final key = category.name.toLowerCase().trim();
    if (key.isEmpty) continue;
    map[key] = override;
  }
  return map;
}
