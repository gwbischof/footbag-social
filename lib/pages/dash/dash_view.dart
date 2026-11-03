// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/dash/dash.dart';
import 'package:footbag_network/pages/goals/goals_page.dart';
import 'package:footbag_network/utils/date_time_extension.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/footbag_map.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Dash, set like a club scoreboard.
class DashView extends StatelessWidget {
  final DashController controller;

  const DashView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('DashScaffold'),
      backgroundColor: Nyfa.ground,
      // Dash carries the wordmark and the avatar, since it is the entry point.
      // Other screens get a plain title.
      appBar: _DashBar(controller: controller),
      bottomNavigationBar: FootbagNavBar(
        current: FootbagTab.dash,
        // Nothing to start while one is running, so the centre action goes
        // quiet rather than offering a tap that would be refused.
        onStart: controller.running == null && !controller.busy
            ? controller.startAction
            : null,
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
      // A rejected token is the one failure a person can act on, and the
      // action is specific. Reporting it as "no connection to the server" --
      // which is what the generic localizer does with an unknown exception --
      // sends someone to check their wifi over an expired session.
      final e = controller.error;
      final signedOut = e is FootbagApiException && e.isNotSignedIn;
      return _Centred(
        icon: signedOut ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
        title: signedOut ? l10n.signedOutAgain : l10n.oopsSomethingWentWrong,
        body: signedOut
            ? l10n.signedOutAgainBody
            : controller.error!.toLocalizedString(context),
        actionLabel: signedOut ? l10n.signIn : l10n.retry,
        onAction: signedOut ? controller.signOutAction : controller.load,
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        _Shortcuts(canModerate: controller.canModerate),

        if (running != null)
          _Scoreboard(controller: controller, session: running)
        else
          _EmptyInvitation(controller: controller),

        if (controller.tryNext.isNotEmpty) ...[
          _SectionLabel(l10n.tryNext),
          for (final idea in controller.tryNext)
            _IdeaRow(
              key: ValueKey('try_${idea.entrySlug}'),
              idea: idea,
              action: running != null ? l10n.addAsGoal : l10n.addToFavourites,
              onPressed: () => controller.takeIdea(idea),
            ),
        ],

        _Nearby(controller: controller),

        if (upcoming.isNotEmpty) _SectionLabel(l10n.upcomingSessions),
        ...upcoming.map(
          (s) => _SessionRow(
            key: ValueKey('up_${s.id}'),
            session: s,
            onTap: () => controller.openSession(s.id),
          ),
        ),

        if (past.isNotEmpty) _SectionLabel(l10n.yourSessions),
        ...past.map(
          (s) => _SessionRow(
            key: ValueKey('past_${s.id}'),
            session: s,
            onTap: () => controller.openSession(s.id),
          ),
        ),
      ],
    );
  }
}

/// The wordmark and the avatar.
class _DashBar extends StatelessWidget implements PreferredSizeWidget {
  final DashController controller;

  const _DashBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // A plain section title, like every tab but the front door. The Feed is
    // home now, so the masthead, the bell and the avatar live there.
    return AppBar(
      backgroundColor: Nyfa.ground,
      surfaceTintColor: Nyfa.ground,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.dash.toUpperCase(),
            style: Nyfa.heading.copyWith(fontSize: 26),
          ),
          Text(l10n.dashGreeting, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Nyfa.rule),
      ),
    );
  }
}

/// The rest of the app, named rather than drawn as icons.
///
/// These were app bar actions until four of them ran off the side of a phone.
/// Labels also solve the problem icons have here: a star, a calendar and a bar
/// chart are not obviously favourites, scheduling and rankings until you have
/// tapped each one once.
class _Shortcuts extends StatelessWidget {
  final bool canModerate;

