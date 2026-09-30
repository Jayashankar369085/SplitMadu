import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_providers.dart';

/// Resolves a UID into a display name using the shared user cache;
/// falls back to [fallback] while loading or if lookup fails.
class UserNameText extends StatelessWidget {
  const UserNameText(
    this.uid, {
    super.key,
    this.fallback = 'Someone',
    this.style,
  });

  final String uid;
  final String fallback;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendsProvider>();
    return FutureBuilder<String>(
      future: friends.getUser(uid).then((u) => u?.name ?? fallback),
      builder: (context, snap) {
        final name = snap.data ?? fallback;
        return Text(name, style: style);
      },
    );
  }
}
