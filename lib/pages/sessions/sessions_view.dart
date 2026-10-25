// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/sessions/sessions.dart';
import 'package:footbag_network/utils/date_time_extension.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Sessions, set like a scoreboard.
///
/// The running session is the hero and everything else is deliberately quiet:
/// hairline rules and dense rows rather than cards, so the only thing that
/// draws the eye is the clock. "Not everything is a card" is the whole layout
/// decision here.
class SessionsView extends StatelessWidget {
  final SessionsController controller;

  const SessionsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final running = controller.running;

    return Scaffold(
      key: const Key('SessionsScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.sessions),
      // One action, swapped by state rather than sitting beside its
      // alternative: you cannot start a session while one is running, so
      // offering both would be offering a dead button.
      floatingActionButton: running != null
          ? null
          : FloatingActionButton.extended(
              key: const Key('StartSessionButton'),
              onPressed: controller.busy ? null : controller.startAction,
              backgroundColor: Nyfa.green,
              foregroundColor: Nyfa.ground,
              shape: const RoundedRectangleBorder(),
              icon: controller.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Nyfa.ground,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                l10n.startSession.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 17,
                  letterSpacing: 1.1,
                ),
              ),
            ),
      body: MaxWidthBody(
        withScrolling: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          backgroundColor: Nyfa.raised,
          color: Nyfa.green,
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = L10n.of(context);

    if (controller.error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: l10n.oopsSomethingWentWrong,
        // Localised, not '$error': the raw form shows people
        // "ClientException with SocketException: Failed host lookup".
        body: controller.error!.toLocalizedString(context),
        actionLabel: l10n.retry,
        onAction: controller.load,
      );
    }
    if (controller.sessions == null) {
      return const Center(
        child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
      );
    }

    final running = controller.running;
    final upcoming = controller.upcoming;
    final past = controller.past;

    if (running == null && upcoming.isEmpty && past.isEmpty) {
      return _Message(
        icon: Icons.sports_handball_rounded,
        title: l10n.noSessionsYet,
        body: l10n.noSessionsYetBody,
      );
    }

    return ListView(
      // Always scrollable, so pull-to-refresh works even when one card is the
      // whole list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (running != null)
          _Scoreboard(controller: controller, session: running),
        if (upcoming.isNotEmpty) _SectionLabel(l10n.upcomingSessions),
        ...upcoming.map(
          (s) => _SessionRow(key: ValueKey('up_${s.id}'), session: s),
        ),
        if (past.isNotEmpty) _SectionLabel(l10n.pastSessions),
        ...past.map(
          (s) => _SessionRow(
            key: ValueKey('past_${s.id}'),
            session: s,
            onTap: () async {
              final filed = await context.push<bool>(
                '/rooms/sessions/${s.id}/report',
              );
              // Only reload when something was filed; backing out should not
              // cost a request.
              if (filed == true) await controller.load();
            },
          ),
        ),
      ],
    );
  }
}

/// The running session: the one loud thing on the screen.
class _Scoreboard extends StatelessWidget {
  final SessionsController controller;
  final FootbagSession session;

  const _Scoreboard({required this.controller, required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final left = controller.minutesUntilCheckInDue;

    return Container(
      key: const Key('RunningSessionCard'),
      decoration: const BoxDecoration(
        color: Nyfa.raised,
        border: Border(
          // A single green edge rather than a filled green panel: the accent
          // marks the live session without competing with the clock.
          left: BorderSide(color: Nyfa.green, width: 3),
          bottom: BorderSide(color: Nyfa.rule),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(17, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LiveDot(),
              const SizedBox(width: 8),
              Text(l10n.sessionRunning.toUpperCase(), style: Nyfa.eyebrow),
            ],
          ),
          const SizedBox(height: 10),
          // Semantics, because to a screen reader the clock is otherwise a
          // string of bare digits.
          Semantics(
            label: l10n.sessionRunning,
            value: _spoken(l10n, session.elapsedNow),
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_hms(session.elapsedNow), style: Nyfa.clock),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.name}  ·  ${_typeLabel(l10n, session.type)}',
            style: Nyfa.bodyMuted,
          ),
          const SizedBox(height: 16),
          // Wrap, not Row: at 360px with a large text scale these two would
          // otherwise overflow side by side.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Action(
                key: const Key('CheckInButton'),
                label: left == null
                    ? l10n.stillHere
                    : l10n.checkInDueIn(left),
                filled: true,
                busy: controller.busy,
                onPressed: () => controller.checkInAction(session.id),
              ),
              _Action(
                key: const Key('StopSessionButton'),
                label: l10n.stopSession,
                filled: false,
                busy: controller.busy,
                onPressed: () => controller.stopAction(session.id),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(l10n.checkInExplainer, style: Nyfa.bodyMuted),
        ],
      ),
    );
  }

  String _spoken(L10n l10n, Duration d) =>
      '${d.inHours} h ${d.inMinutes % 60} min';
}

