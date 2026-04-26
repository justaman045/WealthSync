import 'package:flutter/material.dart';

class IconHelper {
  // List of all icons used in the app's category system.
  // We must explicitly reference these consts so the tree-shaker keeps them.
  static const List<IconData> supportedIcons = [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.health_and_safety,
    Icons.movie,
    Icons.school,
    Icons.work,
    Icons.monetization_on,
    Icons.flight,
    Icons.fitness_center,
    Icons.pets,
    Icons.child_friendly,
    Icons.card_giftcard,
    Icons.wifi,
    Icons.local_grocery_store,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.local_pizza,
    Icons.local_laundry_service,
    Icons.checkroom,
    Icons.electrical_services,
    Icons.plumbing,
    Icons.build,
    Icons.computer,
    Icons.phone_android,
    Icons.videogame_asset,
    Icons.book,
    Icons.library_music,
    Icons.local_hospital,
    Icons.category, // Default fallback
  ];

  /// Returns the matching IconData for the given codePoint.
  /// Returns [Icons.category] if not found.
  static IconData getIconFromCode(int? codePoint) {
    if (codePoint == null) return Icons.category;
    try {
      return supportedIcons.firstWhere((icon) => icon.codePoint == codePoint);
    } catch (_) {
      // If the icon code is valid but not in our list, we have a problem
      // if we are strictly tree-shaking. But for now, fallback to default
      // is the safest way to prevent build errors.
      return Icons.category;
    }
  }
}
