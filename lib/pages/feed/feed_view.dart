// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
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
    final posts = controller.posts;
    final topRow = controller.sort == 'top';

    return Scaffold(
      key: const Key('FeedScaffold'),
      backgroundColor: Nyfa.ground,
      bottomNavigationBar: trick
          ? null
          : const FootbagNavBar(current: FootbagTab.feed),
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
              edgeOffset: topRow ? 152 : 112,
              child: CustomScrollView(
                key: const Key('FeedList'),
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
                    automaticallyImplyLeading: trick,
                    leading: trick
                        ? const Center(child: BackButton(color: Nyfa.paper))
                        : null,
                    centerTitle: false,
                    titleSpacing: trick ? 0 : 20,
                    title: Text(
                      (trick ? controller.widget.entryName ?? '' : l10n.feed)
                          .toUpperCase(),
                      style: Nyfa.heading.copyWith(fontSize: trick ? 20 : 26),
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      if (!trick)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _PostButton(
                            label: l10n.newPost,
                            onPressed: controller.compose,
                          ),
                        ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(topRow ? 97 : 57),
                      child: _Filters(controller: controller),
                    ),
                  ),
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
                              title: l10n.feedEmptyTitle,
                              body: l10n.feedEmptyBody,
                              actionLabel: trick ? null : l10n.postSomething,
                              onAction: trick ? null : controller.compose,
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

class _PostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PostButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    // Outlined, not filled: the green [+] in the nav bar is the loudest
    // control in the app on purpose -- it starts a session -- and a second
    // filled green block above it made posting look like the main thing.
    child: OutlinedButton.icon(
      key: const Key('FeedPost'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Nyfa.green,
        side: const BorderSide(color: Nyfa.green),
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        shape: const RoundedRectangleBorder(),
        // 36 drawn, 48 to the finger.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: Nyfa.display,
          fontSize: 17,
          letterSpacing: 1.1,
          height: 1.2,
        ),
      ),
    ),
  );
}

class _Filters extends StatelessWidget {
  final FeedController controller;

  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Nyfa.ground,
        border: Border(bottom: BorderSide(color: Nyfa.rule)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              children: [
                FeedChip(
                  key: const Key('SortRecent'),
                  label: l10n.feedRecent,
                  selected: c.sort == 'recent',
                  onTap: () => c.setSort('recent'),
                ),
                FeedChip(
                  key: const Key('SortTop'),
                  label: l10n.feedTop,
                  selected: c.sort == 'top',
                  onTap: () => c.setSort('top'),
                ),
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
          if (c.sort == 'top')
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final w in <({String value, String label})>[
                    (value: 'day', label: l10n.windowDay),
                    (value: 'week', label: l10n.windowWeek),
                    (value: 'month', label: l10n.windowMonth),
                    (value: 'year', label: l10n.windowYear),
                    (value: 'all', label: l10n.windowAll),
                  ])
                    _WindowTab(
                      key: Key('Window_${w.value}'),
                      label: w.label,
                      selected: c.window == w.value,
                      onTap: () => c.setWindow(w.value),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A filter chip in the feed header.
///
/// Sort chips fill green when chosen. Filters, when on, are outlined in green
/// instead: two kinds of control, and filling both the same way made "Top"
/// and "Tutorials" read as one choice from a set of four.
class FeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlinedWhenOn;
  final bool busy;

  const FeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
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
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: filled ? Nyfa.green : Colors.transparent,
              border: Border.all(color: selected ? Nyfa.green : Nyfa.rule),
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
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: Nyfa.display,
                    fontSize: 16,
                    letterSpacing: 0.8,
                    color: fg,
                    height: 1.2,
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

/// Top's time window: lighter than the chips above it, because it refines a
/// choice rather than being one.
class _WindowTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WindowTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 15,
                letterSpacing: 1,
                color: selected ? Nyfa.green : Nyfa.muted,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 2,
              width: selected ? 24 : 0,
              color: Nyfa.green,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
  );
}
