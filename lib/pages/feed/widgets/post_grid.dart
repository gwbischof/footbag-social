// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
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
    } else if (post.landed case final landed?) {
      // A landing with no clip: the trick itself, set like a trophy. A
      // profile of these reads as a collection, not a grid of grey squares.
      body = Container(
        color: Nyfa.raised,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Diamond(size: 12, color: Nyfa.green),
            const Spacer(),
            Text(
              landed.name.toUpperCase(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 22,
                height: 0.95,
                color: Nyfa.paper,
              ),
            ),
            if (landed.first)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(L10n.of(context).firstLanded, style: Nyfa.meta),
              ),
          ],
        ),
      );
    } else {
      // Designed as a tile of its own rather than a photo that failed to
      // load: the words on the card surface, top-left like a note, marked in
      // the corner the way a video or an album is.
      final words = post.caption.isNotEmpty
          ? post.caption
          : (post.session?.name ?? '');
      body = Container(
        color: Nyfa.raised,
        padding: const EdgeInsets.fromLTRB(10, 12, 26, 10),
        alignment: Alignment.topLeft,
        child: Text(
          words,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: Nyfa.bodyText.copyWith(
            fontSize: 13,
            height: 1.35,
            fontWeight: post.caption.isEmpty ? FontWeight.w600 : null,
          ),
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
          if ((first == null && post.landed == null) ||
              (first != null && (post.media.length > 1 || first.isVideo)))
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                first == null
                    ? (post.session != null
                          ? Icons.timer_outlined
                          : Icons.notes_rounded)
                    : first.isVideo
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
              child: Diamond(size: 12, color: Nyfa.paper),
            ),
        ],
      ),
    );
  }
}
