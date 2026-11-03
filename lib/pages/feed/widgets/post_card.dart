// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/feed_media.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';

/// What a card needs from whoever is showing it.
///
/// An interface rather than a pile of callbacks because the feed, the post
/// page, a profile and the mod queue all show the same card and each wires it
/// differently. It also lets the preview harness draw the real card with no
/// Matrix client behind it.
abstract class PostActions {
  /// Turn an API media path into something loadable.
  Uri resolve(String path);

  Widget avatar(String userId, String name, double size);

  /// Persist a ♦. The card has already shown it; this returns the server's
  /// truth, which the card then adopts.
  Future<({int count, bool reacted})> setReaction(FootbagPost post, bool on);

  /// Comments over the feed. [typing] opens the keyboard too -- the bubble
  /// means "say something", "View all" means "read". Completes when closed,
  /// so the card can redraw its count.
  Future<void> openComments(FootbagPost post, {required bool typing});

  void openAuthor(String userId, String name);

  void openTag(FootbagTag tag);

  void openClub(FootbagClubRef club);

  /// The ⋯ menu: edit and delete for the author, report for everyone else.
  void openMenu(FootbagPost post);
}

/// One post, as the feed shows it.
///
/// Media runs edge to edge; everything else sits on the 20px gutter the rest
/// of the club screens use, between hairlines rather than inside a card. The
/// one loud thing is the ♦: green, and the only colour on a post that is not
/// the photo itself.
class PostCard extends StatefulWidget {
  final FootbagPost post;
  final PostActions actions;

  /// Show every comment line and the whole caption -- the post page, where
  /// there is nothing to open.
  final bool expanded;

  const PostCard({
    required this.post,
    required this.actions,
    this.expanded = false,
    super.key,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  /// Bumped on each double-tap so the burst replays even mid-animation.
  int _burst = 0;
  bool _captionOpen = false;
  int _page = 0;

  FootbagPost get post => widget.post;

  Future<void> _react(bool on) async {
    if (post.reacted == on) return;
    // A light tap you can feel, on giving one only -- taking a ♦ back is
    // not an event worth announcing. A no-op on the web.
    if (on) unawaited(HapticFeedback.lightImpact());
    // Applied before the request: a tap that waits on the network to light up
    // feels broken, and the server's answer corrects it either way.
    setState(() {
      post.reacted = on;
      post.reactionCount += on ? 1 : -1;
    });
    try {
      final truth = await widget.actions.setReaction(post, on);
      if (!mounted) return;
      setState(() {
        post.reacted = truth.reacted;
        post.reactionCount = truth.count;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post.reacted = !on;
        post.reactionCount += on ? -1 : 1;
      });
    }
  }

  Future<void> _comments({required bool typing}) async {
    await widget.actions.openComments(post, typing: typing);
    if (mounted) setState(() {});
  }

  void _doubleTap() {
    setState(() => _burst++);
    unawaited(_react(true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hasMedia = post.media.isNotEmpty;

    return DecoratedBox(
      key: ValueKey('Post${post.id}'),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(post: post, actions: widget.actions),
          if (post.removed) _RemovedBanner(text: l10n.removedNotice),
          if (hasMedia)
            MediaCarousel(
              media: post.media,
              resolve: widget.actions.resolve,
              burst: _burst,
              onDoubleTap: _doubleTap,
              onPageChanged: (i) => setState(() => _page = i),
            )
          else ...[
            // With no picture, what would have been under it takes its place:
            // the words large, then the session's results. Below the ♦ row
            // they read as a footnote to a photo that is not there.
            if (post.caption.isNotEmpty)
              GestureDetector(
                onDoubleTap: _doubleTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    post.caption,
                    style: Nyfa.bodyText.copyWith(fontSize: 17, height: 1.4),
                  ),
                ),
              ),
            if (post.session != null)
              GestureDetector(
                onDoubleTap: _doubleTap,
                child: SessionResults(
                  summary: post.session!,
                  authorName: post.authorName,
                ),
              ),
          ],
          _ActionRow(
            post: post,
            page: _page,
            onReact: () => _react(!post.reacted),
            onComment: () => _comments(typing: true),
          ),
          _Counts(post: post),
          if (hasMedia && post.caption.isNotEmpty)
            _Caption(
              post: post,
              open: _captionOpen || widget.expanded,
              onOpen: () => setState(() => _captionOpen = true),
              onAuthor: () =>
                  widget.actions.openAuthor(post.authorId, post.authorName),
            ),
          if (post.tags.isNotEmpty || post.club != null)
            _Tags(
              tags: post.tags,
              club: post.club,
              onTap: widget.actions.openTag,
              onClub: widget.actions.openClub,
            ),
          if (hasMedia && post.session != null)
            SessionResults(summary: post.session!, authorName: post.authorName),
          if (!widget.expanded)
            _CommentPreview(post: post, onOpen: () => _comments(typing: false)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FootbagPost post;
  final PostActions actions;

  const _Header({required this.post, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final when = relativeTime(l10n, post.createdAt);
    final sub = [
      if (post.placeName != null) post.placeName!,
      when,
      if (post.editedAt != null) l10n.postEdited,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => actions.openAuthor(post.authorId, post.authorName),
              child: Row(
                children: [
                  actions.avatar(post.authorId, post.authorName, 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Nyfa.bodyText.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Nyfa.bodyMuted.copyWith(
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (post.isTutorial) ...[
            const SizedBox(width: 8),
            _Badge(text: l10n.tutorial),
          ],
          IconButton(
            key: Key('PostMenu${post.id}'),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onPressed: () => actions.openMenu(post),
            icon: const Icon(Icons.more_horiz, color: Nyfa.paper),
          ),
        ],
      ),
    );
  }
}

/// A small outlined label. Green outline, green text: a property of the post,
/// not an action, so it is never filled.
class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(7, 3, 7, 1),
    decoration: BoxDecoration(border: Border.all(color: Nyfa.green)),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: Nyfa.display,
        fontSize: 13,
        letterSpacing: 1.2,
        color: Nyfa.green,
        height: 1.1,
      ),
    ),
  );
}

class _RemovedBanner extends StatelessWidget {
  final String text;

  const _RemovedBanner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    color: Nyfa.raised,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.visibility_off_outlined, size: 18, color: Nyfa.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Nyfa.bodyMuted)),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final FootbagPost post;
  final int page;
  final VoidCallback onReact;
  final VoidCallback onComment;

  const _ActionRow({
    required this.post,
    required this.page,
    required this.onReact,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              DiamondButton(
                key: Key('React${post.id}'),
                on: post.reacted,
                label: post.reacted ? l10n.takeDiamond : l10n.giveDiamond,
                onTap: onReact,
              ),
              IconButton(
                key: Key('Comment${post.id}'),
                tooltip: l10n.comments,
                onPressed: onComment,
                icon: const Icon(
                  Icons.mode_comment_outlined,
                  color: Nyfa.paper,
                  size: 24,
                ),
              ),
              const Spacer(),
            ],
          ),
          // Centred on the row, not the gap beside the buttons, so the dots
          // sit under the middle of the photo they count.
          if (post.media.length > 1)
            PageDots(count: post.media.length, current: page),
        ],
      ),
    );
  }
}

