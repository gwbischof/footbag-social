// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/discover/discover.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class DiscoverView extends StatelessWidget {
  final DiscoverController controller;

  const DiscoverView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return DefaultTabController(
      length: 2,
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
          title: Text(l10n.discover.toUpperCase(), style: Nyfa.heading),
          bottom: TabBar(
            labelColor: Nyfa.green,
            unselectedLabelColor: Nyfa.muted,
            indicatorColor: Nyfa.green,
            dividerColor: Nyfa.rule,
            labelStyle: const TextStyle(
              fontFamily: Nyfa.display,
              fontSize: 17,
              letterSpacing: 1.1,
            ),
            tabs: [
              Tab(text: l10n.discoverSessions.toUpperCase()),
              Tab(text: l10n.discoverPlayers.toUpperCase()),
            ],
          ),
        ),
        bottomNavigationBar: const FootbagNavBar(current: FootbagTab.discover),
        body: MaxWidthBody(
          withScrolling: false,
          child: Column(
            children: [
              _Filters(controller: controller),
              Expanded(
                child: TabBarView(
                  children: [
                    _SessionsTab(controller: controller),
                    _PlayersTab(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final DiscoverController controller;

  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        // One filter row drives both tabs: a discipline is a session type and
        // a play style, which is the point of using one vocabulary for both.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final o in <({String? value, String label})>[
                (value: null, label: l10n.anyStyle),
                (value: 'kicking', label: l10n.sessionTypeKicking),
                (value: 'freestyle', label: l10n.sessionTypeFreestyle),
                (value: 'net', label: l10n.sessionTypeNet),
                (value: 'stitching', label: l10n.sessionTypeStitching),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    key: Key('Filter_${o.value ?? 'all'}'),
                    label: o.label,
                    selected: controller.style == o.value,
                    onTap: () => controller.setStyle(o.value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Nyfa.green : Colors.transparent,
          border: Border.all(color: selected ? Nyfa.green : Nyfa.rule),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: Nyfa.display,
              fontSize: 16,
              letterSpacing: 0.8,
              color: selected ? Nyfa.ground : Nyfa.paper,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SessionsTab extends StatelessWidget {
  final DiscoverController controller;

  const _SessionsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (controller.error != null) return _problem(context, controller, l10n);
    if (controller.sessions == null) return const _Spinner();

    final rows = controller.sessions!;
    if (rows.isEmpty) {
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
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final s = rows[i];
          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Nyfa.rule)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name.toUpperCase(),
                          style: Nyfa.heading.copyWith(fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.hostId,
                          style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (s.isRunning) ...[
                    const SizedBox(width: 10),
                    Text(
                      l10n.runningNow.toUpperCase(),
                      style: Nyfa.eyebrow.copyWith(color: Nyfa.green),
                    ),
                  ],
                ],
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
    if (controller.players == null) return const _Spinner();

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
            for (final p in rows) _PlayerRow(key: ValueKey(p.userId), player: p),
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
    final detail = [
      if (player.city != null && player.city!.isNotEmpty) player.city!,
      if (player.playStyles.isEmpty)
        l10n.playsNothingYet
      else
        player.playStyles.map((s) => _styleLabel(l10n, s)).join(' · '),
    ].join('   ·   ');

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Nyfa.raised,
              child: Text(
                player.displayName.isEmpty
                    ? '?'
                    : player.displayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  color: Nyfa.green,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName.toUpperCase(),
                    style: Nyfa.heading.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
  );
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
        Text(title.toUpperCase(), textAlign: TextAlign.center, style: Nyfa.heading),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: Nyfa.bodyMuted),
      ],
    ),
  );
}

Widget _problem(BuildContext context, DiscoverController c, L10n l10n) => ListView(
  padding: const EdgeInsets.symmetric(horizontal: 32),
  children: [
    const SizedBox(height: 48),
    const Icon(Icons.cloud_off_rounded, size: 44, color: Nyfa.muted),
    const SizedBox(height: 18),
    Text(
      l10n.oopsSomethingWentWrong.toUpperCase(),
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
    Center(child: NyfaForm.action(label: l10n.retry, filled: false, onPressed: c.load)),
  ],
);
