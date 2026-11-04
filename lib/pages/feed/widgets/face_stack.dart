// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:material_ui/material_ui.dart';

/// A few faces, overlapped: who has landed a trick, who has entered a
/// challenge. Social proof reads faster as people than as a number.
class FaceStack extends StatelessWidget {
  final List<({String userId, String name})> people;
  final double size;
  final int max;

  const FaceStack({
    required this.people,
    this.size = 32,
    this.max = 6,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 0.6;
    return SizedBox(
      width: size + (shown.length - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: DecoratedBox(
                // A ring in the ground colour, so overlapping faces read as
                // separate people rather than one blob.
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Nyfa.ground,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: PlayerAvatar(
                    userId: shown[i].userId,
                    name: shown[i].name,
                    size: size - 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
