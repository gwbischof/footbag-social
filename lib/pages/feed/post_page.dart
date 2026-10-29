// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
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
  List<FootbagComment>? comments;
  Object? error;
  bool sending = false;
  final input = TextEditingController();
  final scroll = ScrollController();

  late final actions = AppPostActions(
    context,
    onRemoved: (_) => Navigator.of(context).pop(),
    onReplaced: (updated) => setState(() => post = updated),
  );

  Client get _client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    post = widget.initial;
    input.addListener(() => setState(() {}));
    unawaited(load());
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        _client.fetchPost(widget.postId),
        _client.fetchComments(widget.postId),
      ]);
      if (!mounted) return;
      setState(() {
        post = results[0] as FootbagPost;
        comments = results[1] as List<FootbagComment>;
        error = null;
      });
    } catch (e, s) {
      Logs().w('Loading a post failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => sending = true);
    try {
      final c = await _client.addComment(widget.postId, text);
      if (!mounted) return;
      input.clear();
      setState(() {
        comments = [...?comments, c];
        post?.commentCount += 1;
      });
      // Show what was just said: it is at the bottom, and the keyboard is
      // probably covering it.
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
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FootbagApiException ? e.detail : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> commentMenu(FootbagComment c) async {
    final l10n = L10n.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Nyfa.raised,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: ListTile(
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(
            c.isMine ? Icons.delete_outline : Icons.flag_outlined,
            color: Nyfa.paper,
          ),
          title: Text(
            (c.isMine ? l10n.delete : l10n.reportThis).toUpperCase(),
            style: Nyfa.heading.copyWith(fontSize: 17),
          ),
          onTap: () =>
              Navigator.of(context).pop(c.isMine ? 'delete' : 'report'),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'report') {
      await showReportSheet(context, commentId: c.id);
    } else if (choice == 'delete') {
      try {
        await _client.deleteComment(c.id);
        if (!mounted) return;
        setState(() {
          comments?.removeWhere((x) => x.id == c.id);
          post?.commentCount -= 1;
        });
      } catch (e) {
        Logs().w('Deleting a comment failed', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final p = post;

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
                child: p == null
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
                            if (comments == null)
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Nyfa.green,
                                    ),
                                  ),
                                ),
                              )
                            else if (comments!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  32,
                                ),
                                child: Text(
                                  l10n.noCommentsYet,
                                  style: Nyfa.bodyMuted,
                                ),
                              )
                            else
                              for (final c in comments!)
                                _CommentRow(
                                  comment: c,
                                  avatar: actions.avatar(
                                    c.authorId,
                                    c.authorName,
                                    32,
                                  ),
                                  onAuthor: () => actions.openAuthor(
                                    c.authorId,
                                    c.authorName,
                                  ),
                                  onMenu: () => commentMenu(c),
                                ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
              ),
              if (p != null && !p.removed)
                _CommentBar(
                  controller: input,
                  sending: sending,
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

class _CommentRow extends StatelessWidget {
  final FootbagComment comment;
  final Widget avatar;
  final VoidCallback onAuthor;
  final VoidCallback onMenu;

  const _CommentRow({
    required this.comment,
    required this.avatar,
    required this.onAuthor,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return InkWell(
      key: Key('Comment_${comment.id}'),
      onLongPress: onMenu,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(onTap: onAuthor, child: avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${comment.authorName}  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: relativeTime(l10n, comment.createdAt),
                          style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    style: Nyfa.bodyText,
                  ),
                  const SizedBox(height: 2),
                  Text(comment.body, style: Nyfa.bodyText),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onPressed: onMenu,
              icon: const Icon(Icons.more_horiz, size: 18, color: Nyfa.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final Widget avatar;

  const _CommentBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final ready = controller.text.trim().isNotEmpty && !sending;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Nyfa.ground,
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('CommentInput'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: Nyfa.bodyText,
                  cursorColor: Nyfa.green,
                  onSubmitted: (_) => onSend(),
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  decoration: InputDecoration(
                    hintText: l10n.addComment,
                    hintStyle: Nyfa.bodyMuted.copyWith(fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              TextButton(
                key: const Key('CommentSend'),
                onPressed: ready ? onSend : null,
                child: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Nyfa.green,
                        ),
                      )
                    : Text(
                        l10n.postComment.toUpperCase(),
                        style: TextStyle(
                          fontFamily: Nyfa.display,
                          fontSize: 17,
                          letterSpacing: 1,
                          color: ready ? Nyfa.green : Nyfa.muted,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