/// The ♦: the app's one reaction.
///
/// Drawn rather than an emoji, so it is the same shape on every platform and
/// can be outlined when off. It bumps when tapped -- the only motion on a
/// card that is not someone's clip.
class DiamondButton extends StatefulWidget {
  final bool on;
  final String label;
  final VoidCallback onTap;
  final double size;

  const DiamondButton({
    required this.on,
    required this.label,
    required this.onTap,
    this.size = 22,
    super.key,
  });

  @override
  State<DiamondButton> createState() => _DiamondButtonState();
}

class _DiamondButtonState extends State<DiamondButton>
    with SingleTickerProviderStateMixin {
  late final _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(DiamondButton old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) unawaited(_bump.forward(from: 0));
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: widget.on,
    label: widget.label,
    child: InkResponse(
      onTap: widget.onTap,
      radius: 24,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedBuilder(
            animation: _bump,
            builder: (context, child) => Transform.scale(
              // Up and back: 1 -> 1.3 -> 1 over the curve's run.
              scale:
                  1 +
                  0.3 *
                      Curves.easeOut.transform(1 - (2 * _bump.value - 1).abs()),
              child: child,
            ),
            child: Diamond(size: widget.size, filled: widget.on),
          ),
        ),
      ),
    ),
  );
}

class Diamond extends StatelessWidget {
  final double size;
  final bool filled;
  final Color? color;

  const Diamond({
    required this.size,
    this.filled = true,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * 0.78, size),
    painter: _DiamondPainter(
      filled: filled,
      color: color ?? (filled ? Nyfa.green : Nyfa.paper),
    ),
  );
}

class _DiamondPainter extends CustomPainter {
  final bool filled;
  final Color color;

