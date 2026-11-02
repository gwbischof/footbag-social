// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/blur_hash.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// The box a post's media is drawn in.
///
/// Every item in a carousel shares one box, sized from the first item and
/// clamped between 4:5 portrait and 1.91:1 landscape. Unclamped, a 9:16 phone
/// clip would be taller than most screens and a panorama a sliver; with one
/// box per item, swiping would make the whole feed jump.
double mediaBoxRatio(List<FootbagMedia> media) =>
    media.first.aspectRatio.clamp(4 / 5, 1.91);

class MediaCarousel extends StatefulWidget {
  final List<FootbagMedia> media;
  final Uri Function(String) resolve;

  /// Incremented by the card on each double-tap; a change replays the burst.
  final int burst;
  final VoidCallback onDoubleTap;
  final ValueChanged<int> onPageChanged;

  const MediaCarousel({
    required this.media,
    required this.resolve,
    required this.burst,
    required this.onDoubleTap,
    required this.onPageChanged,
    super.key,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _page = 0;

  /// A mouse is over the carousel. The app lets only touch and trackpads
  /// drag a scrollable, so with a mouse these arrows are the only way to
  /// the second photo; a touch screen never hovers, so phones never see them.
  bool _hover = false;

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
  );

  late final _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void didUpdateWidget(MediaCarousel old) {
    super.didUpdateWidget(old);
    if (widget.burst != old.burst) unawaited(_burst.forward(from: 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final l10n = L10n.of(context);

    return Semantics(
      label: l10n.photoOrClip,
      child: AspectRatio(
        aspectRatio: mediaBoxRatio(media),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onDoubleTap: widget.onDoubleTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Nyfa.raised,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: media.length,
                    onPageChanged: (i) {
                      setState(() => _page = i);
                      widget.onPageChanged(i);
                    },
                    itemBuilder: (context, i) {
                      final m = media[i];
                      return m.isVideo
                          ? FeedVideo(
                              media: m,
                              resolve: widget.resolve,
                              active: i == _page,
                            )
                          : FeedImage(media: m, resolve: widget.resolve);
                    },
                  ),
                ),
                if (media.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _Pill(text: '${_page + 1}/${media.length}'),
                  ),
                if (_hover && _page > 0)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _Arrow(
                        icon: Icons.chevron_left,
                        label: MaterialLocalizations.of(
                          context,
                        ).previousPageTooltip,
                        onTap: () => _go(_page - 1),
                      ),
                    ),
                  ),
                if (_hover && _page < media.length - 1)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _Arrow(
                        icon: Icons.chevron_right,
                        label: MaterialLocalizations.of(
                          context,
                        ).nextPageTooltip,
                        onTap: () => _go(_page + 1),
                      ),
                    ),
                  ),
                // The double-tap burst: a large ♦ that swells and fades. The
                // tap has already counted; this is only there so it feels it.
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) {
                      final t = _burst.value;
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      final grow = Curves.elasticOut.transform(
                        (t * 1.6).clamp(0, 1),
                      );
                      final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
                      return Center(
                        child: Opacity(
                          opacity: fade,
                          child: Transform.scale(
                            scale: 0.4 + 0.6 * grow,
                            child: const Diamond(size: 96, color: Nyfa.green),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Arrow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Nyfa.ground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Nyfa.paper, size: 22),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
    color: Nyfa.ground,
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: Nyfa.display,
        fontSize: 14,
        letterSpacing: 1,
        color: Nyfa.paper,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// A photo: blurhash first, then the image fading in over it.
class FeedImage extends StatelessWidget {
  final FootbagMedia media;
  final Uri Function(String) resolve;
  final bool thumb;

  const FeedImage({
    required this.media,
    required this.resolve,
    this.thumb = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        if (media.blurhash != null)
          BlurHash(
            blurhash: media.blurhash,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        Image.network(
          resolve(thumb ? media.thumbUrl : media.posterUrl).toString(),
          fit: BoxFit.cover,
          // Decoded at the size it is drawn, not the size it was sent. A
          // 1080px photo in a 120px grid tile is otherwise nine times the
          // memory, and a scrolling feed of them is where jank comes from.
          cacheWidth: constraints.maxWidth.isFinite
              ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round()
              : null,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, sync) => sync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: child,
                ),
          errorBuilder: (context, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Nyfa.muted),
          ),
        ),
      ],
    ),
  );
}