  const _Shortcuts({required this.canModerate});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        children: [
          for (final s
              in <({String key, String label, IconData icon, String path})>[
                (
                  key: 'DashFavouritesButton',
                  label: l10n.favourites,
                  icon: Icons.star_outline_rounded,
                  path: '/rooms/dash/favourites',
                ),
                (
                  key: 'DashScheduleButton',
                  label: l10n.scheduleSession,
                  icon: Icons.calendar_today_outlined,
                  path: '/rooms/dash/schedule',
                ),
                (
                  key: 'DashRankingsButton',
                  label: l10n.rankings,
                  icon: Icons.leaderboard_outlined,
                  path: '/rooms/dash/rankings',
                ),
                if (canModerate)
                  (
                    key: 'DashModQueueButton',
                    label: l10n.modQueue,
                    icon: Icons.shield_outlined,
                    path: '/rooms/dash/mod',
                  ),
              ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: Key(s.key),
                onTap: () => context.push(s.path),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Nyfa.rule),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Row(
                      children: [
                        Icon(s.icon, size: 16, color: Nyfa.muted),
                        const SizedBox(width: 7),
                        Text(
                          s.label.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Nyfa.display,
                            fontSize: 16,
                            letterSpacing: 0.8,
                            color: Nyfa.paper,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a new player sees, and most players most of the time.
///
/// Copy straight from the doc's first-run design: name the emptiness honestly,
/// then lead with the action that works with nobody else on the platform.
class _EmptyInvitation extends StatelessWidget {
  final DashController controller;

  const _EmptyInvitation({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nothingEver = controller.past.isEmpty && controller.upcoming.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Nyfa.raised,
        border: Border(left: BorderSide(color: Nyfa.green, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only said to someone with no history. An established player in a
          // quiet week does not need to be told the map is empty.
          if (nothingEver) ...[
            Text(l10n.dashNobodyPlaying, style: Nyfa.bodyMuted),
            const SizedBox(height: 16),
          ],
          Text(l10n.dashStartYourOwn.toUpperCase(), style: Nyfa.heading),
          const SizedBox(height: 6),
          Text(l10n.dashStartYourOwnBody, style: Nyfa.bodyMuted),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('DashStartButton'),
              onPressed: controller.busy ? null : controller.startAction,
              style: FilledButton.styleFrom(
                backgroundColor: Nyfa.green,
                disabledBackgroundColor: Nyfa.rule,
                shape: const RoundedRectangleBorder(),
              ),
              icon: Icon(
                Icons.play_arrow_rounded,
                color: controller.busy ? Nyfa.muted : Nyfa.ground,
              ),
              label: Text(
                l10n.startSession.toUpperCase(),
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 17,
                  letterSpacing: 1.1,
                  color: controller.busy ? Nyfa.muted : Nyfa.ground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The running session: the one loud thing on the screen.
class _Scoreboard extends StatelessWidget {
  final DashController controller;
  final FootbagSession session;

  const _Scoreboard({required this.controller, required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final left = controller.minutesUntilCheckInDue;

    return Container(
      key: const Key('RunningSessionCard'),
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      decoration: const BoxDecoration(
        color: Nyfa.raised,
        border: Border(left: BorderSide(color: Nyfa.green, width: 3)),
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
          Semantics(
            label: l10n.sessionRunning,
            value:
                '${session.elapsedNow.inHours} h '
                '${session.elapsedNow.inMinutes % 60} min',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_hms(session.elapsedNow), style: Nyfa.clock),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_subtitle(l10n, session), style: Nyfa.bodyMuted),
          const SizedBox(height: 12),
          // What you came to work on, so it is in front of you mid-session.
          InkWell(
            key: const Key('RunningGoals'),
            onTap: () => controller.editGoals(session.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 18, color: Nyfa.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.runningGoals.isEmpty
                          ? l10n.setGoals
                          : '${l10n.workingOn}: '
                                '${controller.runningGoals.map((g) => g.name).join(', ')}',
                      style: Nyfa.bodyText.copyWith(
                        color: controller.runningGoals.isEmpty
                            ? Nyfa.green
                            : Nyfa.paper,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Nyfa.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Action(
                key: const Key('CheckInButton'),
                label: left == null ? l10n.stillHere : l10n.checkInDueIn(left),
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
}

/// A one-second pulse on the live marker. The card already repaints every
/// second for the clock, so this costs nothing.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 900),
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Nyfa.green.withValues(
        alpha: DateTime.now().second.isEven ? 1 : 0.35,
      ),
      shape: BoxShape.circle,
    ),
  );
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
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Nyfa.green,
                disabledBackgroundColor: Nyfa.rule,
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
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
    child: Text(text.toUpperCase(), style: Nyfa.eyebrow),
  );
}

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
                        if (!_nameCarriesType(l10n, session))
                          _typeLabel(l10n, session.type),
                        if (when != null) when.localizedTime(context),
                        if (session.isUpcoming) l10n.sessionScheduled,
                        if (session.isRunning && !session.isHost)
                          l10n.sessionLive,
                        if (!session.isHost && session.hostName != null)
                          l10n.hostedBy(session.hostName!),
                        if (session.myState == 'requested') l10n.requestSent,
                      ].join('  ·  '),
                      style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (session.isHost &&
                  (session.requests?.isNotEmpty ?? false)) ...[
                const SizedBox(width: 12),
                // Requests waiting on the host. There is no notification
                // inbox yet, so this badge is how a host finds out.
                Container(
                  padding: const EdgeInsets.fromLTRB(7, 3, 7, 1),
                  color: Nyfa.green,
                  child: Text(
                    l10n
                        .sessionRequestsBadge(session.requests!.length)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontFamily: Nyfa.display,
                      fontSize: 13,
                      letterSpacing: 1,
                      color: Nyfa.ground,
                    ),
                  ),
                ),
              ],
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

class _Centred extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _Centred({
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
      const SizedBox(height: 72),
      Icon(icon, size: 44, color: Nyfa.muted),
      const SizedBox(height: 18),
      Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: Nyfa.heading,
      ),
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

/// Whether the session's name already opens with its type.
///
/// A session nobody named is called "Freestyle · Sat 25 Oct", so printing the
/// type beside it gives "Freestyle · Sat 25 Oct · Freestyle". The type still
/// earns its place on a session someone named themselves.
bool _nameCarriesType(L10n l10n, FootbagSession session) => session.name
    .toLowerCase()
    .startsWith(_typeLabel(l10n, session.type).toLowerCase());

String _subtitle(L10n l10n, FootbagSession session) =>
    _nameCarriesType(l10n, session)
    ? session.name
    : '${session.name}  ·  ${_typeLabel(l10n, session.type)}';

String _typeLabel(L10n l10n, String type) => switch (type) {
  'casual' => l10n.sessionTypeCasual,
  'kicking' => l10n.sessionTypeKicking,
  'freestyle' => l10n.sessionTypeFreestyle,
  'net' => l10n.sessionTypeNet,
  'stitching' => l10n.sessionTypeStitching,
  _ => type,
};

String _two(int n) => n.toString().padLeft(2, '0');

String _hms(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

String _short(Duration d) =>
    d.inHours > 0 ? '${d.inHours}H ${d.inMinutes % 60}M' : '${d.inMinutes} MIN';

/// Playing near you: sessions running now, as circles on a map.
///
/// Before the player has shared a location, a single quiet button rather
/// than a permission prompt on open. Afterwards the map, honest when empty:
/// early on, nobody nearby is the common case and saying so beats hiding it.
class _Nearby extends StatelessWidget {
  final DashController controller;

  const _Nearby({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final here = controller.here;
    final nearby = controller.nearby;

    if (here == null || nearby == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('ShowNearMe'),
            onPressed: () => controller.loadNearby(ask: true),
            style: TextButton.styleFrom(
              foregroundColor: Nyfa.green,
              minimumSize: const Size(0, 48),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.near_me_outlined, size: 18),
            label: Text(
              l10n.showNearMe,
              style: Nyfa.bodyText.copyWith(color: Nyfa.green),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.playingNearYou),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 180,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
              child: FootbagMap(
                key: const Key('DashNearbyMap'),
                areas: [for (final s in nearby) s.area!],
                you: here,
                interactive: true,
                onAreaTap: (i) => controller.openSession(nearby[i].id),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            nearby.isEmpty
                ? l10n.nobodyPlayingNear
                : l10n.nearbySessionsExplain,
            style: Nyfa.bodyMuted.copyWith(fontSize: 13),
          ),
        ),
        ...nearby.map(
          (s) => _SessionRow(
            key: ValueKey('near_${s.id}'),
            session: s,
            onTap: () => controller.openSession(s.id),
          ),
        ),
      ],
    );
  }
}

/// One Try next idea: what, why, and the one thing to do with it.
class _IdeaRow extends StatelessWidget {
  final FootbagIdea idea;
  final String action;
  final VoidCallback onPressed;

  const _IdeaRow({
    required this.idea,
    required this.action,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final reason = ideaReason(L10n.of(context), idea);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idea.name,
                  style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
                ),
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reason,
                      style: Nyfa.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SmallButton(label: action, accent: true, onPressed: onPressed),
        ],
      ),
    );
  }
}
