// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/pages/feed/widgets/post_grid.dart';
import 'package:footbag_network/utils/date_time_extension.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// A club: who they are, where they play, what they post and have on.
///
/// Public to everyone, as all clubs are -- roster included. The one action
/// at the bottom depends on where you stand: ask to join, wait, or (as a
/// member) schedule something for the club. There is no club chat button: a
/// club's conversation is a group chat its members make themselves.
class ClubPage extends StatefulWidget {
  final int clubId;

  const ClubPage({required this.clubId, super.key});

  @override
  ClubPageState createState() => ClubPageState();
}

enum ClubSection { posts, sessions, members }

class ClubPageState extends State<ClubPage> {
  FootbagClub? club;
  List<FootbagPost>? posts;
  List<FootbagSession>? sessions;
  Object? error;
  bool busy = false;
  ClubSection section = ClubSection.posts;

  Client get client => Matrix.of(context).client;

  /// The signed-in player. Overridden by the preview harness.
  String get me => client.userID ?? '';

  /// The founder cannot leave, so is not offered Leave.
  bool get isFounder =>
      club?.members?.any((m) => m.isCreator && m.userId == me) ?? false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        client.fetchClub(widget.clubId),
        client.fetchFeed(club: widget.clubId, limit: 30),
        client.fetchClubSessions(widget.clubId),
      ]);
      if (!mounted) return;
      setState(() {
        club = results[0] as FootbagClub;
        posts = (results[1] as FootbagFeedPage).posts;
        sessions = results[2] as List<FootbagSession>;
        error = null;
      });
    } catch (e, s) {
      Logs().w('Loading a club failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  Uri resolveMedia(String path) => client.footbagMediaUri(path);

  /// One action, then adopt the server's answer, or say why it refused.
  Future<void> act(Future<FootbagClub> Function() call) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => busy = true);
    try {
      final c = await call();
      if (mounted) setState(() => club = c);
    } on FootbagApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invite() async {
    final c = club;
    if (c == null) return;
    await showInviteSheet(
      context,
      client: client,
      already: {...?c.members?.map((m) => m.userId)},
      add: (id) => client.inviteToClub(c.id, id),
    );
    if (mounted) unawaited(load());
  }

  Future<void> edit() async {
    final c = club;
    if (c == null) return;
    await context.push('/rooms/club/${c.id}/edit', extra: c);
    if (mounted) unawaited(load());
  }

  Future<void> schedule() async {
    await context.push('/rooms/dash/schedule', extra: widget.clubId);
    if (mounted) unawaited(load());
  }

  Future<void> memberMenu(FootbagClubMember m) async {
    final l10n = L10n.of(context);
    final c = club!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Nyfa.raised,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label, icon) in [
              if (!m.isOrganiser)
                ('organiser', l10n.makeOrganiser, Icons.star_outline),
              if (m.isOrganiser)
                ('member', l10n.makeMember, Icons.person_outline),
              ('remove', l10n.removeFromClub, Icons.person_remove_outlined),
            ])
              ListTile(
                minTileHeight: 56,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(icon, color: Nyfa.paper),
                title: Text(
                  label.toUpperCase(),
                  style: Nyfa.heading.copyWith(fontSize: 17),
                ),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await act(
      () => choice == 'remove'
          ? client.declineClubMember(c.id, m.userId)
          : client.setClubRole(c.id, m.userId, choice),
    );
  }

  Future<void> leave() async {
    await act(() => client.leaveClub(widget.clubId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = club;
    return Scaffold(
      key: const Key('ClubScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(
        title: c?.name ?? '',
        actions: [
          if (c != null && c.isOrganiser)
            IconButton(
              key: const Key('EditClub'),
              tooltip: l10n.editClub,
              onPressed: edit,
              icon: const Icon(Icons.edit_outlined, color: Nyfa.paper),
            ),
          if (c != null && c.isMember && !isFounder)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Nyfa.paper),
              color: Nyfa.raised,
              onSelected: (_) => leave(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'leave',
                  child: Text(l10n.leaveClub, style: Nyfa.bodyText),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: c == null ? null : _ActionBar(state: this),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: feedMaxWidth),
          child: c == null
              ? (error != null
                    ? FeedProblem(error: error!, onRetry: load)
                    : const SingleChildScrollView(
                        child: RowsSkeleton(header: true),
                      ))
              : RefreshIndicator(
                  onRefresh: load,
                  backgroundColor: Nyfa.raised,
                  color: Nyfa.green,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _Header(club: c)),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 56,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                            children: [
                              for (final (s, label) in [
                                (ClubSection.posts, l10n.clubPosts),
                                (ClubSection.sessions, l10n.clubSessions),
                                (ClubSection.members, l10n.clubMembers),
                              ])
                                FeedChip(
                                  key: Key('ClubSection_${s.name}'),
                                  label: label,
                                  selected: section == s,
                                  onTap: () => setState(() => section = s),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Divider(height: 1, color: Nyfa.rule),
                      ),
                      ...switch (section) {
                        ClubSection.posts => _postSlivers(context),
                        ClubSection.sessions => [
                          SliverToBoxAdapter(child: _Sessions(state: this)),
                        ],
                        ClubSection.members => [
                          SliverToBoxAdapter(child: _Members(state: this)),
                        ],
                      },
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _postSlivers(BuildContext context) {
    final l10n = L10n.of(context);
    final list = posts ?? const <FootbagPost>[];
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              l10n.clubNoPosts,
              textAlign: TextAlign.center,
              style: Nyfa.bodyMuted,
            ),
          ),
        ),
      ];
    }
    return [
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 4 / 5,
        ),
        itemCount: list.length,
        itemBuilder: (context, i) => PostGridTile(
          post: list[i],
          resolve: resolveMedia,
          onTap: () =>
              context.push('/rooms/feed/post/${list[i].id}', extra: list[i]),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  final FootbagClub club;

  const _Header({required this.club});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.clubMemberCount(club.memberCount).toUpperCase(),
            style: Nyfa.eyebrow,
          ),
          if (club.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: Nyfa.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(club.location, style: Nyfa.bodyText)),
              ],
            ),
          ],
          if (club.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(club.description, style: Nyfa.bodyText),
          ],
        ],
      ),
    );
  }
}

