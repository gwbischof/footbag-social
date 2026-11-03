// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Rooms with something unread: what the bell and the inbox's chat row count.
///
/// Spaces are left out -- a space is a folder, not a conversation.
int unreadChatCount(Client client) =>
    client.rooms.where((r) => !r.isSpace && r.isUnreadOrInvited).length;

/// Everything that happened that you should know about, newest first.
///
/// One list, as the doc settled. Chat is a single row at the top that opens
/// Chat: Matrix owns chat's unread state, and copying messages in here would
/// be a second, drifting copy of it.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  InboxPageState createState() => InboxPageState();
}

class InboxPageState extends State<InboxPage> {
  List<FootbagInboxItem>? items;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final loaded = await Matrix.of(context).client.fetchInbox();
      if (mounted) {
        setState(() {
          items = loaded;
          error = null;
        });
      }
    } catch (e, s) {
      Logs().w('Loading the inbox failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  /// Overridden by the preview harness, which has no Matrix client.
  int chatCount(BuildContext context) =>
      unreadChatCount(Matrix.of(context).client);

  Uri resolveMedia(String path) =>
      Matrix.of(context).client.footbagMediaUri(path);

  void open(FootbagInboxItem item) {
    switch (item.kind) {
      case 'join_request' || 'join_approved' when item.sessionId != null:
        context.push('/rooms/session/${item.sessionId}');
      case 'club_request' || 'club_approved' when item.club != null:
        context.push('/rooms/club/${item.club!.id}');
      case _ when item.postId != null && item.outcome != 'removed':
        context.push('/rooms/feed/post/${item.postId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = items;
    final chats = chatCount(context);

    return Scaffold(
      key: const Key('InboxScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.inbox),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: load,
            backgroundColor: Nyfa.raised,
            color: Nyfa.green,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (chats > 0) _ChatRow(count: chats),
                if (list == null && error != null)
                  FeedProblem(error: error!, onRetry: load)
                else if (list == null)
                  const RowsSkeleton(avatar: true)
                else if (list.isEmpty && chats == 0)
                  FeedEmpty(title: l10n.inboxEmpty)
                else
                  for (final item in list)
                    _InboxRow(
                      key: ValueKey(item.key),
                      item: item,
                      resolve: resolveMedia,
                      onTap: () => open(item),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final int count;

  const _ChatRow({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return InkWell(
      key: const Key('InboxChats'),
      onTap: () => context.go('/rooms'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          color: Nyfa.raised,
          border: Border(bottom: BorderSide(color: Nyfa.rule)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Nyfa.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 20,
                color: Nyfa.ground,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.unreadChats(count),
                style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Nyfa.faint),
          ],
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final FootbagInboxItem item;
  final Uri Function(String) resolve;
  final VoidCallback onTap;

  const _InboxRow({
    required this.item,
    required this.resolve,
    required this.onTap,
    super.key,
  });

  /// "Marco", "Marco and Kenji", "Marco and 3 others".
  static String _names(L10n l10n, FootbagInboxItem item) {
    final a = item.actors;
    if (a.isEmpty) return l10n.someone;
    if (item.actorCount == 1) return a[0].name;
    if (item.actorCount == 2 && a.length >= 2) {
      return l10n.namesTwo(a[0].name, a[1].name);
    }
    return l10n.namesMany(a[0].name, item.actorCount - 1);
  }

  /// The sentence with the names in bold, the way a person reads it: who,
  /// then what.
  static List<InlineSpan> _emphasised(String text, String names) {
    final at = names.isEmpty ? -1 : text.indexOf(names);
    final spans = at < 0
        ? [TextSpan(text: text)]
        : [
            TextSpan(text: text.substring(0, at)),
            TextSpan(
              text: names,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.substring(at + names.length)),
          ];
    return [for (final span in spans) ..._diamonds(span)];
  }

  /// The ♦ in a sentence, drawn as the app's own diamond. As a character it
  /// falls back to the system emoji font, which draws it red -- the one
  /// colour this app never uses for itself.
  static List<InlineSpan> _diamonds(TextSpan span) {
    final text = span.text ?? '';
    if (!text.contains('♦')) return [span];
    final parts = text.split('♦');
    return [
      for (var i = 0; i < parts.length; i++) ...[
        if (parts[i].isNotEmpty) TextSpan(text: parts[i], style: span.style),
        if (i < parts.length - 1)
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Diamond(size: 13),
            ),
          ),
      ],
    ];
  }

  String _text(L10n l10n) {
    final names = _names(l10n, item);
    final session = item.sessionName ?? '';
    return switch (item.kind) {
      'reaction' => l10n.inboxReaction(names),
      'comment' => l10n.inboxComment(names),
      'join_request' => l10n.inboxJoinRequest(names, session),
      'join_approved' => l10n.inboxJoinApproved(names, session),
      'club_request' => l10n.inboxClubRequest(names, item.club?.name ?? ''),
      'club_approved' => l10n.inboxClubApproved(names, item.club?.name ?? ''),
      'results_shared' => l10n.inboxResultsShared(names, session),
      'post_removed' => l10n.inboxPostRemoved,
      'report_resolved' =>
        item.outcome == 'removed'
            ? l10n.inboxReportRemoved
            : l10n.inboxReportKept,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final first = item.actors.firstOrNull;

    final Widget lead = first != null
        ? PlayerAvatar(userId: first.userId, name: first.name, size: 40)
        : Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Nyfa.raised,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 20,
              color: Nyfa.muted,
            ),
          );

    Widget? trail;
    if (item.postThumbUrl != null) {
      trail = SizedBox.square(
        dimension: 44,
        child: Image.network(
          resolve(item.postThumbUrl!).toString(),
          fit: BoxFit.cover,
          cacheWidth: 132,
          errorBuilder: (_, _, _) => const ColoredBox(color: Nyfa.raised),
        ),
      );
    } else if (item.postId != null && item.postCaption.isNotEmpty) {
      // A post with no picture. Its caption at thumbnail size was 8px type
      // nobody could read; a plain mark says "a text post" more clearly.
      trail = Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        color: Nyfa.raised,
        child: const Icon(Icons.notes_rounded, size: 20, color: Nyfa.muted),
      );
    } else if (item.sessionId != null || item.club != null) {
      trail = const Icon(Icons.chevron_right_rounded, color: Nyfa.faint);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        // New this visit: a lift off the ground and a green dot -- solid
        // colours, as everywhere, rather than a tint.
        color: item.unread ? Nyfa.raised : Nyfa.ground,
        child: Row(
          children: [
            lead,
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    ..._emphasised(_text(l10n), _names(l10n, item)),
                    TextSpan(
                      text: '  ${relativeTime(l10n, item.at)}',
                      style: Nyfa.meta,
                    ),
                  ],
                ),
                style: Nyfa.bodyText,
              ),
            ),
            if (item.unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 10),
                decoration: const BoxDecoration(
                  color: Nyfa.green,
                  shape: BoxShape.circle,
                ),
              ),
            if (trail != null) ...[const SizedBox(width: 12), trail],
          ],
        ),
      ),
    );
  }
}
