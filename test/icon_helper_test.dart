import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/icon_helper.dart';

/// A category's icon is persisted as an int `codePoint` and resolved later by
/// [IconHelper.getIconFromCode]. `supportedIcons` exists so the release
/// tree-shaker keeps every icon the picker can offer; if one is dropped, lookup
/// silently degrades to [Icons.category] with no error anywhere.
void main() {
  group('IconHelper.getIconFromCode()', () {
    test('resolves the fallback icon itself', () {
      expect(IconHelper.getIconFromCode(Icons.category.codePoint), Icons.category);
    });

    test('returns the fallback for null (fresh category, no icon yet)', () {
      expect(IconHelper.getIconFromCode(null), Icons.category);
    });

    test('returns the fallback for an unknown codePoint', () {
      // e.g. an icon removed from the picker in a later release.
      expect(IconHelper.getIconFromCode(999999999), Icons.category);
    });

    test('round-trips every selectable icon (the tree-shaking contract)', () {
      // This is the point of the whole file: each icon the picker offers must
      // come back identical, not silently replaced by the fallback.
      for (final icon in IconHelper.supportedIcons) {
        expect(
          IconHelper.getIconFromCode(icon.codePoint),
          icon,
          reason: 'icon 0x${icon.codePoint.toRadixString(16)} was lost',
        );
      }
    });

    test('the fallback is present in the supported list', () {
      // It doubles as the picker's default selection, so it must be listed.
      expect(IconHelper.supportedIcons, contains(Icons.category));
    });

    test('supported icons are non-empty and unique by codePoint', () {
      expect(IconHelper.supportedIcons, isNotEmpty);
      final codes = IconHelper.supportedIcons.map((i) => i.codePoint).toList();
      // A duplicate would make the picker show one icon twice and collapse a
      // persisted value onto the wrong glyph.
      expect(codes.toSet().length, codes.length);
    });

    test('lookup is O(1) and stable across repeated calls', () {
      final icon = IconHelper.supportedIcons.first;
      expect(
        IconHelper.getIconFromCode(icon.codePoint),
        IconHelper.getIconFromCode(icon.codePoint),
      );
    });
  });
}