/// Whether clips play with sound, shared by every clip on screen.
///
/// Unmute one and the next one is unmuted too, which is what someone who
/// turned the sound on meant. Starts muted because browsers refuse to autoplay
/// anything that is not.
final feedMuted = ValueNotifier<bool>(true);

/// A clip that plays itself while it is on screen.
///
/// The controller is created only once the clip first scrolls into view, so a
/// feed of twenty clips does not open twenty streams on load. It plays while
/// at least 60% visible and on the carousel's current page, and pauses
/// otherwise -- a clip that keeps playing off screen is battery and data
/// spent on nothing.
class FeedVideo extends StatefulWidget {
  final FootbagMedia media;
  final Uri Function(String) resolve;
  final bool active;

  const FeedVideo({
    required this.media,
    required this.resolve,
    required this.active,
    super.key,
  });

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  VideoPlayerController? _controller;
  ScrollableState? _scrollable;
  ScrollPosition? _scroll;
  bool _visible = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    feedMuted.addListener(_applyVolume);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The nearest Scrollable is the carousel's own PageView; the one that
    // matters for "on screen" is the vertical list above it.
    _scrollable = _verticalScrollable(context);
    final vertical = _scrollable?.position;
    if (vertical != _scroll) {
      _scroll?.removeListener(_evaluate);
      _scroll = vertical;
      _scroll?.addListener(_evaluate);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  static ScrollableState? _verticalScrollable(BuildContext context) {
    ScrollableState? found;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final s = element.state as ScrollableState;
        if (s.axisDirection == AxisDirection.down ||
            s.axisDirection == AxisDirection.up) {
          found = s;
          return false;
        }
      }
      return true;
    });
    return found;
  }

  @override
  void didUpdateWidget(FeedVideo old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _evaluate();
  }

  @override
  void dispose() {
    feedMuted.removeListener(_applyVolume);
    _scroll?.removeListener(_evaluate);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _applyVolume() => _controller?.setVolume(feedMuted.value ? 0 : 1);

  /// How much of this clip is inside the viewport, 0 to 1.
  double _visibleFraction() {
    final box = context.findRenderObject() as RenderBox?;
    final viewport = _scrollable?.context.findRenderObject() as RenderBox?;
    if (box == null ||
        !box.hasSize ||
        !box.attached ||
        viewport == null ||
        !viewport.attached) {
      return 0;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final vTop = viewport.localToGlobal(Offset.zero).dy;
    final vBottom = vTop + viewport.size.height;
    final shown = (bottom.clamp(vTop, vBottom) - top.clamp(vTop, vBottom));
    return box.size.height == 0 ? 0 : shown / box.size.height;
  }

  void _evaluate() {
    if (!mounted) return;
    final visible = widget.active && _visibleFraction() >= 0.6;
    if (visible == _visible && _controller != null) return;
    _visible = visible;
    if (visible) {
      unawaited(_play());
    } else {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _play() async {
    var c = _controller;
    if (c == null) {
      c = VideoPlayerController.networkUrl(
        widget.resolve(widget.media.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = c;
      try {
        await c.initialize();
      } catch (_) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      await c.setLooping(true);
      _applyVolume();
      if (!mounted) return;
      setState(() {});
    }
    if (_visible) await c.play();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return GestureDetector(
      // A single tap is the sound, as people expect from a feed; the
      // carousel's double-tap still reaches the card above.
      onTap: () => feedMuted.value = !feedMuted.value,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The poster stays underneath until the first frame is real, so
          // the box never flashes black between the blurhash and the clip.
          FeedImage(media: widget.media, resolve: widget.resolve),
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          if (_failed)
            const Center(
              child: Icon(
                Icons.videocam_off_outlined,
                color: Nyfa.paper,
                size: 32,
              ),
            ),
          Positioned(
            right: 12,
            bottom: 14,
            child: ValueListenableBuilder<bool>(
              valueListenable: feedMuted,
              builder: (context, muted, _) => Semantics(
                button: true,
                label: muted ? l10n.unmuteClip : l10n.mute,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Nyfa.ground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 16,
                    color: Nyfa.paper,
                  ),
                ),
              ),
            ),
          ),
          // A hairline of progress along the bottom edge, in the club green:
          // the scoreboard clock, shrunk to a line.
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: Nyfa.green,
                    bufferedColor: Nyfa.rule,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
