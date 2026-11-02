// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
import 'package:footbag_network/pages/feed/widgets/comments.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// One post and its whole conversation.
///
/// Opened with the card the feed already had, so it draws instantly, then
/// refreshed from the server -- the counts may have moved since the feed
/// loaded, and the full caption and comments were never in it.
class PostPage extends StatefulWidget {
  final int postId;
  final FootbagPost? initial;

  const PostPage({required this.postId, this.initial, super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  FootbagPost? post;
  CommentThread? thread;
  Object? error;
  final input = TextEditingController();
  final scroll = ScrollController();

  late final actions = AppPostActions(
    context,
    onRemoved: (_) => Navigator.of(context).pop(),
    onReplaced: (updated) => setState(() => _adopt(updated)),
  );

  Client get _client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    input.addListener(() => setState(() {}));
    if (widget.initial != null) _adopt(widget.initial!);
    unawaited(load());
  }

  void _adopt(FootbagPost p) {
    post = p;
    thread?.removeListener(_changed);
    thread?.dispose();
    thread = CommentThread(_client, p)..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    thread?.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await _client.fetchPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _adopt(p);
        error = null;
      });
      await thread!.load();
    } catch (e, s) {
      Logs().w('Loading a post failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> send() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final err = await thread!.send(input.text);
    if (!mounted) return;
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err is FootbagApiException
                ? err.detail
                : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
      return;
    }
    input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        unawaited(
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final p = post;
    final t = thread;

    return Scaffold(
      key: const Key('PostScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.comments),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: feedMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: p == null || t == null
                    ? (error != null
                          ? FeedProblem(error: error!, onRetry: load)
                          : const SingleChildScrollView(child: PostSkeleton()))
                    : RefreshIndicator(
                        onRefresh: load,
                        backgroundColor: Nyfa.raised,
                        color: Nyfa.green,
                        child: ListView(
                          controller: scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            PostCard(post: p, actions: actions, expanded: true),
                            ...commentRows(context, t, actions),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
              ),
              if (p != null && t != null && !p.removed)
                CommentBar(
                  controller: input,
                  sending: t.sending,
                  onSend: send,
                  avatar: actions.avatar(
                    _client.userID ?? '',
                    _client.userID?.substring(1) ?? '',
                    32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
