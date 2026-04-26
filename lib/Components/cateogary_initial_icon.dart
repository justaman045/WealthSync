import 'package:flutter/material.dart';

class CategoryInitialsIcon extends StatelessWidget {
  final String categoryName;
  final double size;

  const CategoryInitialsIcon({
    super.key,
    required this.categoryName,
    this.size = 40.0,
  });

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Color _getColor(String name) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(categoryName);
    final bgColor = _getColor(categoryName);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size / 2,
        ),
      ),
    );
  }
}