class _Sessions extends StatelessWidget {
  final ClubPageState state;

  const _Sessions({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = state.sessions ?? const <FootbagSession>[];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          l10n.clubNoSessions,
          textAlign: TextAlign.center,
          style: Nyfa.bodyMuted,
        ),
      );
    }
    return Column(
      children: [
        for (final s in list)
          InkWell(
            key: Key('ClubSession_${s.id}'),
            onTap: () => context.push('/rooms/session/${s.id}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Nyfa.rule)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Nyfa.heading.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (s.isRunning)
                              l10n.sessionLive
                            else if (s.scheduledAt != null)
                              s.scheduledAt!.localizedTime(context),
                            l10n.goingCount(s.attendeeCount),
                          ].join('  ·  '),
                          style: Nyfa.meta,
                        ),
                      ],
                    ),
                  ),
                  if (s.isRunning)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Nyfa.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded, color: Nyfa.faint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  final ClubPageState state;

  const _Members({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = state.club!;
    final requests = c.requests ?? const [];
    final busy = state.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.isOrganiser && requests.isNotEmpty) ...[
          NyfaForm.section('${l10n.joinRequests}  ${requests.length}'),
          for (final r in requests)
            PersonRow(
              key: Key('ClubRequest_${r.userId}'),
              userId: r.userId,
              name: r.name,
              trailing: [
                SmallButton(
                  key: Key('ClubApprove_${r.userId}'),
                  label: l10n.sessionApprove,
                  accent: true,
                  onPressed: busy
                      ? null
                      : () => state.act(
                          () => state.client.approveClubMember(c.id, r.userId),
                        ),
                ),
                const SizedBox(width: 8),
                SmallButton(
                  label: l10n.sessionDecline,
                  onPressed: busy
                      ? null
                      : () => state.act(
                          () => state.client.declineClubMember(c.id, r.userId),
                        ),
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
        for (final m in c.members ?? const <FootbagClubMember>[])
          PersonRow(
            key: Key('ClubMember_${m.userId}'),
            userId: m.userId,
            name: m.name,
            trailing: [
              if (m.isCreator || m.isOrganiser)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    (m.isCreator ? l10n.founder : l10n.organiser).toUpperCase(),
                    style: Nyfa.eyebrow.copyWith(
                      fontSize: 13,
                      color: Nyfa.muted,
                    ),
                  ),
                ),
              // The founder's role is fixed, so there is nothing to offer.
              if (c.isOrganiser && !m.isCreator)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  onPressed: busy ? null : () => state.memberMenu(m),
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Nyfa.muted,
                  ),
                ),
            ],
          ),
        if (c.isOrganiser)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: NyfaForm.action(
              key: const Key('InviteToClub'),
              label: l10n.invitePlayers,
              filled: false,
              onPressed: state.invite,
            ),
          ),
      ],
    );
  }
}

/// The one thing to do next, pinned to the bottom.
class _ActionBar extends StatelessWidget {
  final ClubPageState state;

  const _ActionBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = state.club!;
    final busy = state.busy;

    Widget? action;
    String? note;
    Widget? secondary;
    switch (c.myState) {
      case 'approved':
        action = NyfaForm.action(
          key: const Key('ScheduleClubSession'),
          label: l10n.scheduleClubSession,
          onPressed: state.schedule,
        );
      case 'requested':
        note = l10n.clubRequestSent;
        secondary = NyfaForm.action(
          key: const Key('WithdrawClubRequest'),
          label: l10n.withdrawRequest,
          filled: false,
          onPressed: busy ? null : state.leave,
        );
      case 'declined':
        note = l10n.clubDeclined;
      default:
        action = NyfaForm.action(
          key: const Key('AskToJoinClub'),
          label: l10n.askToJoinClub,
          onPressed: busy
              ? null
              : () => state.act(() => state.client.askToJoinClub(c.id)),
        );
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
                  child: Text(
                    note.toUpperCase(),
                    style: Nyfa.heading.copyWith(fontSize: 17),
                  ),
                ),
              if (action != null) Expanded(child: action),
              ?secondary,
            ],
          ),
        ),
      ),
    );
  }
}
