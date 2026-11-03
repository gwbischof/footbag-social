// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../widgets/matrix.dart';
import 'settings_ignore_list_view.dart';

/// Everyone you have blocked, and the way back from it.
///
/// Chat's own "block" buttons land here with the person filled in, so they
/// go through the same confirm as the feed and profiles: one block, covering
/// the feed, sessions, Discover and chat. FluffyChat's version asked you to
/// type a Matrix ID, which nobody using this app should ever see.
class SettingsIgnoreList extends StatefulWidget {
  final String? initialUserId;

  const SettingsIgnoreList({super.key, this.initialUserId});

  @override
  SettingsIgnoreListController createState() => SettingsIgnoreListController();
}

class SettingsIgnoreListController extends State<SettingsIgnoreList> {
  List<FootbagPlayer>? blocks;
  Object? error;

  Client get _client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    final pending = widget.initialUserId;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _block(pending));
    } else {
      unawaited(load());
    }
  }

  Future<void> load() async {
    try {
      final list = await _client.fetchBlocks();
      if (mounted) setState(() => blocks = list);
    } catch (e, s) {
      Logs().w('Loading blocks failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _block(String userId) async {
    final profile = await _client
        .getProfileFromUserId(userId)
        .catchError((_) => Profile(userId: userId));
    if (!mounted) return;
    await confirmBlock(
      context,
      userId,
      profile.displayName ?? userId.localpart ?? userId,
    );
    await load();
  }

  Future<void> unblock(FootbagPlayer p) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    try {
      await _client.unblockPlayer(p.userId);
      setState(() => blocks?.remove(p));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.playerUnblocked(p.displayName))),
      );
    } catch (e) {
      Logs().w('Unblocking failed', e);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsIgnoreListView(this);
}
