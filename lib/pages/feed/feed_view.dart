// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/challenge_card.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/pages/feed/widgets/trick_header.dart';
import 'package:footbag_network/pages/inbox/inbox_bell.dart';
import 'package:footbag_network/widgets/edge_fade.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The widest a post is drawn. A phone's width on a phone; on a desktop, a
/// column -- a 1400px-wide photo is a poster, not a post.
const feedMaxWidth = 600.0;

class FeedView extends StatelessWidget {
  final FeedController controller;

  const FeedView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final trick = controller.widget.isTrickPage;
    final challenge = controller.widget.isChallengePage;
    final sub = controller.widget.isSubPage;
    final posts = controller.posts;

    return Scaffold(
      key: const Key('FeedScaffold'),
      backgroundColor: Nyfa.ground,
      bottomNavigationBar: sub
          ? null
          : FootbagNavBar(
              current: FootbagTab.feed,
              onReselect: controller.scrollToTop,
            ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: feedMaxWidth),
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              backgroundColor: Nyfa.raised,
              color: Nyfa.green,
              // Below the floating header, not behind it.
              edgeOffset: 112,
              child: CustomScrollView(
                key: const Key('FeedList'),
                controller: controller.scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    // Floats: it slides away as you read down and comes back
                    // the moment you scroll up, so the filters are always one
                    // flick away without costing a fifth of the screen.
                    floating: true,
                    snap: true,
                    pinned: false,
                    backgroundColor: Nyfa.ground,
                    surfaceTintColor: Nyfa.ground,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: sub,
                    leading: sub
                        ? const Center(child: BackButton(color: Nyfa.paper))
                        : null,
                    centerTitle: false,
                    titleSpacing: sub ? 0 : 20,
                    // Home carries the masthead, as the front door; a trick's
                    // page carries the trick's name.
                    title: Text(
                      trick
                          ? (controller.widget.entryName ?? '')
                          : challenge
                          ? (controller.widget.challengeTitle ?? '')
                          : 'FOOTBAG SOCIAL',
                      style: sub
                          ? Nyfa.heading.copyWith(fontSize: 20)
                          : const TextStyle(
                              fontFamily: Nyfa.display,
                              color: Nyfa.paper,
                              fontSize: 24,
                              letterSpacing: 1.6,
                            ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Post, the bell, you: three icons, the way a feed's
                    // home screen is read. A labelled POST button beside the
                    // masthead, bell and avatar did not fit at phone width.
                    actions: [
                      if (!sub) ...[
                        IconButton(
                          key: const Key('FeedPost'),
                          tooltip: l10n.newPost,
                          onPressed: controller.compose,
                          icon: const Icon(
                            Icons.add_box_outlined,
                            color: Nyfa.paper,
                            size: 26,
                          ),
                        ),
                        const InboxBell(),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            key: const Key('FeedProfile'),
                            tooltip: l10n.editProfile,
                            onPressed: () =>
                                context.push('/rooms/dash/profile'),
                            icon: PlayerAvatar(
                              userId: controller.myUserId,
                              name: controller.myUserId.length > 1
                                  ? controller.myUserId.substring(1)
                                  : '?',
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: _Filters(controller: controller),
                    ),
                  ),
                  if (trick)
                    SliverToBoxAdapter(
                      child: TrickHeader(slug: controller.widget.entrySlug!),
                    ),
                  if (challenge)
                    SliverToBoxAdapter(
                      child: ChallengeHeader(
                        slug: controller.widget.challengeSlug!,
                      ),
                    ),
                  if (!sub)
                    const SliverToBoxAdapter(child: ChallengeBanner()),
                  if (controller.error != null && posts == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: FeedProblem(
                        error: controller.error!,
                        onRetry: controller.refresh,
                      ),
                    )
                  else if (posts == null)
                    SliverList.list(
                      children: const [PostSkeleton(), PostSkeleton()],
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: controller.isFiltered
                          ? FeedEmpty(
                              title: l10n.feedFilteredEmpty,
                              actionLabel: l10n.clearFilters,
                              onAction: controller.clearFilters,
                            )
                          : FeedEmpty(
                              title: trick
                                  ? l10n.trickNoClipsTitle
                                  : challenge
                                  ? l10n.challengeNoEntriesTitle
                                  : l10n.feedEmptyTitle,
                              body: trick
                                  ? l10n.trickNoClipsBody
                                  : challenge
                                  ? l10n.challengeNoEntriesBody
                                  : l10n.feedEmptyBody,
                              actionLabel: sub ? null : l10n.postSomething,
                              onAction: sub ? null : controller.compose,
                            ),
                    )
                  else ...[
                    SliverList.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, i) {
                        // Ask for the next page three posts early, so it has
                        // usually arrived before anyone reaches the end.
                        if (i >= posts.length - 3) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => unawaited(controller.loadMore()),
                          );
                        }
                        return PostCard(
                          key: ValueKey('PostCard${posts[i].id}'),
                          post: posts[i],
                          actions: controller.actions,
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: FeedFooter(
                        loading: controller.loadingMore,
                        failed: controller.moreFailed,
                        atEnd: !controller.hasMore,
                        onRetry: controller.retryMore,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final FeedController controller;

  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;

    // Small and borderless, so the first post starts right under the
    // masthead: a row of 40px blocks over a ruled edge was the heaviest
    // thing on the home screen.
    return ColoredBox(
      color: Nyfa.ground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: EdgeFade(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                children: [
                  FeedChip(
                    key: const Key('SortRecent'),
                    label: l10n.feedRecent,
                    selected: c.sort == 'recent',
                    onTap: () => c.setSort('recent'),
                  ),
                  _TopChip(controller: c),
                  // A gap rather than a divider: sort is one choice, filters
                  // are independent switches, and the space says so.
                  const SizedBox(width: 12),
                  FeedChip(
                    key: const Key('FilterTutorials'),
                    label: l10n.feedTutorials,
                    selected: c.tutorialsOnly,
                    outlinedWhenOn: true,
                    onTap: c.toggleTutorials,
                  ),
                  FeedChip(
                    key: const Key('FilterNear'),
                    label: l10n.feedNearMe,
                    icon: Icons.near_me_outlined,
                    busy: c.locating,
                    selected: c.near != null,
                    outlinedWhenOn: true,
                    onTap: c.toggleNear,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A filter chip in the feed header.
///
/// Sort chips fill paper when chosen. Filters, when on, keep their fill and
/// turn their label green instead: two kinds of control, and filling both the same way made "Top"
/// and "Tutorials" read as one choice from a set of four.
class FeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailing;
  final bool outlinedWhenOn;
  final bool busy;

  const FeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailing,
    this.outlinedWhenOn = false,
    this.busy = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final filled = selected && !outlinedWhenOn;
    final fg = filled
        ? Nyfa.ground
        : selected
        ? Nyfa.green
        : Nyfa.paper;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // Tonal when off, paper when on -- the shared chip's look; an
            // outlined-when-on chip keeps the tonal fill and turns its label
            // green, so "on" never needs a box drawn round it.
            decoration: BoxDecoration(
              color: filled ? Nyfa.paper : Nyfa.tonal,
              borderRadius: Nyfa.rounded,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Nyfa.green,
                      ),
                    ),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 15, color: fg),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Nyfa.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: fg,
                    height: 1.2,
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(trailing, size: 18, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top, and how far back it counts, in one chip.
///
/// The window used to be a second row that appeared under the filters when
/// Top was chosen, so the header grew by 40px exactly when you wanted to look
/// at posts. Now the chip says which window it is using -- "Top · Week" --
/// and tapping it again offers the others.
class _TopChip extends StatefulWidget {
  final FeedController controller;

  const _TopChip({required this.controller});

  @override
  State<_TopChip> createState() => _TopChipState();
}

class _TopChipState extends State<_TopChip> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = widget.controller;
    final windows = <({String value, String label})>[
      (value: 'day', label: l10n.windowDay),
      (value: 'week', label: l10n.windowWeek),
      (value: 'month', label: l10n.windowMonth),
      (value: 'year', label: l10n.windowYear),
      (value: 'all', label: l10n.windowAll),
    ];
    final on = c.sort == 'top';
    final current = windows.firstWhere((w) => w.value == c.window).label;

    return MenuAnchor(
      controller: _menu,
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Nyfa.raised),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(color: Nyfa.rule),
            borderRadius: Nyfa.rounded,
          ),
        ),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        for (final w in windows)
          MenuItemButton(
            key: Key('Window_${w.value}'),
            onPressed: () => c.setWindow(w.value),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(160, 48)),
            ),
            trailingIcon: w.value == c.window
                ? const Icon(Icons.check, size: 18, color: Nyfa.green)
                : null,
            child: Text(
              w.label,
              style: TextStyle(
                fontFamily: Nyfa.body,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: w.value == c.window ? Nyfa.green : Nyfa.paper,
              ),
            ),
          ),
      ],
      child: FeedChip(
        key: const Key('SortTop'),
        label: on ? '${l10n.feedTop} · $current' : l10n.feedTop,
        trailing: on ? Icons.expand_more : null,
        selected: on,
        onTap: () => on ? _menu.open() : c.setSort('top'),
      ),
    );
  }
}
