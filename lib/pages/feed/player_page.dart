// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_grid.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/future_loading_dialog.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Someone's page: who they are, and everything they have posted.
///
/// This is the feed filtered by author -- the doc's point that "filtering by
/// user is a profile view, not a follow graph". There is no follow button,
/// because there is nothing to follow; there is a message button, because
/// the reason to open someone's page is usually to play with them.
class PlayerPage extends StatefulWidget {
  final String userId;

  /// The name the link was showing, so the header is not blank while the
  /// profile loads.
  final String? name;

  const PlayerPage({required this.userId, this.name, super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  FootbagPlayerProfile? profile;
  List<FootbagPost>? posts;
  String? _next;
  bool loadingMore = false;
  Object? error;

  Client get _client => Matrix.of(context).client;

  bool get isMe => widget.userId == _client.userID;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        _client.fetchPlayer(widget.userId),
        _client.fetchFeed(author: widget.userId, limit: 30),
      ]);
      if (!mounted) return;
      final page = results[1] as FootbagFeedPage;
      setState(() {
        profile = results[0] as FootbagPlayerProfile;
        posts = page.posts;
        _next = page.next;
        error = null;
      });
    } catch (e, s) {
      Logs().w('Loading a profile failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || _next == null) return;
    setState(() => loadingMore = true);
    try {
      final page = await _client.fetchFeed(
        author: widget.userId,
        cursor: _next,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        posts!.addAll(page.posts);
        _next = page.next;
      });
    } catch (e) {
      Logs().w('Loading more posts failed', e);
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> message() async {
    final router = GoRouter.of(context);
    final result = await showFutureLoadingDialog(
      context: context,
      future: () => _client.startDirectChat(widget.userId),
    );
    final roomId = result.result;
    if (roomId != null) router.go('/rooms/$roomId');
  }

  Future<void> open(FootbagPost post) async {
    await context.push('/rooms/feed/post/${post.id}', extra: post);
    // A ♦ or a comment on the post page changes nothing in a grid tile, but
    // a deletion does.
    if (mounted) unawaited(load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final p = profile?.player;
    final name = p?.displayName ?? widget.name ?? '';
    final list = posts;

    return Scaffold(
      key: const Key('PlayerScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: name),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: feedMaxWidth),
          child: error != null && profile == null
              ? FeedProblem(error: error!, onRetry: load)
              : RefreshIndicator(
                  onRefresh: load,
                  backgroundColor: Nyfa.raised,
                  color: Nyfa.green,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 600) unawaited(loadMore());
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    PlayerAvatar(
                                      userId: widget.userId,
                                      name: name,
                                      size: 72,
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.toUpperCase(),
                                            style: Nyfa.heading.copyWith(
                                              fontSize: 28,
                                            ),
                                          ),
                                          if (p?.city != null)
                                            Text(
                                              p!.city!,
                                              style: Nyfa.bodyMuted,
                                            ),
                                          if (profile != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                l10n
                                                    .postCount(
                                                      profile!.postCount,
                                                    )
                                                    .toUpperCase(),
                                                style: Nyfa.eyebrow.copyWith(
                                                  color: Nyfa.green,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (p != null && p.playStyles.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final s in p.playStyles)
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            3,
                                            8,
                                            1,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Nyfa.rule,
                                            ),
                                          ),
                                          child: Text(
                                            _style(l10n, s).toUpperCase(),
                                            style: Nyfa.eyebrow.copyWith(
                                              color: Nyfa.paper,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                if (p != null && p.bio.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(p.bio, style: Nyfa.bodyText),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: isMe
                                      ? NyfaForm.action(
                                          key: const Key('PlayerEdit'),
                                          label: l10n.editProfile,
                                          filled: false,
                                          onPressed: () => context.push(
                                            '/rooms/dash/profile',
                                          ),
                                        )
                                      : NyfaForm.action(
                                          key: const Key('PlayerMessage'),
                                          label: l10n.sendAMessage,
                                          onPressed: message,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: Divider(height: 1, color: Nyfa.rule),
                        ),
                        if (list == null)
                          const SliverToBoxAdapter(child: PostSkeleton())
                        else if (list.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                l10n.noPostsYet,
                                textAlign: TextAlign.center,
                                style: Nyfa.bodyMuted,
                              ),
                            ),
                          )
                        else
                          SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                  // 4:5, the tallest a post can be, so portrait
                                  // clips lose less to the crop than a square would.
                                  childAspectRatio: 4 / 5,
                                ),
                            itemCount: list.length,
                            itemBuilder: (context, i) => PostGridTile(
                              post: list[i],
                              resolve: _client.footbagMediaUri,
                              onTap: () => open(list[i]),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  static String _style(L10n l10n, String s) => switch (s) {
    'kicking' => l10n.sessionTypeKicking,
    'net' => l10n.sessionTypeNet,
    'stitching' => l10n.sessionTypeStitching,
    _ => l10n.sessionTypeFreestyle,
  };
}
