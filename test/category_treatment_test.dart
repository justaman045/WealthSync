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

  test('fixedAmount round-trips and clearing it persists as null', () {
    final cat = CategoryModel(
      id: 'c3',
      name: 'Food',
      fixedAmount: 550,
    );
    expect(cat.toMap()['fixedAmount'], 550);
    expect(CategoryModel.fromMap('c3', cat.toMap()).fixedAmount, 550);

    // Clearing the field must write null, or the old amount would keep
    // applying as an override instead of returning to the auto average.
    final cleared = CategoryModel(id: 'c3', name: 'Food', fixedAmount: null);
    expect(cleared.toMap()['fixedAmount'], isNull);
    expect(CategoryModel.fromMap('c3', cleared.toMap()).fixedAmount, isNull);
  });

  test('buildFixedAmountOverrides keeps only positive, named amounts', () {
    final cats = [
      CategoryModel(id: '1', name: '  Food  ', fixedAmount: 550),
      CategoryModel(id: '2', name: 'Rent', fixedAmount: 0),
      CategoryModel(id: '3', name: 'Gym', fixedAmount: null),
      CategoryModel(id: '4', name: '   ', fixedAmount: 900),
      CategoryModel(id: '5', name: 'Travel', fixedAmount: -5),
      CategoryModel(id: '6', name: 'Internet', fixedAmount: double.infinity),
    ];
    expect(buildFixedAmountOverrides(cats), {'food': 550});
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
