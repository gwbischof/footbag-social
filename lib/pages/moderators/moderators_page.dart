// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Who moderates the feed, for admins to appoint and stand down.
///
/// Each moderator's count of decisions is shown, as the doc asks: two people
/// with removal powers need a record of who did what.
class ModeratorsPage extends StatefulWidget {
  const ModeratorsPage({super.key});

  @override
  ModeratorsPageState createState() => ModeratorsPageState();
}

class ModeratorsPageState extends State<ModeratorsPage> {
  List<FootbagModerator>? moderators;
  Object? error;

  Client get client => Matrix.of(context).client;

  /// Overridden by the preview harness.
  String get me => client.userID ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final list = await client.fetchModerators();
      if (mounted) {
        setState(() {
          moderators = list;
          error = null;
        });
      }
    } catch (e, s) {
      Logs().w('Loading moderators failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> appoint() async {
    await showInviteSheet(
      context,
      client: client,
      already: {...?moderators?.map((m) => m.userId)},
      add: client.appointModerator,
    );
    if (mounted) unawaited(load());
  }

  Future<void> standDown(FootbagModerator m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await client.dismissModerator(m.userId);
      if (mounted) unawaited(load());
    } on FootbagApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.detail)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = moderators;
    return Scaffold(
      key: const Key('ModeratorsScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.moderators),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: NyfaForm.action(
              key: const Key('AppointModerator'),
              label: l10n.appointModerator,
              onPressed: appoint,
            ),
          ),
        ),
      ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Text(l10n.moderatorsExplain, style: Nyfa.bodyMuted),
                ),
                if (list == null && error != null)
                  FeedProblem(error: error!, onRetry: load)
                else if (list == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Nyfa.green,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  for (final m in list)
                    PersonRow(
                      key: Key('Moderator_${m.userId}'),
                      userId: m.userId,
                      name: m.name,
                      trailing: [
                        Text(
                          (m.isAdmin
                                  ? l10n.adminRole
                                  : l10n.moderatorActions(m.actions))
                              .toUpperCase(),
                          style: Nyfa.eyebrow.copyWith(
                            fontSize: 13,
                            color: m.isAdmin ? Nyfa.green : Nyfa.muted,
                          ),
                        ),
                        // Not yourself: the last admin standing themselves
                        // down would leave nobody able to appoint anyone.
                        if (m.userId != me)
                          IconButton(
                            tooltip: l10n.standDown,
                            onPressed: () => standDown(m),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Nyfa.muted,
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
