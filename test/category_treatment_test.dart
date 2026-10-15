import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/cateogary.dart';

void main() {
  test('CategoryModel fromMap/toMap round-trips treatmentOverride', () {
    final cat = CategoryModel(
      id: 'c1',
      name: 'SIP',
      treatmentOverride: 'ignored',
      color: 0xFF00FF00,
      iconCode: 1234,
    );
    final map = cat.toMap();
    expect(map['treatmentOverride'], 'ignored');
    final back = CategoryModel.fromMap('c1', map);
    expect(back.treatmentOverride, 'ignored');
    expect(back.name, 'SIP');
  });

  test('treatmentOverride can be null (Auto)', () {
    final cat = CategoryModel(
      id: 'c2',
      name: 'Food',
      treatmentOverride: null,
    );
    final map = cat.toMap();
    expect(map['treatmentOverride'], isNull);
    final back = CategoryModel.fromMap('c2', map);
    expect(back.treatmentOverride, isNull);
  });

  test('buildTreatmentOverrides trims, lowercases, skips null/empty', () {
    final cats = [
      CategoryModel(id: '1', name: '  SIP  ', treatmentOverride: 'ignored'),
      CategoryModel(id: '2', name: 'Rent', treatmentOverride: 'fixed'),
      CategoryModel(id: '3', name: 'Food', treatmentOverride: null),
      CategoryModel(id: '4', name: '   ', treatmentOverride: 'ignored'),
      CategoryModel(id: '5', name: 'Cable', treatmentOverride: ''),
    ];
    final overrides = buildTreatmentOverrides(cats);
    expect(overrides, {'sip': 'ignored', 'rent': 'fixed'});
  });
}
