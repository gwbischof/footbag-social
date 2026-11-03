// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/comments.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:footbag_network/widgets/avatar.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// [PostActions] for the running app: the API, the router, and the sheets.
///
/// One implementation shared by the feed, a post's page, a profile and a
/// trick's clips, so the ⋯ menu means the same thing wherever a card appears.
/// The owning screen hears about deletions and edits through the callbacks,
/// so it can drop or replace the card without a reload.
class AppPostActions implements PostActions {
  final BuildContext context;
  final void Function(FootbagPost post) onRemoved;
  final void Function(FootbagPost updated) onReplaced;

  AppPostActions(
    this.context, {
    required this.onRemoved,
    required this.onReplaced,
  });

  Client get _client => Matrix.of(context).client;

  @override
  Uri resolve(String path) => _client.footbagMediaUri(path);

  @override
  Widget avatar(String userId, String name, double size) =>
      PlayerAvatar(userId: userId, name: name, size: size);

  @override
  Future<({int count, bool reacted})> setReaction(FootbagPost post, bool on) =>
      _client.setReaction(post.id, on);

  @override
  Future<void> openComments(FootbagPost post, {required bool typing}) =>
      showCommentsSheet(
        context,
        this,
        thread: CommentThread(_client, post),
        me: _client.userID ?? '',
        typing: typing,
      );

  @override
  void openAuthor(String userId, String name) => unawaited(
    context.push(
      '/rooms/feed/player/${Uri.encodeComponent(userId)}',
      extra: name,
    ),
  );

  @override
  void openTag(FootbagTag tag) =>
      unawaited(context.push('/rooms/feed/trick/${tag.slug}', extra: tag.name));

  @override
  void openClub(FootbagClubRef club) =>
      unawaited(context.push('/rooms/club/${club.id}'));

  @override
  void openMenu(FootbagPost post) => unawaited(_menu(post));

  Future<void> _menu(FootbagPost post) async {
    final l10n = L10n.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Nyfa.raised,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.isMine && !post.removed) ...[
              _SheetRow(
                key: const Key('MenuEdit'),
                icon: Icons.edit_outlined,
                label: l10n.editPost,
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              _SheetRow(
                key: const Key('MenuDelete'),
                icon: Icons.delete_outline,
                label: l10n.deletePost,
                danger: true,
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
            if (!post.isMine)
              _SheetRow(
                key: const Key('MenuReport'),
                icon: Icons.flag_outlined,
                label: l10n.reportThis,
                danger: true,
                onTap: () => Navigator.of(context).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        await _edit(post);
      case 'delete':
        await _delete(post);
      case 'report':
        await showReportSheet(context, postId: post.id);
    }
  }

  Future<void> _delete(FootbagPost post) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showOkCancelAlertDialog(
      context: context,
      title: l10n.deletePost,
      message: l10n.deletePostConfirm,
      okLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      isDestructive: true,
    );
    if (ok != OkCancelResult.ok) return;
    try {
      await _client.deletePost(post.id);
      onRemoved(post);
      messenger.showSnackBar(SnackBar(content: Text(l10n.postDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_describe(l10n, e))));
    }
  }

  Future<void> _edit(FootbagPost post) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final caption = TextEditingController(text: post.caption);
    var tutorial = post.isTutorial;

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Nyfa.ground,
      shape: const RoundedRectangleBorder(),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NyfaForm.section(l10n.editPost),
                NyfaForm.field(
                  key: const Key('EditCaption'),
                  controller: caption,
                  label: l10n.captionHint,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2200,
                ),
                const SizedBox(height: 8),
                NyfaForm.toggle(
                  label: l10n.markTutorial,
                  explain: l10n.markTutorialExplain,
                  value: tutorial,
                  onChanged: (v) => setSheet(() => tutorial = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: NyfaForm.action(
                    key: const Key('EditSave'),
                    label: l10n.saveChanges,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final text = caption.text.trim();
    caption.dispose();
    if (save != true) return;
    try {
      final updated = await _client.editPost(
        post.id,
        caption: text,
        isTutorial: tutorial,
      );
      onReplaced(updated);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_describe(l10n, e))));
    }
  }
}

