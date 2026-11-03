// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The most goals a session takes. The API's limit too; the copy asks for
/// three, because the report reads them back as a checklist.
const maxGoals = 5;

/// Why an idea is offered, as a sentence. Null when the heading already
/// says it -- a favourite under Favourites needs no reason.
String? ideaReason(L10n l10n, FootbagIdea idea) => switch (idea.rule) {
  'next_step' => l10n.ideaNextStep(idea.becauseName ?? ''),
  'string_ready' => l10n.ideaStringReady,
  'string_again' => l10n.ideaStringAgain,
  'ease_off' => l10n.ideaEaseOff(idea.becauseName ?? '', idea.count ?? 0),
  'unmet' => l10n.ideaUnmet(idea.count ?? 1),
  'last_session' => l10n.ideaLastSession,
  _ => null,
};

/// Plan, before do: a few things to work on in one session.
///
/// Opened straight after Start -- never before it, so Start stays one tap --
/// and from the session page. Every tap saves, so there is nothing to lose
/// by leaving, and the one button says Skip until something is picked.
class GoalsPage extends StatefulWidget {
  final int sessionId;

  const GoalsPage({required this.sessionId, super.key});

  @override
  GoalsPageState createState() => GoalsPageState();
}

class GoalsPageState extends State<GoalsPage> {
  List<FootbagGoal>? goals;
  List<FootbagIdea> ideas = const [];
  Object? error;

  Client get client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        client.fetchGoals(widget.sessionId),
        client.fetchGoalIdeas(widget.sessionId),
      ]);
      if (!mounted) return;
      setState(() {
        goals = results[0] as List<FootbagGoal>;
        ideas = results[1] as List<FootbagIdea>;
        error = null;
      });
    } catch (e, s) {
      Logs().w('Loading goals failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  /// Overridden by the preview harness.
  Future<List<FootbagGoal>> save(List<String> slugs) =>
      client.setGoals(widget.sessionId, slugs);

  /// Change the list, show it at once, and put it back if the save fails.
  Future<void> _change(List<FootbagGoal> next) async {
    final before = goals;
    setState(() => goals = next);
    try {
      final saved = await save([for (final g in next) g.entrySlug]);
      if (mounted) setState(() => goals = saved);
    } catch (e) {
      Logs().w('Saving goals failed', e);
      if (!mounted) return;
      setState(() => goals = before);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).oopsSomethingWentWrong)),
      );
    }
  }

  bool get full => (goals?.length ?? 0) >= maxGoals;

  void add(FootbagIdea idea) {
    if (full) return;
    unawaited(
      _change([
        ...?goals,
        FootbagGoal(entrySlug: idea.entrySlug, name: idea.name),
      ]),
    );
  }

  void remove(FootbagGoal goal) => unawaited(
    _change([...?goals?.where((g) => g.entrySlug != goal.entrySlug)]),
  );

  Future<void> search() async {
    final picked = await context.push<List<String>>(
      '/rooms/dash/favourites/add',
      extra: {...?goals?.map((g) => g.entrySlug)},
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final room = maxGoals - (goals?.length ?? 0);
    // Names come back from the save; the slug stands in for a moment.
    await _change([
      ...?goals,
      for (final slug in picked.take(room))
        FootbagGoal(entrySlug: slug, name: slug),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = goals;
    final chosen = {...?list?.map((g) => g.entrySlug)};
    final open = ideas.where((i) => !chosen.contains(i.entrySlug)).toList();

    List<Widget> section(String source, String title) {
      final rows = open.where((i) => i.source == source).toList();
      if (rows.isEmpty) return const [];
      return [
        NyfaForm.section(title),
        for (final i in rows)
          _Row(
            key: Key('Idea_${i.entrySlug}'),
            title: i.name,
            subtitle: ideaReason(l10n, i),
            icon: Icons.add,
            iconColor: full ? Nyfa.rule : Nyfa.green,
            onTap: full ? null : () => add(i),
          ),
      ];
    }

    return Scaffold(
      key: const Key('GoalsScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.goals),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: NyfaForm.action(
              key: const Key('GoalsDone'),
              label: chosen.isEmpty ? l10n.skip : l10n.done,
              filled: chosen.isNotEmpty,
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: list == null
              ? (error != null
                    ? FeedProblem(error: error!, onRetry: load)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Nyfa.green,
                          strokeWidth: 2,
                        ),
                      ))
              : ListView(
                  key: const Key('GoalsList'),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Text(l10n.goalsExplain, style: Nyfa.bodyMuted),
                    ),
                    NyfaForm.section(l10n.yourGoals),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(l10n.noGoalsYet, style: Nyfa.bodyText),
                      )
                    else
                      for (final g in list)
                        _Row(
                          key: Key('Goal_${g.entrySlug}'),
                          title: g.name,
                          icon: Icons.close,
                          iconColor: Nyfa.muted,
                          leading: const Icon(
                            Icons.flag_outlined,
                            size: 20,
                            color: Nyfa.green,
                          ),
                          onTap: () => remove(g),
                        ),
                    if (full)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Text(l10n.goalsFull, style: Nyfa.bodyMuted),
                      ),
                    ...section('last', l10n.fromLastTime),
                    ...section('next', l10n.tryNext),
                    ...section('favourite', l10n.favourites),
                    const SizedBox(height: 12),
                    _Row(
                      key: const Key('GoalsSearch'),
                      title: l10n.searchAllTricks,
                      icon: Icons.chevron_right_rounded,
                      iconColor: Nyfa.muted,
                      leading: const Icon(
                        Icons.search,
                        size: 20,
                        color: Nyfa.muted,
                      ),
                      onTap: full ? null : search,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A hairline-ruled row: a name, an optional reason, and one action.
class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _Row({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.subtitle,
    this.leading,
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Nyfa.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    ),
  );
}
