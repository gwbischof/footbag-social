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

/// "Illegal, or someone at risk". The one colour on this screen that is not
/// the club's: urgency is a state, not a brand, and green would say "go".
/// 6.0:1 on the ground.
const _urgent = Color(0xFFFF7A66);

/// Reported posts and comments, grouped by what was reported.
///
/// Five reports of one post are one decision, so they arrive as one item
/// carrying all five reasons. Illegal sorts first; the server does the
/// ordering so every moderator sees the same queue.
class ModQueue extends StatefulWidget {
  const ModQueue({super.key});

  @override
  State<ModQueue> createState() => _ModQueueState();
}

class _ModQueueState extends State<ModQueue> {
  String state = 'open';
  List<FootbagQueueItem>? items;
  Object? error;

  /// Report ids with a decision in flight, so a double tap cannot send two.
  final busy = <int>{};

  Client get _client => Matrix.of(context).client;

  late final actions = AppPostActions(
    context,
    onRemoved: (_) => unawaited(load()),
    onReplaced: (_) => unawaited(load()),
  );

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final loaded = await _client.fetchModQueue(state: state);
      if (!mounted) return;
      setState(() {
        items = loaded;
        error = null;
      });
    } catch (e, s) {
      Logs().w('Loading the mod queue failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  void setState_(String value) {
    setState(() {
      state = value;
      items = null;
    });
    unawaited(load());
  }

  Future<void> decide(FootbagQueueItem item, {required bool remove}) async {
    final id = item.reportIds.first;
    setState(() => busy.add(id));
    try {
      await _client.resolveContentReport(id, remove: remove);
      // Out of the open list at once; the next load confirms it.
      if (mounted) setState(() => items?.remove(item));
    } catch (e) {
      Logs().w('Resolving a report failed', e);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> restore(FootbagQueueItem item) async {
    final post = item.post;
    if (post == null) return;
    try {
      await _client.restorePost(post.id);
      await load();
    } catch (e) {
      Logs().w('Restoring a post failed', e);
    }
  }

  String _reason(L10n l10n, String r) => switch (r) {
    'spam' => l10n.reasonSpam,
    'harassment' => l10n.reasonHarassment,
    'not_footbag' => l10n.reasonNotFootbag,
    'not_theirs' => l10n.reasonNotTheirs,
    'illegal' => l10n.reasonIllegal,
    _ => r,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = items;

    return Scaffold(
      key: const Key('ModQueueScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.modQueue),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: feedMaxWidth),
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    for (final s in <({String value, String label})>[
                      (value: 'open', label: l10n.queueOpen),
                      (value: 'actioned', label: l10n.queueActioned),
                    ])
                      FeedChip(
                        key: Key('Queue_${s.value}'),
                        label: s.label,
                        selected: state == s.value,
                        onTap: () => setState_(s.value),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: load,
                  backgroundColor: Nyfa.raised,
                  color: Nyfa.green,
                  child: error != null && list == null
                      ? FeedProblem(error: error!, onRetry: load)
                      : list == null
                      ? ListView(children: const [PostSkeleton()])
                      : list.isEmpty
                      ? ListView(children: [FeedEmpty(title: l10n.queueEmpty)])
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) => _Item(
                            item: list[i],
                            reasonLabel: (r) => _reason(l10n, r),
                            actions: actions,
                            busy: busy.contains(list[i].reportIds.first),
                            onRemove: () => decide(list[i], remove: true),
                            onKeep: () => decide(list[i], remove: false),
                            onRestore: () => restore(list[i]),
                          ),
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

class _Item extends StatelessWidget {
  final FootbagQueueItem item;
  final String Function(String) reasonLabel;
  final PostActions actions;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback onKeep;
  final VoidCallback onRestore;

  const _Item({
    required this.item,
    required this.reasonLabel,
    required this.actions,
    required this.busy,
    required this.onRemove,
    required this.onKeep,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final open = item.state == 'open';
    final reasons = item.reasons.toSet().toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          // The urgent stripe: what needs looking at first reads at a glance,
          // without reading a word.
          left: BorderSide(
            color: item.isUrgent ? _urgent : Nyfa.rule,
            width: 3,
          ),
          top: const BorderSide(color: Nyfa.rule),
          bottom: const BorderSide(color: Nyfa.rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Nyfa.raised,
            padding: const EdgeInsets.fromLTRB(17, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in reasons)
                            Container(
                              padding: const EdgeInsets.fromLTRB(7, 3, 7, 1),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: r == 'illegal' ? _urgent : Nyfa.muted,
                                ),
                              ),
                              child: Text(
                                reasonLabel(r).toUpperCase(),
                                style: Nyfa.eyebrow.copyWith(
                                  fontSize: 13,
                                  color: r == 'illegal' ? _urgent : Nyfa.paper,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      l10n.reportCount(item.reportIds.length).toUpperCase(),
                      style: Nyfa.eyebrow,
                    ),
                  ],
                ),
                for (final note in item.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '“$note”',
                      style: Nyfa.bodyMuted.copyWith(fontSize: 14),
                    ),
                  ),
                if (!open && item.actionedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${item.state == 'removed' ? l10n.removeContent : l10n.keepContent}'
                      '  ·  ${l10n.decidedBy(item.actionedBy!)}',
                      style: Nyfa.bodyMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (item.post != null)
            PostCard(post: item.post!, actions: actions)
          else if (item.comment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${item.comment!.authorName}  ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: item.comment!.body),
                  ],
                ),
                style: Nyfa.bodyText,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: open
                ? Row(
                    children: [
                      Expanded(
                        child: NyfaForm.action(
                          key: Key('Remove_${item.reportIds.first}'),
                          label: l10n.removeContent,
                          onPressed: busy ? null : onRemove,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NyfaForm.action(
                          key: Key('Keep_${item.reportIds.first}'),
                          label: l10n.keepContent,
                          filled: false,
                          onPressed: busy ? null : onKeep,
                        ),
                      ),
                    ],
                  )
                : item.state == 'removed' &&
                      item.post != null &&
                      item.post!.removed
                ? NyfaForm.action(
                    label: l10n.restoreContent,
                    filled: false,
                    onPressed: onRestore,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
