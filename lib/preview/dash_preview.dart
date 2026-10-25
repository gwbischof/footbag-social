// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A throwaway harness for LOOKING at the new screens.
//
// Not shipped and not imported by the app: `flutter run -t lib/preview/...`
// only. It exists because twice in this feature a screen was declared working
// on the strength of "it compiles", and both times it was wrong -- once a
// widget was mounted at zero width, once it was never on screen at all.

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: const _Gallery(),
  );
}

/// Every club-themed screen's chrome, side by side, so a change to the tokens
/// shows up everywhere at once.
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // Driven by the URL so a headless screenshot can capture each screen
    // without needing to click a tab.
    final want = Uri.base.queryParameters['screen'];
    final index = const [
      'dash', 'profile', 'favourites', 'schedule', 'discover', 'rankings',
    ].indexOf(want ?? 'dash');

    return DefaultTabController(
      initialIndex: index < 0 ? 0 : index,
      length: 6,
      child: Scaffold(
        backgroundColor: Nyfa.ground,
        appBar: TabBar(
          labelColor: Nyfa.green,
          unselectedLabelColor: Nyfa.muted,
          indicatorColor: Nyfa.green,
          labelStyle: const TextStyle(fontFamily: Nyfa.display, fontSize: 15),
          tabs: const [
            Tab(text: 'DASH'),
            Tab(text: 'PROFILE'),
            Tab(text: 'FAVOURITES'),
            Tab(text: 'SCHEDULE'),
            Tab(text: 'DISCOVER'),
            Tab(text: 'RANKINGS'),
          ],
        ),
        body: TabBarView(
          children: [
            const _PreviewScaffold(),
            _ProfilePreview(l10n: l10n),
            _FavouritesPreview(l10n: l10n),
            _SchedulePreview(l10n: l10n),
            _DiscoverPreview(l10n: l10n),
            _RankingsPreview(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _ProfilePreview extends StatelessWidget {
  final L10n l10n;
  const _ProfilePreview({required this.l10n});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nyfa.ground,
    appBar: Nyfa.appBar(title: l10n.editProfile),
    body: ListView(
      children: [
        const SizedBox(height: 12),
        NyfaForm.field(
          controller: TextEditingController(text: 'Garrett'),
          label: l10n.displayName,
          helper: l10n.displayNameHelp,
        ),
        const SizedBox(height: 14),
        NyfaForm.field(
          controller: TextEditingController(
            text: 'Playing since 2003. Working on spinning paradox mirages.',
          ),
          label: l10n.bio,
          helper: l10n.bioHelp,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: 14),
        NyfaForm.field(
          controller: TextEditingController(text: 'New York'),
          label: l10n.city,
          helper: l10n.cityHelp,
        ),
        NyfaForm.section(l10n.playStyles),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(l10n.playStylesHelp, style: Nyfa.bodyMuted),
        ),
        NyfaForm.chips(
          options: [
            (value: 'kicking', label: l10n.sessionTypeKicking),
            (value: 'freestyle', label: l10n.sessionTypeFreestyle),
            (value: 'net', label: l10n.sessionTypeNet),
            (value: 'stitching', label: l10n.sessionTypeStitching),
          ],
          selected: const {'freestyle', 'net'},
          onToggle: (_) {},
        ),
        NyfaForm.section(l10n.privacy),
        NyfaForm.toggle(
          label: l10n.discoverable,
          explain: l10n.discoverableExplain,
          value: true,
          onChanged: (_) {},
        ),
        NyfaForm.toggle(
          label: l10n.showMySessions,
          explain: l10n.showMySessionsExplain,
          value: false,
          onChanged: (_) {},
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: NyfaForm.action(label: l10n.saveProfile, onPressed: () {}),
        ),
        const SizedBox(height: 40),
      ],
    ),
  );
}

class _FavouritesPreview extends StatelessWidget {
  final L10n l10n;
  const _FavouritesPreview({required this.l10n});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nyfa.ground,
    appBar: Nyfa.appBar(
      title: l10n.favourites,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, color: Nyfa.green, size: 20),
            label: Text(
              l10n.addTrick.toUpperCase(),
              style: const TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 17,
                letterSpacing: 1.1,
                color: Nyfa.green,
              ),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(l10n.favouritesHelp, style: Nyfa.bodyMuted),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              const Icon(Icons.drag_handle, size: 16, color: Nyfa.muted),
              const SizedBox(width: 6),
              Text(l10n.reorderHint.toUpperCase(), style: Nyfa.eyebrow),
            ],
          ),
        ),
        for (final name in ['Mirage', 'Paradox Mirage', 'Atomic Mirage'])
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Nyfa.rule)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Icon(Icons.drag_handle, color: Nyfa.muted),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      style: Nyfa.heading.copyWith(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Nyfa.muted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _SchedulePreview extends StatelessWidget {
  final L10n l10n;
  const _SchedulePreview({required this.l10n});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nyfa.ground,
    appBar: Nyfa.appBar(title: l10n.scheduleSession),
    body: ListView(
      children: [
        NyfaForm.section(l10n.scheduleWhen),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            spacing: 12,
            children: [
              Expanded(child: _FakePicker(label: l10n.pickDate, value: 'Sat 26 Oct 2026')),
              Expanded(child: _FakePicker(label: l10n.pickTime, value: '6:00 PM')),
            ],
          ),
        ),
        NyfaForm.section(l10n.sessionTypeLabel),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(l10n.sessionTypeHelp, style: Nyfa.bodyMuted),
        ),
        NyfaForm.chips(
          options: [
            (value: 'casual', label: l10n.sessionTypeCasual),
            (value: 'kicking', label: l10n.sessionTypeKicking),
            (value: 'freestyle', label: l10n.sessionTypeFreestyle),
            (value: 'net', label: l10n.sessionTypeNet),
            (value: 'stitching', label: l10n.sessionTypeStitching),
          ],
          selected: const {'freestyle'},
          onToggle: (_) {},
        ),
        const SizedBox(height: 24),
        NyfaForm.field(
          controller: TextEditingController(),
          label: l10n.sessionName,
          helper: l10n.sessionNameHelp,
        ),
        NyfaForm.section(l10n.whoCanJoin),
        NyfaForm.chips(
          options: [
            (value: 'open', label: l10n.joiningOpen),
            (value: 'invite_only', label: l10n.joiningInviteOnly),
          ],
          selected: const {'open'},
          onToggle: (_) {},
        ),
        const SizedBox(height: 10),
        NyfaForm.toggle(
          label: l10n.showOnFeed,
          explain: l10n.showOnFeedExplain,
          value: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: NyfaForm.action(label: l10n.createSession, onPressed: () {}),
        ),
        const SizedBox(height: 40),
      ],
    ),
  );
}

