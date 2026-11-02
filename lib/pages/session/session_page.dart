// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/session/where_sheet.dart';
import 'package:footbag_network/utils/date_time_extension.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/footbag_map.dart';
import 'package:footbag_network/widgets/future_loading_dialog.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// One session, from wherever you are standing: host, invitee, requester or
/// stranger.
///
/// **Approval is the privacy model**, and the screen is built around it. A
/// stranger sees the count but not the names, and never an exact spot -- that
/// travels in a DM with the host, so it is never in this app's database at
/// all. "Message host" is the only chat affordance a session has.
class SessionPage extends StatefulWidget {
  final int sessionId;

  const SessionPage({required this.sessionId, super.key});

  @override
  State<SessionPage> createState() => SessionPageState();
}

class SessionPageState extends State<SessionPage> {
  FootbagSession? session;
  Object? error;
  bool busy = false;

  /// Redraws the clock while the session runs, and only then.
  Timer? _tick;

  Client get _client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void adopt(FootbagSession s) => _adopt(s);

  void _adopt(FootbagSession s) {
    setState(() {
      session = s;
      error = null;
    });
    _tick?.cancel();
    if (s.isRunning) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> load() async {
    try {
      final s = await _client.fetchSession(widget.sessionId);
      if (mounted) _adopt(s);
    } catch (e, s) {
      Logs().w('Loading a session failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  /// Run one action, adopt the server's answer, and say why if it refused.
  Future<void> act(Future<FootbagSession> Function() call) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => busy = true);
    try {
      final s = await call();
      if (mounted) _adopt(s);
    } on FootbagApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> messageHost() async {
    final router = GoRouter.of(context);
    final result = await showFutureLoadingDialog(
      context: context,
      future: () => _client.startDirectChat(session!.hostId),
    );
    final roomId = result.result;
    if (roomId != null) router.go('/rooms/$roomId');
  }

  Future<void> stop() async {
    final id = widget.sessionId;
    await act(() => _client.stopSession(id));
    if (!mounted || session?.isRunning != false) return;
    // Stopping leads into reporting, as it does from Dash: it is the step
    // most likely to be skipped.
    await context.push<bool>('/rooms/dash/$id/report');
    if (mounted) unawaited(load());
  }

  Future<void> report() async {
    await context.push<bool>('/rooms/dash/${widget.sessionId}/report');
  }

  Future<void> setWhere() async {
    final s = session;
    if (s == null) return;
    final picked = await showWhereSheet(
      context,
      client: _client,
      current: s.place == null
          ? null
          : FootbagWhere.place(
              s.place!.id,
              label: s.place!.name,
              radiusMiles: _milesOf(s.area),
            ),
    );
    if (picked != null) {
      await act(() => _client.setSessionLocation(s.id, picked));
    }
  }

  void openInMaps(FootbagPlace p) => launchUrlString(
    'https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lng}#map=17/${p.lat}/${p.lng}',
    mode: LaunchMode.externalApplication,
  );

  Future<void> invite() async {
    final s = session;
    if (s == null) return;
    await showInviteSheet(
      context,
      // Passed in rather than looked up: the sheet's own context sits above
      // the page, and the client is the page's.
      client: _client,
      already: {...?s.attendees?.map((a) => a.userId), s.hostId},
      add: (id) => _client.inviteToSession(s.id, id),
    );
    if (mounted) unawaited(load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = session;

    return Scaffold(
      key: const Key('SessionScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(
        title: s?.name ?? '',
        subtitle: s == null ? null : _typeLabel(l10n, s.type),
      ),
      bottomNavigationBar: s == null ? null : _ActionBar(state: this),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: s == null
              ? (error != null
                    ? FeedProblem(error: error!, onRetry: load)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Nyfa.green,
                          strokeWidth: 2,
                        ),
                      ))
              : RefreshIndicator(
                  onRefresh: load,
                  backgroundColor: Nyfa.raised,
                  color: Nyfa.green,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _Status(session: s),
                      _Host(session: s, onMessage: messageHost),
                      if (s.club != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: InkWell(
                            key: const Key('SessionClub'),
                            onTap: () =>
                                context.push('/rooms/club/${s.club!.id}'),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.groups_outlined,
                                  size: 18,
                                  color: Nyfa.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.club!.name,
                                    style: Nyfa.bodyText.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Nyfa.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      _Where(state: this),
                      if (s.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(s.note, style: Nyfa.bodyText),
                        ),
                      _People(state: this),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

String _typeLabel(L10n l10n, String type) => switch (type) {
  'kicking' => l10n.sessionTypeKicking,
  'net' => l10n.sessionTypeNet,
  'stitching' => l10n.sessionTypeStitching,
  'casual' => l10n.sessionTypeCasual,
  _ => l10n.sessionTypeFreestyle,
};

String _hms(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:'
    '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

String _short(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0 ? '${h}H ${m.toString().padLeft(2, '0')}M' : '${m}M';
}

/// The scoreboard: live clock, start time, or final duration.
class _Status extends StatelessWidget {
  final FootbagSession session;

  const _Status({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = session;
    final live = s.isRunning;
    final ended = s.endedAt != null;

    final String label;
    final String big;
    if (live) {
      label = l10n.sessionLive;
      big = _hms(s.elapsedNow);
    } else if (ended) {
      label = l10n.sessionEnded;
      big = s.duration == null ? '—' : _short(s.duration!);
    } else {
      label = l10n.sessionScheduled;
      big =
          (s.scheduledAt ?? s.startedAt)
              ?.localizedTime(context)
              .toUpperCase() ??
          '';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      padding: const EdgeInsets.fromLTRB(17, 16, 20, 18),
      decoration: BoxDecoration(
        color: Nyfa.raised,
        border: Border(
          left: BorderSide(color: live ? Nyfa.green : Nyfa.rule, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (live) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Nyfa.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(label.toUpperCase(), style: Nyfa.eyebrow),
              const Spacer(),
              Text(
                l10n.goingCount(s.attendeeCount).toUpperCase(),
                style: Nyfa.eyebrow.copyWith(
                  color: s.attendeeCount > 0 ? Nyfa.green : Nyfa.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              big,
              style: live
                  ? Nyfa.clock
                  : Nyfa.clock.copyWith(color: Nyfa.paper, fontSize: 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _Host extends StatelessWidget {
  final FootbagSession session;
  final VoidCallback onMessage;

  const _Host({required this.session, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = session;
    final name = s.hostName ?? s.hostId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.push(
              '/rooms/feed/player/${Uri.encodeComponent(s.hostId)}',
              extra: name,
            ),
            child: PlayerAvatar(userId: s.hostId, name: name, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.isHost ? l10n.youAreHosting : l10n.hostedBy(name),
              style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (!s.isHost)
            TextButton.icon(
              key: const Key('MessageHost'),
              onPressed: onMessage,
              icon: const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Nyfa.green,
              ),
              label: Text(
                l10n.messageHost.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 16,
                  letterSpacing: 1,
                  color: Nyfa.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Who is coming, and -- for the host -- who is asking.
class _People extends StatelessWidget {
  final SessionPageState state;

  const _People({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = state.session!;
    final requests = s.requests ?? const [];
    final going = s.attendees;
    final open = s.endedAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.isHost && requests.isNotEmpty) ...[
          NyfaForm.section('${l10n.joinRequests}  ${requests.length}'),
          for (final r in requests)
            PersonRow(
              key: Key('Request_${r.userId}'),
              userId: r.userId,
              name: r.name,
              trailing: [
                SmallButton(
                  key: Key('Approve_${r.userId}'),
                  label: l10n.sessionApprove,
                  // Outlined green, not filled: a host may have several
                  // requests, and a column of filled buttons would outshout
                  // the one action the screen is about.
                  accent: true,
                  onPressed: state.busy
                      ? null
                      : () => state.act(
                          () => state._client.approveAttendee(s.id, r.userId),
                        ),
                ),
                const SizedBox(width: 8),
                SmallButton(
                  key: Key('Decline_${r.userId}'),
                  label: l10n.sessionDecline,
                  onPressed: state.busy
                      ? null
                      : () => state.act(
                          () => state._client.declineAttendee(s.id, r.userId),
                        ),
                ),
              ],
            ),
        ],
        NyfaForm.section(l10n.sessionGoing),
        if (going == null)
          // A stranger: the count is in the scoreboard, the names wait for
          // the host. Saying so beats an empty list that looks broken.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.namesAfterApproval, style: Nyfa.bodyMuted),
          )
        else if (going.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.goingCount(0), style: Nyfa.bodyMuted),
          )
        else
          for (final p in going)
            PersonRow(
              key: Key('Going_${p.userId}'),
              userId: p.userId,
              name: p.name,
              trailing: [
                if (s.isHost && open)
                  IconButton(
                    tooltip: l10n.removeAttendee,
                    onPressed: state.busy
                        ? null
                        : () => state.act(
                            () => state._client.declineAttendee(s.id, p.userId),
                          ),
                    icon: const Icon(Icons.close, size: 18, color: Nyfa.muted),
                  ),
              ],
            ),
        if (s.isHost && open)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: NyfaForm.action(
              key: const Key('InvitePlayers'),
              label: l10n.invitePlayers,
              filled: false,
              onPressed: state.invite,
            ),
          ),
        if (!s.isHost && open)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 18, color: Nyfa.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.isGoing ? l10n.exactSpotGoing : l10n.exactSpotNote,
                    style: Nyfa.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final SessionPageState state;

  const _ActionBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = state.session!;
    final busy = state.busy;
    final ended = s.endedAt != null;
    final started = s.startedAt != null;

    Widget? primary;
    Widget? secondary;
    String? note;

    if (s.isHost) {
      if (!started) {
        primary = NyfaForm.action(
          key: const Key('StartScheduled'),
          label: l10n.startNow,
          onPressed: busy
              ? null
              : () =>
                    state.act(() => state._client.startScheduledSession(s.id)),
        );
      } else if (s.isRunning) {
        primary = NyfaForm.action(
          key: const Key('SessionCheckIn'),
          label: l10n.stillHere,
          onPressed: busy
              ? null
              : () => state.act(() => state._client.checkInToSession(s.id)),
        );
        secondary = NyfaForm.action(
          key: const Key('SessionStop'),
          label: l10n.stopSession,
          filled: false,
          onPressed: busy ? null : state.stop,
        );
      } else {
        primary = NyfaForm.action(
          key: const Key('SessionReport'),
          label: l10n.reportProgress,
          onPressed: state.report,
        );
      }
    } else {
      switch (s.myState) {
        case 'approved':
          if (started) {
            primary = NyfaForm.action(
              key: const Key('SessionReport'),
              label: l10n.reportProgress,
              onPressed: state.report,
            );
          } else {
            note = l10n.youreGoing;
          }
          if (!ended) {
            secondary = NyfaForm.action(
              key: const Key('LeaveSession'),
              label: l10n.leaveSession,
              filled: false,
              onPressed: busy
                  ? null
                  : () => state.act(() => state._client.leaveSession(s.id)),
            );
          }
        case 'requested':
          note = l10n.requestSent;
          secondary = NyfaForm.action(
            key: const Key('WithdrawRequest'),
            label: l10n.withdrawRequest,
            filled: false,
            onPressed: busy
                ? null
                : () => state.act(() => state._client.leaveSession(s.id)),
          );
        case 'declined':
          note = l10n.requestDeclined;
        default:
          if (ended) return const SizedBox.shrink();
          if (s.joining != 'open') {
            note = l10n.inviteOnlyNote;
          } else {
            primary = NyfaForm.action(
              key: const Key('RequestToJoin'),
              label: l10n.requestToJoin,
              onPressed: busy
                  ? null
                  : () => state.act(() => state._client.requestToJoin(s.id)),
            );
          }
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Nyfa.ground,
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              if (note != null)
                Expanded(
                  child: Row(
                    children: [
                      if (s.myState == 'approved')
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check, color: Nyfa.green, size: 20),
                        ),
                      Flexible(
                        child: Text(
                          note.toUpperCase(),
                          style: Nyfa.heading.copyWith(
                            fontSize: 17,
                            color: s.myState == 'approved'
                                ? Nyfa.green
                                : Nyfa.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (primary != null) Expanded(child: primary),
              if (primary != null && secondary != null)
                const SizedBox(width: 12),
              if (secondary != null)
                note != null ? secondary : Expanded(child: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The radius a host picked, back in the miles they picked it in.
int _milesOf(FootbagArea? area) {
  if (area == null) return 3;
  const choices = [1, 3, 10, 25];
  return choices.reduce(
    (a, b) =>
        (area.radiusM - a * 1609.344).abs() <=
            (area.radiusM - b * 1609.344).abs()
        ? a
        : b,
  );
}

/// Where: the circle for everyone who can see the session, the place itself
/// for those let in. Hidden entirely when there is nothing to show and the
/// viewer cannot add anything.
class _Where extends StatelessWidget {
  final SessionPageState state;

  const _Where({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final s = state.session!;
    final area = s.area;
    final place = s.place;
    if (area == null && !s.isHost) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.where.toUpperCase(), style: Nyfa.eyebrow),
              ),
              if (s.isHost)
                TextButton(
                  key: const Key('SetWhere'),
                  onPressed: state.busy ? null : state.setWhere,
                  style: TextButton.styleFrom(
                    foregroundColor: Nyfa.green,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    (area == null ? l10n.setLocation : l10n.changeLocation)
                        .toUpperCase(),
                    style: Nyfa.eyebrow.copyWith(color: Nyfa.green),
                  ),
                ),
            ],
          ),
        ),
        if (area != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 180,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
                child: FootbagMap(
                  key: const Key('SessionMap'),
                  areas: [area],
                  pin: place == null ? null : LatLng(place.lat, place.lng),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Icon(
                place != null
                    ? Icons.place_outlined
                    : Icons.blur_circular_outlined,
                size: 18,
                color: place != null ? Nyfa.green : Nyfa.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place?.name ??
                          (area == null ? l10n.noLocation : l10n.areaOnly),
                      style: Nyfa.bodyText.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (area != null)
                      Text(
                        l10n.areaMiles(_milesOf(area)),
                        style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (place != null)
                SmallButton(
                  key: const Key('OpenInMaps'),
                  label: l10n.openInMaps,
                  onPressed: () => state.openInMaps(place),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
