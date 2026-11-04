// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/discover/discover.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/edge_fade.dart';
import 'package:footbag_network/widgets/footbag_map.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class DiscoverView extends StatelessWidget {
  final DiscoverController controller;

  const DiscoverView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return DefaultTabController(
      length: 3,
      initialIndex: controller.widget.initialTab,
      child: Scaffold(
        key: const Key('DiscoverScaffold'),
        backgroundColor: Nyfa.ground,
        appBar: AppBar(
          backgroundColor: Nyfa.ground,
          surfaceTintColor: Nyfa.ground,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: 20,
          title: Text(l10n.discover, style: Nyfa.heading),
          bottom: TabBar(
            labelColor: Nyfa.paper,
            unselectedLabelColor: Nyfa.muted,
            indicatorColor: Nyfa.paper,
            dividerColor: Nyfa.rule,
            labelStyle: const TextStyle(
              fontFamily: Nyfa.body,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: [
              Tab(text: l10n.discoverSessions),
              Tab(text: l10n.discoverPlayers),
              Tab(text: l10n.discoverClubs),
            ],
          ),
        ),
        bottomNavigationBar: const FootbagNavBar(current: FootbagTab.discover),
        body: MaxWidthBody(
          withScrolling: false,
          // The discipline filter belongs to the two tabs it filters; a club
          // is not a discipline, so the Clubs tab goes without it.
          child: TabBarView(
            children: [
              Column(
                children: [
                  _Filters(controller: controller, nearMe: true),
                  Expanded(child: _SessionsTab(controller: controller)),
                ],
              ),
              Column(
                children: [
                  _Filters(controller: controller),
                  Expanded(child: _PlayersTab(controller: controller)),
                ],
              ),
              _ClubsTab(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final DiscoverController controller;

  /// The near-me chip: sessions have an area, players do not.
  final bool nearMe;

  const _Filters({required this.controller, this.nearMe = false});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        // One filter row drives both tabs: a discipline is a session type and
        // a play style, which is the point of using one vocabulary for both.
        SizedBox(
          height: 48,
          child: EdgeFade(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (nearMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NyfaChip(
                      key: const Key('Filter_near'),
                      label: l10n.nearMe,
                      icon: Icons.near_me_outlined,
                      selected: controller.near != null,
                      onTap: controller.locating ? null : controller.toggleNear,
                    ),
                  ),
                for (final o in <({String? value, String label})>[
                  (value: null, label: l10n.anyStyle),
                  (value: 'kicking', label: l10n.sessionTypeKicking),
                  (value: 'freestyle', label: l10n.sessionTypeFreestyle),
                  (value: 'net', label: l10n.sessionTypeNet),
                  (value: 'stitching', label: l10n.sessionTypeStitching),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NyfaChip(
                      key: Key('Filter_${o.value ?? 'all'}'),
                      label: o.label,
                      selected: controller.style == o.value,
                      onTap: () => controller.setStyle(o.value),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SessionsTab extends StatelessWidget {
  final DiscoverController controller;

  const _SessionsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (controller.error != null) return _problem(context, controller, l10n);
    if (controller.sessions == null) return const _Loading();

    final rows = controller.sessions!;
    final near = controller.near;
    // Near me shows where, before what: the circles say more at a glance
    // than a list of names. Sessions without an area are already filtered
    // out by the server when near is on.
    final map = near == null
        ? null
        : SizedBox(
            height: 200,
            child: FootbagMap(
              key: const Key('DiscoverMap'),
              areas: [for (final s in rows) s.area!],
              you: near,
              interactive: true,
              onAreaTap: (i) => context.push('/rooms/session/${rows[i].id}'),
            ),
          );
    if (rows.isEmpty) {
      if (map != null) {
        return ListView(
          children: [
            map,
            _Empty(
              icon: Icons.near_me_outlined,
              title: l10n.noSessionsToJoin,
              body: l10n.noSessionsNearBody,
            ),
          ],
        );
      }
      return _Empty(
        icon: Icons.sports_handball_rounded,
        title: l10n.noSessionsToJoin,
        body: l10n.noSessionsToJoinBody,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      backgroundColor: Nyfa.raised,
      color: Nyfa.green,
      child: ListView.builder(
        key: const Key('DiscoverSessionsList'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length + (map == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (map != null && index == 0) return map;
          final s = rows[index - (map == null ? 0 : 1)];
          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Nyfa.rule)),
            ),
            child: InkWell(
              key: Key('DiscoverSession_${s.id}'),
              onTap: () async {
                await context.push('/rooms/session/${s.id}');
                await controller.load();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: Nyfa.heading.copyWith(fontSize: 17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            // The host's name and how many are going -- not the
                            // MXID, which is how the first version read.
                            [
                              l10n.hostedBy(s.hostName ?? s.hostId),
                              l10n.goingCount(s.attendeeCount),
                              if (s.myState == 'requested') l10n.requestSent,
                              if (s.myState == 'approved') l10n.youreGoing,
                            ].join('  ·  '),
                            style: Nyfa.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (s.isRunning) ...[
                      const SizedBox(width: 10),
                      Text(
                        l10n.runningNow,
                        style: Nyfa.eyebrow.copyWith(color: Nyfa.green),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Nyfa.faint),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final DiscoverController controller;

  const _PlayersTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (controller.error != null) return _problem(context, controller, l10n);
    if (controller.players == null) {
      return const _Loading(avatar: true);
    }

    final rows = controller.players!;
    return RefreshIndicator(
      onRefresh: controller.load,
      backgroundColor: Nyfa.raised,
      color: Nyfa.green,
      child: ListView(
        key: const Key('DiscoverPlayersList'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              key: const Key('CityFilterField'),
              controller: controller.cityController,
              onChanged: controller.onCityChanged,
              style: Nyfa.bodyText,
              cursorColor: Nyfa.green,
              decoration: Nyfa.input(l10n.filterByCity).copyWith(
                prefixIcon: const Icon(
                  Icons.place_outlined,
                  color: Nyfa.muted,
                  size: 20,
                ),
              ),
            ),
          ),
          if (rows.isEmpty)
            _Empty(
              icon: Icons.person_search_outlined,
              title: l10n.noPlayersYet,
              body: l10n.noPlayersYetBody,
            )
          else
            for (final p in rows)
              _PlayerRow(key: ValueKey(p.userId), player: p),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final FootbagPlayer player;

  const _PlayerRow({required this.player, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PersonRow(
      userId: player.userId,
      name: player.displayName,
      detail: [
        if (player.city != null && player.city!.isNotEmpty) player.city!,
        if (player.playStyles.isEmpty)
          l10n.playsNothingYet
        else
          player.playStyles.map((s) => _styleLabel(l10n, s)).join(', '),
      ].join('  ·  '),
      trailing: const [Icon(Icons.chevron_right_rounded, color: Nyfa.faint)],
    );
  }

  String _styleLabel(L10n l10n, String s) => switch (s) {
    'kicking' => l10n.sessionTypeKicking,
    'freestyle' => l10n.sessionTypeFreestyle,
    'net' => l10n.sessionTypeNet,
    'stitching' => l10n.sessionTypeStitching,
    _ => s,
  };
}

class _Loading extends StatelessWidget {
  final bool avatar;

  const _Loading({this.avatar = false});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(child: RowsSkeleton(avatar: avatar));
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Empty({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
    child: Column(
      children: [
        Icon(icon, size: 44, color: Nyfa.muted),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: Nyfa.heading),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: Nyfa.bodyMuted),
      ],
    ),
  );
}

Widget _problem(BuildContext context, DiscoverController c, L10n l10n) =>
    ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.cloud_off_rounded, size: 44, color: Nyfa.muted),
        const SizedBox(height: 18),
        Text(
          l10n.oopsSomethingWentWrong,
          textAlign: TextAlign.center,
          style: Nyfa.heading,
        ),
        const SizedBox(height: 8),
        Text(
          c.error!.toLocalizedString(context),
          textAlign: TextAlign.center,
          style: Nyfa.bodyMuted,
        ),
        const SizedBox(height: 20),
        Center(
          child: NyfaForm.action(
            label: l10n.retry,
            filled: false,
            onPressed: c.load,
          ),
        ),
      ],
    );

/// Clubs, biggest first, with starting one a tap away.
class _ClubsTab extends StatelessWidget {
  final DiscoverController controller;

  const _ClubsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = controller.clubs;
    return RefreshIndicator(
      onRefresh: controller.load,
      backgroundColor: Nyfa.raised,
      color: Nyfa.green,
      child: ListView(
        key: const Key('DiscoverClubsList'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: NyfaForm.action(
              key: const Key('StartAClub'),
              label: l10n.startAClub,
              filled: false,
              onPressed: () async {
                await context.push('/rooms/club/new');
                await controller.load();
              },
            ),
          ),
          if (list == null)
            const RowsSkeleton(rows: 4)
          else if (list.isEmpty)
            _Empty(
              icon: Icons.groups_outlined,
              title: l10n.discoverClubs,
              body: l10n.clubsEmpty,
            )
          else
            for (final c in list)
              InkWell(
                key: Key('DiscoverClub_${c.id}'),
                onTap: () async {
                  await context.push('/rooms/club/${c.id}');
                  await controller.load();
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
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
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Nyfa.heading.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (c.location.isNotEmpty) c.location,
                                l10n.clubMemberCount(c.memberCount),
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Nyfa.meta,
                            ),
                          ],
                        ),
                      ),
                      if (c.isMember)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            (c.isOrganiser
                                ? l10n.organiser
                                : l10n.youAreMember),
                            style: Nyfa.eyebrow.copyWith(fontSize: 13),
                          ),
                        )
                      else if (c.myState == 'requested')
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            l10n.clubRequestSent,
                            style: Nyfa.eyebrow.copyWith(fontSize: 13),
                          ),
                        ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Nyfa.faint,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
