// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// One post's conversation: loading it, adding to it, taking things out.
///
/// Shared by the comments sheet and the post page, so the two cannot drift.
/// It writes the count and the two-line preview back onto the post itself,
/// so the card under the sheet is already right when the sheet closes.
class CommentThread extends ChangeNotifier {
  final Client? client;
  final FootbagPost post;

  List<FootbagComment>? comments;
  Object? error;
  bool sending = false;

  CommentThread(this.client, this.post);

  Future<void> load() async {
    try {
      comments = await client!.fetchComments(post.id);
      error = null;
    } catch (e, s) {
      Logs().w('Loading comments failed', e, s);
      error = e;
    }
    notifyListeners();
  }

  void _syncPreview() {
    final all = comments ?? const <FootbagComment>[];
    post.commentsPreview
      ..clear()
      ..addAll(all.length > 2 ? all.sublist(all.length - 2) : all);
  }

  /// Post a comment. Returns the error to show, or null on success.
  Future<Object?> send(String text) async {
    if (text.trim().isEmpty || sending) return null;
    sending = true;
    notifyListeners();
    try {
      final c = await client!.addComment(post.id, text.trim());
      comments = [...?comments, c];
      post.commentCount += 1;
      _syncPreview();
      return null;
    } catch (e) {
      return e;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> remove(FootbagComment c) async {
    try {
      await client!.deleteComment(c.id);
      comments?.removeWhere((x) => x.id == c.id);
      post.commentCount -= 1;
      _syncPreview();
      notifyListeners();
    } catch (e) {
      Logs().w('Deleting a comment failed', e);
    }
  }
}

/// Delete for your own comment, report for anyone else's.
Future<void> showCommentMenu(
  BuildContext context,
  CommentThread thread,
  FootbagComment c,
) async {
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
        onTap: () => Navigator.of(context).pop(c.isMine ? 'delete' : 'report'),
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'report') {
    await showReportSheet(context, commentId: c.id);
  } else if (choice == 'delete') {
    await thread.remove(c);
  }
}

/// The comments, as rows -- or the state they are in.
List<Widget> commentRows(
  BuildContext context,
  CommentThread thread,
  PostActions actions,
) {
  final l10n = L10n.of(context);
  final comments = thread.comments;
  if (comments == null) {
    return const [
      Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Nyfa.green),
          ),
        ),
      ),
    ];
  }
  if (comments.isEmpty) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Text(l10n.noCommentsYet, style: Nyfa.bodyMuted),
      ),
    ];
  }
  return [
    for (final c in comments)
      CommentRow(
        key: ValueKey('CommentRow${c.id}'),
        comment: c,
        avatar: actions.avatar(c.authorId, c.authorName, 32),
        onAuthor: () => actions.openAuthor(c.authorId, c.authorName),
        onMenu: () => showCommentMenu(context, thread, c),
      ),
  ];
}

/// Comments over the feed, the way people expect them.
///
/// Opened from the bubble, the keyboard is already up -- the bubble means
/// "say something". Opened from "View all comments" it is not, because that
/// means "read". Swipe it away and the feed is exactly where it was, which a
/// separate page could not promise.
Future<void> showCommentsSheet(
  BuildContext context,
  PostActions actions, {
  required CommentThread thread,
  required String me,
  required bool typing,
}) {
  unawaited(thread.load());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Nyfa.ground,
    shape: const RoundedRectangleBorder(side: BorderSide(color: Nyfa.rule)),
    builder: (context) => _CommentsSheet(
      thread: thread,
      actions: actions,
      typing: typing,
      me: me,
    ),
  ).whenComplete(thread.dispose);
}

class _CommentsSheet extends StatefulWidget {
  final CommentThread thread;
  final PostActions actions;
  final bool typing;
  final String me;

  const _CommentsSheet({
    required this.thread,
    required this.actions,
    required this.typing,
    required this.me,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final input = TextEditingController();
  final scroll = ScrollController();

  CommentThread get thread => widget.thread;

  @override
  void initState() {
    super.initState();
    thread.addListener(_changed);
    input.addListener(_changed);
  }

  @override
  void dispose() {
    thread.removeListener(_changed);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> send() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final error = await thread.send(input.text);
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FootbagApiException
                ? error.detail
                : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
      return;
    }
    input.clear();
    // Newest is at the bottom, likely under the keyboard: bring it up.
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
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        // Two thirds of the screen: enough to read a thread, with the post
        // still visible above it so you know what you are replying to.
        height: height * 0.66,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, color: Nyfa.rule),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Text(
                l10n.comments.toUpperCase(),
                style: Nyfa.heading.copyWith(fontSize: 18),
              ),
            ),
            const Divider(height: 1, color: Nyfa.rule),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                children: commentRows(context, thread, widget.actions),
              ),
            ),
            if (!thread.post.removed)
              CommentBar(
                controller: input,
                sending: thread.sending,
                onSend: send,
                autofocus: widget.typing,
                avatar: widget.actions.avatar(
                  widget.me,
                  widget.me.length > 1 ? widget.me.substring(1) : widget.me,
                  32,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One comment. Its menu -- delete yours, report theirs -- is on long-press,
/// and with a mouse a ⋯ appears on hover. A ⋯ drawn on every row was a column
/// of dots down the thread for an action most people never take.
class CommentRow extends StatefulWidget {
  final FootbagComment comment;
  final Widget avatar;
  final VoidCallback onAuthor;
  final VoidCallback onMenu;

  const CommentRow({
    required this.comment,
    required this.avatar,
    required this.onAuthor,
    required this.onMenu,
    super.key,
  });

  @override
  State<CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<CommentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final comment = widget.comment;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        key: Key('Comment_${comment.id}'),
        onLongPress: widget.onMenu,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(onTap: widget.onAuthor, child: widget.avatar),
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
                            style: Nyfa.meta,
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
              // Always in the tree, so the row never reflows on hover; only
              // drawn while a pointer is over it.
              Opacity(
                opacity: _hover ? 1 : 0,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  onPressed: widget.onMenu,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Nyfa.muted,
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

class CommentBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final Widget avatar;
  final bool autofocus;

  const CommentBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.avatar,
    this.autofocus = false,
    super.key,
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
                  autofocus: autofocus,
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