String _describe(L10n l10n, Object e) => switch (e) {
  FootbagApiException(isNotSignedIn: true) => l10n.signedOutAgain,
  FootbagApiException(:final detail) => detail,
  _ => l10n.oopsSomethingWentWrong,
};

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: Icon(icon, color: Nyfa.paper),
    title: Text(
      label.toUpperCase(),
      style: Nyfa.heading.copyWith(fontSize: 17),
    ),
    onTap: onTap,
  );
}

/// Report a post or a comment: a reason, and an optional note.
///
/// "Illegal, or someone at risk" is listed last but sorts first for the
/// moderators -- the order here is for the person reporting, who usually has
/// one of the commoner reasons in mind.
Future<void> showReportSheet(
  BuildContext context, {
  int? postId,
  int? commentId,
}) async {
  final l10n = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final client = Matrix.of(context).client;
  final note = TextEditingController();
  String? reason;
  var sending = false;

  final reasons = <({String value, String label})>[
    (value: 'spam', label: l10n.reasonSpam),
    (value: 'harassment', label: l10n.reasonHarassment),
    (value: 'not_footbag', label: l10n.reasonNotFootbag),
    (value: 'not_theirs', label: l10n.reasonNotTheirs),
    (value: 'illegal', label: l10n.reasonIllegal),
  ];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Nyfa.ground,
    shape: const RoundedRectangleBorder(),
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NyfaForm.section(l10n.reportWhy),
                for (final r in reasons)
                  InkWell(
                    key: Key('Reason_${r.value}'),
                    onTap: () => setSheet(() => reason = r.value),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Nyfa.rule)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(r.label, style: Nyfa.bodyText)),
                          if (reason == r.value)
                            const Diamond(size: 16, color: Nyfa.green)
                          else
                            const Diamond(
                              size: 16,
                              filled: false,
                              color: Nyfa.rule,
                            ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 1, color: Nyfa.rule),
                const SizedBox(height: 16),
                NyfaForm.field(
                  controller: note,
                  label: l10n.reportNote,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: NyfaForm.action(
                    key: const Key('SendReport'),
                    label: l10n.sendReport,
                    onPressed: reason == null || sending
                        ? null
                        : () async {
                            setSheet(() => sending = true);
                            try {
                              await client.reportContent(
                                postId: postId,
                                commentId: commentId,
                                reason: reason!,
                                note: note.text.trim(),
                              );
                              if (context.mounted) Navigator.of(context).pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.reportSent)),
                              );
                            } catch (e) {
                              setSheet(() => sending = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(_describe(l10n, e))),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  note.dispose();
}

/// Someone's picture, from their Matrix profile.
///
/// The same picture they have in chat, because it is the same person. The
/// SDK caches profiles, so a feed of the same five people asks once each.
class PlayerAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final double size;

  const PlayerAvatar({
    required this.userId,
    required this.name,
    required this.size,
    super.key,
  });

  /// Replaces the Matrix lookup in the preview harness, which has no
  /// client. Never set in the app.
  static Widget Function(String userId, String name, double size)?
  previewBuilder;

  @override
  Widget build(BuildContext context) {
    final preview = previewBuilder;
    if (preview != null) return preview(userId, name, size);
    final client = Matrix.of(context).client;
    return FutureBuilder<Profile>(
      future: client
          .getProfileFromUserId(userId)
          .catchError((_) => Profile(userId: userId)),
      builder: (context, snapshot) => Avatar(
        mxContent: snapshot.data?.avatarUrl,
        name: name,
        size: size,
        client: client,
        backgroundColor: Nyfa.toneFor(userId),
        textColor: Nyfa.paper,
        fontFamily: Nyfa.display,
      ),
    );
  }
}
