import 'package:flutter/material.dart';

/// Deterministic player avatar displaying initials over a harmonious seeded background color.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.size = 44,
  });

  final String seed;
  final String name;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF0E7A5F), // Emerald
    Color(0xFF2E7D32), // Forest
    Color(0xFF00796B), // Teal
    Color(0xFF1976D2), // Ocean Blue
    Color(0xFF5E35B1), // Deep Purple
    Color(0xFFD81B60), // Berry
    Color(0xFFE65100), // Amber Dark
    Color(0xFF455A64), // Slate
  ];

  Color _colorFor(String s) {
    if (s.isEmpty) return _palette[0];
    int hash = 0;
    for (int i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.codeUnitAt(i)) & 0xFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  String _initials(String n) {
    final trimmed = n.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _colorFor(seed.isNotEmpty ? seed : name);
    final text = _initials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
