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
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Suggested tricks, for moderators: approve into everyone's dictionary, or
/// leave with the author.
///
/// Each shows what it claims to be built from, because the question is
/// whether the name fits the parts. There is no delete: the author's reports
/// may already use it.
class PendingTricksPage extends StatefulWidget {
  const PendingTricksPage({super.key});

  @override
  PendingTricksPageState createState() => PendingTricksPageState();
}

class PendingTricksPageState extends State<PendingTricksPage> {
  List<FootbagPendingEntry>? pending;
  Object? error;

  Client get client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final list = await client.fetchPendingEntries();
      if (mounted) {
        setState(() {
          pending = list;
          error = null;
        });
      }
    } catch (e, s) {
      Logs().w('Loading suggested tricks failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> decide(FootbagPendingEntry p, {required bool approve}) async {
    final messenger = ScaffoldMessenger.of(context);
    final slug = p.entry.slug;
    setState(
      () => pending = pending?.where((x) => x.entry.slug != slug).toList(),
    );
    try {
      await (approve
          ? client.approveEntry(slug)
          : client.keepEntryPrivate(slug));
    } on FootbagApiException catch (e) {
      // "Approve what it is built from first" -- put it back and say so.
      messenger.showSnackBar(SnackBar(content: Text(e.detail)));
      if (mounted) unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = pending;
    return Scaffold(
      key: const Key('PendingTricksScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.tricksQueue),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: load,
            backgroundColor: Nyfa.raised,
            color: Nyfa.green,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(l10n.keepPrivateExplain, style: Nyfa.bodyMuted),
                ),
                if (list == null && error != null)
                  FeedProblem(error: error!, onRetry: load)
                else if (list == null)
                  const RowsSkeleton(rows: 3)
                else if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.tricksPendingEmpty,
                      textAlign: TextAlign.center,
                      style: Nyfa.bodyMuted,
                    ),
                  )
                else
                  for (final p in list) _PendingRow(state: this, pending: p),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final PendingTricksPageState state;
  final FootbagPendingEntry pending;

  const _PendingRow({required this.state, required this.pending});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final e = pending.entry;
    final kind = switch (e.kind) {
      'composite' => l10n.kindComposite,
      'string' => l10n.kindString,
      _ => l10n.kindTrick,
    };
    // What it claims to be: "Paradox + Mirage", or the steps in order.
    final parts = switch (e.kind) {
      'composite' => [...pending.modifierNames, ?pending.baseName].join(' + '),
      'string' => pending.stepNames.join(' > '),
      _ => null,
    };
    return Container(
      key: Key('PendingTrick_${e.slug}'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kind, style: Nyfa.eyebrow),
          const SizedBox(height: 4),
          Text(e.name, style: Nyfa.heading.copyWith(fontSize: 20)),
          if (parts != null && parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(parts, style: Nyfa.bodyText),
            ),
          if (e.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e.description, style: Nyfa.bodyMuted),
            ),
          if (e.aka.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.alsoCalled(e.aka.join(', ')),
                style: Nyfa.bodyMuted.copyWith(fontSize: 13),
              ),
            ),
          if (pending.suggestedByName != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.suggestedBy(pending.suggestedByName!),
                style: Nyfa.bodyMuted.copyWith(fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SmallButton(
                key: Key('KeepPrivate_${e.slug}'),
                label: l10n.keepPrivate,
                onPressed: () => state.decide(pending, approve: false),
              ),
              const SizedBox(width: 8),
              SmallButton(
                key: Key('ApproveTrick_${e.slug}'),
                label: l10n.approvePlace,
                accent: true,
                onPressed: () => state.decide(pending, approve: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
