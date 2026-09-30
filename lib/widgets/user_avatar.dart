import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// Circular avatar: photo if available, else initials on a color derived
/// from the name (deterministic, playful).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 22,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  static const _palette = [
    Color(0xFF5B34EB),
    Color(0xFFFF6B4A),
    Color(0xFF0FA968),
    Color(0xFF2D7FF9),
    Color(0xFFF5A623),
    Color(0xFF9C27B0),
    Color(0xFF00897B),
  ];

  Color get _color {
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _initialsBubble(isDark),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return _initialsBubble(isDark);
            },
          ),
        ),
      );
    }
    return _initialsBubble(isDark);
  }

  Widget _initialsBubble(bool isDark) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? _color.withValues(alpha: 0.35) : _color,
      child: Text(
        Formatters.initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.82,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
