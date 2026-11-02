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

  /// The user's own monthly amount for this category's bill, or null/0 for
  /// Auto (the average of the months that have spending). Optional and
  /// free — it lives next to [treatmentOverride] because both describe how the
  /// category counts toward the AI Insights bills total.
  final double? fixedAmount;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.iconCode,
    this.color,
    this.treatmentOverride,
    this.fixedAmount,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'],
      iconCode: (map['iconCode'] as num?)?.toInt(),
      color: (map['color'] as num?)?.toInt(),
      treatmentOverride: map['treatmentOverride'] as String?,
      fixedAmount: (map['fixedAmount'] as num?)?.toDouble(),
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
      // Same contract: clearing the field writes null so Auto wins again.
      'fixedAmount': fixedAmount,
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

/// Builds the per-category manual bill amounts: lowercased, trimmed name ->
/// positive amount. Cleared/zero/negative entries are omitted so the
/// auto-average keeps applying (see `buildMonthlyBills`).
Map<String, double> buildFixedAmountOverrides(
  Iterable<CategoryModel> categories,
) {
  final map = <String, double>{};
  for (final category in categories) {
    final amount = category.fixedAmount;
    if (amount == null || !amount.isFinite || amount <= 0) continue;
    final key = category.name.toLowerCase().trim();
    if (key.isEmpty) continue;
    map[key] = amount;
  }
  return map;
}