  const _DiamondPainter({required this.filled, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.filled != filled || old.color != color;
}

class PageDots extends StatelessWidget {
  final int count;
  final int current;

  const PageDots({required this.count, required this.current, super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: i == current ? 14 : 5,
          height: 5,
          // Solid colours, as everywhere: rule for the rest, green for here.
          color: i == current ? Nyfa.green : Nyfa.muted,
        ),
    ],
  );
}

class _Counts extends StatelessWidget {
  final FootbagPost post;

  const _Counts({required this.post});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
    child: Text(
      L10n.of(context).diamonds(post.reactionCount).toUpperCase(),
      style: Nyfa.heading.copyWith(
        fontSize: 17,
        color: post.reactionCount == 0 ? Nyfa.muted : Nyfa.paper,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _Caption extends StatelessWidget {
  final FootbagPost post;
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback onAuthor;

  const _Caption({
    required this.post,
    required this.open,
    required this.onOpen,
    required this.onAuthor,
  });

  static const _bold = TextStyle(fontWeight: FontWeight.w700);

  /// How much of the caption fits in two lines with "… more" after it.
  ///
  /// Measured, not guessed: a binary search over the cut point, so "… more"
  /// lands exactly at the end of the second line the way people expect,
  /// instead of on a line of its own.
  static int _fit(
    String name,
    String caption,
    String more,
    double width,
    TextDirection dir,
    TextStyle style,
    TextScaler scaler,
  ) {
    bool fits(int n) {
      final painter = TextPainter(
        textScaler: scaler,
        text: TextSpan(
          style: style,
          children: [
            TextSpan(text: '$name  ', style: _bold),
            TextSpan(text: '${caption.substring(0, n).trimRight()}… $more'),
          ],
        ),
        maxLines: 2,
        textDirection: dir,
      )..layout(maxWidth: width);
      return !painter.didExceedMaxLines;
    }

    var lo = 0, hi = caption.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final dir = Directionality.of(context);
    // Measured in exactly the style it is drawn in. The first version used
    // Nyfa.bodyText alone, but Text merges it over the theme's default --
    // which adds letter spacing -- and applies the system text scale, so the
    // measured cut was a few pixels short and "more" fell onto a clipped
    // third line.
    final style = DefaultTextStyle.of(context).style.merge(Nyfa.bodyText);
    final scaler = MediaQuery.textScalerOf(context);
    final name = TextSpan(text: '${post.authorName}  ', style: _bold);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final whole = TextPainter(
            textScaler: scaler,
            text: TextSpan(
              style: style,
              children: [
                name,
                TextSpan(text: post.caption),
              ],
            ),
            maxLines: 2,
            textDirection: dir,
          )..layout(maxWidth: constraints.maxWidth);

          if (open || !whole.didExceedMaxLines) {
            return Text.rich(
              TextSpan(
                children: [
                  name,
                  TextSpan(text: post.caption),
                ],
              ),
              style: Nyfa.bodyText,
            );
          }
          final more = l10n.captionMore;
          final n = _fit(
            post.authorName,
            post.caption,
            more,
            constraints.maxWidth,
            dir,
            style,
            scaler,
          );
          return GestureDetector(
            onTap: onOpen,
            child: Text.rich(
              TextSpan(
                children: [
                  name,
                  TextSpan(
                    text: '${post.caption.substring(0, n).trimRight()}… ',
                  ),
                  TextSpan(
                    text: more,
                    style: const TextStyle(color: Nyfa.muted),
                  ),
                ],
              ),
              style: Nyfa.bodyText,
              maxLines: 2,
            ),
          );
        },
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  final List<FootbagTag> tags;
  final FootbagClubRef? club;
  final ValueChanged<FootbagTag> onTap;
  final ValueChanged<FootbagClubRef> onClub;

  const _Tags({
    required this.tags,
    required this.club,
    required this.onTap,
    required this.onClub,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // The club first, as where the post belongs; then what it is about.
        if (club != null)
          InkWell(
            key: Key('ClubTag_${club!.id}'),
            onTap: () => onClub(club!),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: Nyfa.green)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 15,
                    color: Nyfa.green,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    club!.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: Nyfa.display,
                      fontSize: 15,
                      letterSpacing: 0.9,
                      color: Nyfa.paper,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final t in tags)
          InkWell(
            key: Key('Tag_${t.slug}'),
            onTap: () => onTap(t),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Diamond(size: 9, color: Nyfa.green),
                  const SizedBox(width: 7),
                  Text(
                    t.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: Nyfa.display,
                      fontSize: 15,
                      letterSpacing: 0.9,
                      color: Nyfa.paper,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// What a session post carries besides its media: the report, as a scoreboard.
class SessionResults extends StatelessWidget {
  final FootbagSessionSummary summary;

  /// Who posted it: named over their own lines once others' results share
  /// the card, so it reads as a table of players rather than one list.
  final String? authorName;

  const SessionResults({required this.summary, this.authorName, super.key});

  /// How much of a shared session a card holds; the post page is the same
  /// card, so the cap is about the feed staying a feed.
  static const _perPlayer = 3;
  static const _players = 8;

  static String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String _type(L10n l10n) => switch (summary.type) {
    'kicking' => l10n.sessionTypeKicking,
    'net' => l10n.sessionTypeNet,
    'stitching' => l10n.sessionTypeStitching,
    'casual' => l10n.sessionTypeCasual,
    _ => l10n.sessionTypeFreestyle,
  };

  String? _grade(L10n l10n, String? grade) => switch (grade) {
    'tried' => l10n.gradeTried,
    'footing' => l10n.gradeFooting,
    'hitting' => l10n.gradeHitting,
    'consistent' => l10n.gradeConsistent,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final head = [
      _type(l10n),
      if (summary.duration != null) _duration(summary.duration!),
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Nyfa.raised,
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Nyfa.heading.copyWith(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  head.toUpperCase(),
                  style: Nyfa.eyebrow.copyWith(
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (summary.kicks != null)
            _line(
              lead: Text(
                '${summary.kicks}',
                style: Nyfa.clock.copyWith(fontSize: 30, height: 1),
              ),
              text: l10n.consecutiveKicks,
            ),
          if (summary.others.isNotEmpty && authorName != null)
            _player(authorName!),
          for (final line in summary.lines.take(
            summary.others.isEmpty ? 6 : _perPlayer,
          ))
            _result(l10n, line),
          for (final o in summary.others.take(_players)) ...[
            _player(o.name),
            if (o.kicks != null)
              _line(text: l10n.consecutiveKicks, trailing: '${o.kicks}'),
            for (final line in o.lines.take(_perPlayer)) _result(l10n, line),
          ],
          if (summary.others.length > _players)
            _line(text: l10n.morePlayers(summary.others.length - _players)),
        ],
      ),
    );
  }

  Widget _result(L10n l10n, FootbagSessionLine line) => _line(
    lead: line.isFirst ? _Badge(text: l10n.firstLanded) : null,
    text: line.name,
    trailing: [
      _grade(l10n, line.grade),
      if (line.count != null) '×${line.count}',
    ].whereType<String>().join('  '),
  );

  /// A player's name, heading their lines on a shared session.
  /// No rule of its own: the lines under it carry theirs.
  Widget _player(String name) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
    child: Text(name.toUpperCase(), style: Nyfa.eyebrow),
  );

  Widget _line({Widget? lead, required String text, String trailing = ''}) =>
      DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Nyfa.bodyText,
                ),
              ),
              if (trailing.isNotEmpty)
                Text(
                  trailing.toUpperCase(),
                  style: Nyfa.eyebrow.copyWith(
                    color: Nyfa.green,
                    fontSize: 14,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      );
}

class _CommentPreview extends StatelessWidget {
  final FootbagPost post;
  final VoidCallback onOpen;

  const _CommentPreview({required this.post, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (post.commentCount == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.commentCount > post.commentsPreview.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.viewAllComments(post.commentCount),
                  style: Nyfa.bodyMuted.copyWith(fontSize: 14),
                ),
              ),
            for (final c in post.commentsPreview)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${c.authorName}  ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: c.body),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Nyfa.bodyText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "3h", "2d", "5w" -- short, because it sits beside a name. Past a year,
/// the date, because "61w" is a sum nobody wants to do.
String relativeTime(L10n l10n, DateTime when, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(when);
  if (age.inMinutes < 1) return l10n.justNow;
  if (age.inHours < 1) return l10n.minutesAgoShort(age.inMinutes);
  if (age.inDays < 1) return l10n.hoursAgoShort(age.inHours);
  if (age.inDays < 7) return l10n.daysAgoShort(age.inDays);
  if (age.inDays < 365) return l10n.weeksAgoShort(age.inDays ~/ 7);
  return '${when.year}-${when.month.toString().padLeft(2, '0')}'
      '-${when.day.toString().padLeft(2, '0')}';
}
