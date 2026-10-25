// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/sessions/sessions.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class SessionsView extends StatelessWidget {
  final SessionsController controller;

  const SessionsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final running = controller.running;

    return Scaffold(
      key: const Key('SessionsScaffold'),
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(l10n.sessions),
      ),
      // One action, and it changes with the state rather than sitting beside
      // it: you cannot start a second session while one is running, so
      // offering both would be offering a dead button.
      floatingActionButton: running == null
          ? FloatingActionButton.extended(
              key: const Key('StartSessionButton'),
              onPressed: controller.startAction,
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(l10n.startSession),
            )
          : null,
      body: MaxWidthBody(
        withScrolling: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    if (controller.error != null) {
      return _centred(
        context,
        icon: Icons.error_outline,
        title: l10n.oopsSomethingWentWrong,
        body: '${controller.error}',
      );
    }
    if (controller.sessions == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final running = controller.running;
    final past = controller.past;

    if (running == null && past.isEmpty) {
      // An empty screen is an invitation, not a report of nothing.
      return _centred(
        context,
        icon: Icons.sports_handball_outlined,
        title: l10n.noSessionsYet,
        body: l10n.noSessionsYetBody,
      );
    }

    return ListView(
      // Always scrollable, so pull-to-refresh works even when one card is the
      // whole list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (running != null) _RunningCard(controller: controller, session: running),
        if (past.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              l10n.pastSessions,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...past.map((s) => _PastTile(session: s)),
      ],
    );
  }

  Widget _centred(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            spacing: 8,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The running session: a clock, a check-in, and a way to stop.
class _RunningCard extends StatelessWidget {
  final SessionsController controller;
  final FootbagSession session;

  const _RunningCard({required this.controller, required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Card(
      key: const Key('RunningSessionCard'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Text(
              l10n.sessionRunning.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                letterSpacing: 1.1,
              ),
            ),
            Text(
              _hms(session.elapsedNow),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                // Digits that do not jitter as the seconds change.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${session.name} · ${session.type}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('CheckInButton'),
                    onPressed: () => controller.checkInAction(session.id),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.stillHere),
                  ),
                ),
                OutlinedButton(
                  key: const Key('StopSessionButton'),
                  onPressed: () => controller.stopAction(session.id),
                  child: Text(l10n.stopSession),
                ),
              ],
            ),
            Text(
              l10n.checkInExplainer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastTile extends StatelessWidget {
  final FootbagSession session;

  const _PastTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = session.startedAt ?? session.scheduledAt;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.sports_handball_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(session.name),
      subtitle: Text(
        [
          session.type,
          if (when != null) _day(when),
        ].join(' · '),
      ),
      trailing: session.duration == null
          ? null
          : Text(
              _short(session.duration!),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hms(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

/// Minutes below an hour, hours above. "47 min" and "1h 12m" both read faster
/// than a zero-padded clock in a list.
String _short(Duration d) =>
    d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes} min';

String _day(DateTime when) =>
    '${when.year}-${_two(when.month)}-${_two(when.day)}';