class _DiscoverPreview extends StatelessWidget {
  final L10n l10n;
  const _DiscoverPreview({required this.l10n});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: _scaffold(context),
  );

  Widget _scaffold(BuildContext context) => Scaffold(
    backgroundColor: Nyfa.ground,
    appBar: AppBar(
      backgroundColor: Nyfa.ground,
      surfaceTintColor: Nyfa.ground,
      elevation: 0,
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
    body: Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final o in [
                (l10n.anyStyle, true),
                (l10n.sessionTypeKicking, false),
                (l10n.sessionTypeFreestyle, false),
                (l10n.sessionTypeNet, false),
                (l10n.sessionTypeStitching, false),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: o.$2 ? Nyfa.green : Colors.transparent,
                      border: Border.all(color: o.$2 ? Nyfa.green : Nyfa.rule),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        o.$1.toUpperCase(),
                        style: TextStyle(
                          fontFamily: Nyfa.display,
                          fontSize: 16,
                          letterSpacing: 0.8,
                          color: o.$2 ? Nyfa.ground : Nyfa.paper,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in [
          ('Freestyle · Sat 25 Oct', '@maya:footbagsocial.com', true),
          ('Washington Square Meetup', '@theo:footbagsocial.com', false),
        ])
          DecoratedBox(
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
                          s.$1.toUpperCase(),
                          style: Nyfa.heading.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 3),
                        Text(s.$2, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (s.$3)
                    Text(
                      l10n.runningNow.toUpperCase(),
                      style: Nyfa.eyebrow.copyWith(color: Nyfa.green),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _RankingsPreview extends StatelessWidget {
  final L10n l10n;
  const _RankingsPreview({required this.l10n});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nyfa.ground,
    appBar: Nyfa.appBar(title: l10n.rankings),
    body: ListView(
      children: [
        const SizedBox(height: 14),
        _chipRow([
          (l10n.metricPlayTime, true),
          (l10n.metricSessions, false),
          (l10n.metricDays, false),
        ]),
        const SizedBox(height: 10),
        _chipRow([
          (l10n.windowWeek, false),
          (l10n.windowMonth, true),
          (l10n.windowYear, false),
          (l10n.windowAll, false),
        ]),
        const SizedBox(height: 18),
        for (final r in [
          (1, 'Maya', '12H 40M', false),
          (2, 'Theo', '9H 05M', false),
          (3, 'Garrett', '7H 22M', true),
          (4, 'Lena', '4H 10M', false),
        ])
          DecoratedBox(
            decoration: BoxDecoration(
              color: r.$4 ? Nyfa.raised : Colors.transparent,
              border: const Border(top: BorderSide(color: Nyfa.rule)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${r.$1}',
                      style: TextStyle(
                        fontFamily: Nyfa.display,
                        fontSize: 20,
                        color: r.$1 <= 3 ? Nyfa.green : Nyfa.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          r.$2.toUpperCase(),
                          style: Nyfa.heading.copyWith(fontSize: 17),
                        ),
                        if (r.$4) ...[
                          const SizedBox(width: 8),
                          Text(
                            l10n.youLabel.toUpperCase(),
                            style: Nyfa.eyebrow.copyWith(
                              color: Nyfa.green,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    r.$3,
                    style: const TextStyle(
                      fontFamily: Nyfa.display,
                      color: Nyfa.paper,
                      fontSize: 19,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Text(l10n.whyNotRanked.toUpperCase(), style: Nyfa.eyebrow),
        ),
        const Divider(height: 34, thickness: 1, color: Nyfa.rule),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(l10n.yourPractice.toUpperCase(), style: Nyfa.eyebrow),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            l10n.yourPracticeBody,
            style: Nyfa.bodyMuted.copyWith(fontSize: 12),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var w = 0; w < 21; w++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Container(
                          width: 13,
                          height: 13,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: const [
                              Nyfa.raised,
                              Color(0xFF2F4A12),
                              Color(0xFF6E9A1E),
                              Nyfa.green,
                            ][(w * 7 + d * 3) % 4],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chipRow(List<(String, bool)> options) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: o.$2 ? Nyfa.green : Colors.transparent,
                border: Border.all(color: o.$2 ? Nyfa.green : Nyfa.rule),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  o.$1.toUpperCase(),
                  style: TextStyle(
                    fontFamily: Nyfa.display,
                    fontSize: 16,
                    letterSpacing: 0.8,
                    color: o.$2 ? Nyfa.ground : Nyfa.paper,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _FakePicker extends StatelessWidget {
  final String label;
  final String value;
  const _FakePicker({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: Nyfa.eyebrow.copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Nyfa.heading.copyWith(fontSize: 19)),
        ),
      ],
    ),
  );
}

/// Dash's chrome with stubbed content: the parts that are pure layout.
class _PreviewScaffold extends StatelessWidget {
  const _PreviewScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      backgroundColor: Nyfa.ground,
      appBar: AppBar(
        backgroundColor: Nyfa.ground,
        surfaceTintColor: Nyfa.ground,
        elevation: 0,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FOOTBAG SOCIAL',
              style: TextStyle(
                fontFamily: Nyfa.display,
                color: Nyfa.paper,
                fontSize: 24,
                letterSpacing: 1.6,
                height: 1.05,
              ),
            ),
            Text(l10n.dashGreeting, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Nyfa.raised,
              child: const Text(
                'G',
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  color: Nyfa.green,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Nyfa.rule),
        ),
      ),
      bottomNavigationBar: const FootbagNavBar(current: FootbagTab.dash),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final s in [
                  (l10n.favourites, Icons.star_outline_rounded),
                  (l10n.scheduleSession, Icons.calendar_today_outlined),
                  (l10n.rankings, Icons.leaderboard_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Nyfa.rule),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Row(
                          children: [
                            Icon(s.$2, size: 16, color: Nyfa.muted),
                            const SizedBox(width: 7),
                            Text(
                              s.$1.toUpperCase(),
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
              ],
            ),
          ),
          // The running scoreboard.
          Container(
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Nyfa.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.sessionRunning.toUpperCase(), style: Nyfa.eyebrow),
                  ],
                ),
                const SizedBox(height: 10),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('00:47:12', style: Nyfa.clock),
                ),
                const SizedBox(height: 6),
                Text('Freestyle · Sat 25 Oct', style: Nyfa.bodyMuted),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: Nyfa.green,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          l10n.checkInDueIn(6).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Nyfa.display,
                            fontSize: 17,
                            letterSpacing: 1.1,
                            color: Nyfa.ground,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Nyfa.rule),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          l10n.stopSession.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Nyfa.display,
                            fontSize: 17,
                            letterSpacing: 1.1,
                            color: Nyfa.paper,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(l10n.checkInExplainer, style: Nyfa.bodyMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
            child: Text(l10n.yourSessions.toUpperCase(), style: Nyfa.eyebrow),
          ),
          for (final row in [
            ('Freestyle · Fri 24 Oct', 'Freestyle  ·  18:30', '47 MIN'),
            ('Kicking · Wed 22 Oct', 'Kicking  ·  12:05', '1H 12M'),
          ])
            DecoratedBox(
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
                            row.$1.toUpperCase(),
                            style: Nyfa.heading.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 3),
                          Text(row.$2, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      row.$3,
                      style: const TextStyle(
                        fontFamily: Nyfa.display,
                        color: Nyfa.paper,
                        fontSize: 19,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Nyfa.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
