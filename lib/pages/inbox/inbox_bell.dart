// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/inbox/inbox_page.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The bell: the inbox, with everything unread counted -- inbox lines plus
/// unread chats.
///
/// Self-contained, so whichever screen is the front door can carry it. The
/// inbox count is asked for when the bell appears and cleared when the inbox
/// is opened (opening it marks everything read). Chat's half is read live
/// from Matrix on every sync, so a new message lights it without a request.
class InboxBell extends StatefulWidget {
  const InboxBell({super.key});

  /// Replaces the Matrix lookups in the preview harness, which has no
  /// client. Never set in the app.
  static int? previewCount;

  @override
  State<InboxBell> createState() => _InboxBellState();
}

class _InboxBellState extends State<InboxBell> {
  int _inbox = 0;

  @override
  void initState() {
    super.initState();
    if (InboxBell.previewCount == null) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final n = await Matrix.of(context).client.fetchUnreadCount();
      if (mounted && n != _inbox) setState(() => _inbox = n);
    } catch (_) {
      // A badge that fails to load is a badge that shows nothing; the inbox
      // itself still works when opened.
    }
  }

  Future<void> _open() async {
    await context.push('/rooms/dash/inbox');
    if (mounted) setState(() => _inbox = 0);
  }

  Widget _icon(BuildContext context, int count) => IconButton(
    key: const Key('InboxBell'),
    tooltip: L10n.of(context).inbox,
    onPressed: _open,
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: Nyfa.green,
      textColor: Nyfa.ground,
      textStyle: const TextStyle(
        fontFamily: Nyfa.display,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      child: const Icon(
        Icons.notifications_none_rounded,
        color: Nyfa.paper,
        size: 26,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final preview = InboxBell.previewCount;
    if (preview != null) return _icon(context, preview);
    final client = Matrix.of(context).client;
    return StreamBuilder<Object?>(
      stream: client.onSync.stream,
      builder: (context, _) {
        return _icon(context, _inbox + unreadChatCount(client));
      },
    );
  }
}
