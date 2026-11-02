// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Rows of people and the invite search, shared by sessions and clubs --
/// both have a roster, requests to answer, and people to add, and they
/// should look and behave as one thing.

/// Find players by name and add them; completes when the sheet closes.
///
/// [add] does the adding -- inviting to a session, or to a club -- so the
/// sheet knows nothing about either.
Future<void> showInviteSheet(
  BuildContext context, {
  required Client client,
  required Set<String> already,
  required Future<void> Function(String userId) add,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Nyfa.ground,
  shape: const RoundedRectangleBorder(),
  builder: (_) => _InviteSheet(client: client, already: already, add: add),
);

class PersonRow extends StatelessWidget {
  final String userId;
  final String name;
  final List<Widget> trailing;

  const PersonRow({
    required this.userId,
    required this.name,
    this.trailing = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(
      '/rooms/feed/player/${Uri.encodeComponent(userId)}',
      extra: name,
    ),
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Row(
        children: [
          PlayerAvatar(userId: userId, name: name, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...trailing,
        ],
      ),
    ),
  );
}

class SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool accent;

  const SmallButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.accent = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: Nyfa.display,
      fontSize: 15,
      letterSpacing: 1,
      color: filled
          ? Nyfa.ground
          : accent
          ? Nyfa.green
          : Nyfa.paper,
    );
    const shape = RoundedRectangleBorder();
    return SizedBox(
      height: 36,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Nyfa.green,
                disabledBackgroundColor: Nyfa.rule,
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(label.toUpperCase(), style: style),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent ? Nyfa.green : Nyfa.rule),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(label.toUpperCase(), style: style),
            ),
    );
  }
}

/// The one thing you can do next, pinned to the bottom.
/// Find a player by name and add them. An invite is an approval made first.
class _InviteSheet extends StatefulWidget {
  final Client client;
  final Set<String> already;
  final Future<void> Function(String userId) add;

  const _InviteSheet({
    required this.client,
    required this.already,
    required this.add,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final query = TextEditingController();
  Timer? _debounce;
  List<FootbagPlayer>? results;
  final added = <String>{};

  Set<String> get _already => widget.already;

  @override
  void dispose() {
    _debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (text.trim().isEmpty) {
        if (mounted) setState(() => results = null);
        return;
      }
      try {
        final found = await widget.client.discoverPlayers(query: text.trim());
        if (mounted) setState(() => results = found);
      } catch (e) {
        Logs().w('Player search failed', e);
      }
    });
  }

  Future<void> _add(FootbagPlayer p) async {
    try {
      await widget.add(p.userId);
      if (mounted) setState(() => added.add(p.userId));
    } catch (e) {
      Logs().w('Invite failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final found = results;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NyfaForm.section(l10n.invitePlayers),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  key: const Key('InviteSearch'),
                  controller: query,
                  autofocus: true,
                  onChanged: _search,
                  style: Nyfa.bodyText,
                  cursorColor: Nyfa.green,
                  decoration: Nyfa.input(l10n.invitePlayersHint).copyWith(
                    prefixIcon: const Icon(Icons.search, color: Nyfa.muted),
                  ),
                ),
              ),
              Flexible(
                child: found == null
                    ? const SizedBox(height: 24)
                    : found.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        child: Text(
                          l10n.invitePlayersEmpty,
                          style: Nyfa.bodyMuted,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in found)
                            PersonRow(
                              userId: p.userId,
                              name: p.displayName,
                              trailing: [
                                if (_already.contains(p.userId) ||
                                    added.contains(p.userId))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      l10n.sessionAdded.toUpperCase(),
                                      style: Nyfa.eyebrow.copyWith(
                                        color: Nyfa.green,
                                      ),
                                    ),
                                  )
                                else
                                  SmallButton(
                                    key: Key('Invite_${p.userId}'),
                                    label: l10n.addToSession,
                                    filled: true,
                                    onPressed: () => _add(p),
                                  ),
                              ],
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: NyfaForm.action(
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  filled: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