/// A one-second pulse on the live marker.
///
/// The only motion on either screen. The card already repaints every second
/// for the clock, so this costs nothing, and it is the thing that makes
/// "running" read as a state rather than a label.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final onBeat = DateTime.now().second.isEven;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Nyfa.green.withValues(alpha: onBeat ? 1 : 0.35),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback onPressed;

  const _Action({
    required this.label,
    required this.filled,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: Nyfa.display,
      fontSize: 17,
      letterSpacing: 1.1,
      color: filled ? Nyfa.ground : Nyfa.paper,
    );
    return SizedBox(
      height: 48, // A real tap target.
      child: filled
          ? FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Nyfa.green,
                disabledBackgroundColor: Nyfa.green.withValues(alpha: 0.4),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(label.toUpperCase(), style: style),
            )
          : OutlinedButton(
              onPressed: busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Nyfa.rule),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(label.toUpperCase(), style: style),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
    child: Text(text.toUpperCase(), style: Nyfa.eyebrow),
  );
}

/// A session as a dense row. Hairline-separated, no card.
class _SessionRow extends StatelessWidget {
  final FootbagSession session;
  final VoidCallback? onTap;

  const _SessionRow({required this.session, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final when = session.startedAt ?? session.scheduledAt;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name.toUpperCase(),
                      style: Nyfa.heading.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _typeLabel(l10n, session.type),
                        if (when != null) when.localizedTime(context),
                        if (session.isUpcoming) l10n.sessionScheduled,
                      ].join('  ·  '),
                      style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (session.duration != null) ...[
                const SizedBox(width: 12),
                Text(
                  _short(session.duration!),
                  style: const TextStyle(
                    fontFamily: Nyfa.display,
                    color: Nyfa.paper,
                    fontSize: 19,
                    letterSpacing: 0.8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Nyfa.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty and error states. An empty screen is an invitation, not a report of
/// nothing — so it gets the same care as the loaded one.
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 32),
    children: [
      const SizedBox(height: 88),
      Icon(icon, size: 44, color: Nyfa.muted),
      const SizedBox(height: 18),
      Text(title.toUpperCase(), textAlign: TextAlign.center, style: Nyfa.heading),
      const SizedBox(height: 8),
      Text(body, textAlign: TextAlign.center, style: Nyfa.bodyMuted),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 20),
        Center(
          child: _Action(
            label: actionLabel!,
            filled: false,
            busy: false,
            onPressed: () => onAction!(),
          ),
        ),
      ],
    ],
  );
}

String _typeLabel(L10n l10n, String type) => switch (type) {
  'casual' => l10n.sessionTypeCasual,
  'kicking' => l10n.sessionTypeKicking,
  'freestyle' => l10n.sessionTypeFreestyle,
  'net' => l10n.sessionTypeNet,
  'stitching' => l10n.sessionTypeStitching,
  // A type this build does not know about is still worth showing as itself
  // rather than as a blank.
  _ => type,
};

String _two(int n) => n.toString().padLeft(2, '0');

String _hms(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

/// Minutes below an hour, hours above. "47 MIN" and "1H 12M" both read faster
/// than a zero-padded clock in a list.
String _short(Duration d) =>
    d.inHours > 0 ? '${d.inHours}H ${d.inMinutes % 60}M' : '${d.inMinutes} MIN';
