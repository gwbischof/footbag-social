// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/pages/feed/widgets/feed_media.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';

/// One post in a grid -- a profile's, or a club's.
///
/// A post with no picture still gets a tile -- its words, or its session --
/// because a grid that silently skipped text posts would misstate how much
/// someone has posted, right under the count that says otherwise.
class PostGridTile extends StatelessWidget {
  final FootbagPost post;
  final Uri Function(String) resolve;
  final VoidCallback onTap;

  const PostGridTile({
    required this.post,
    required this.resolve,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final first = post.media.firstOrNull;
    Widget body;
    if (first != null) {
      body = FeedImage(media: first, resolve: resolve, thumb: true);
    } else {
      body = Container(
        color: Nyfa.raised,
        padding: const EdgeInsets.all(10),
        alignment: Alignment.topLeft,
        child: Text(
          post.caption.isNotEmpty
              ? post.caption
              : (post.session?.name ?? '').toUpperCase(),
          maxLines: 6,
          overflow: TextOverflow.fade,
          style: post.caption.isNotEmpty
              ? Nyfa.bodyText.copyWith(fontSize: 12, height: 1.35)
              : Nyfa.heading.copyWith(fontSize: 16),
        ),
      );
    }
    return InkWell(
      key: Key('Grid_${post.id}'),
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (post.media.length > 1 || (first?.isVideo ?? false))
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                first!.isVideo
                    ? Icons.play_arrow_rounded
                    : Icons.collections_outlined,
                size: 18,
                color: Nyfa.paper,
                shadows: const [Shadow(color: Nyfa.ground, blurRadius: 6)],
              ),
            ),
          if (post.isTutorial)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Diamond(size: 12, color: Nyfa.green),
            ),
        ],
      ),
    );
  }
}
