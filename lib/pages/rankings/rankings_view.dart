// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/rankings/rankings.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class RankingsView extends StatelessWidget {
  final RankingsController controller;

  const RankingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      key: const Key('RankingsScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.rankings),
      body: MaxWidthBody(
        withScrolling: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          backgroundColor: Nyfa.raised,
          color: Nyfa.green,
          child: _body(context, l10n),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, L10n l10n) {
    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 72),
          const Icon(Icons.cloud_off_rounded, size: 44, color: Nyfa.muted),
          const SizedBox(height: 18),
          Text(
            l10n.oopsSomethingWentWrong.toUpperCase(),
            textAlign: TextAlign.center,
            style: Nyfa.heading,
          ),
          const SizedBox(height: 8),
          Text(
            controller.error!.toLocalizedString(context),
            textAlign: TextAlign.center,
            style: Nyfa.bodyMuted,
          ),
          const SizedBox(height: 20),
          Center(
            child: NyfaForm.action(
              label: l10n.retry,
              filled: false,
              onPressed: controller.load,
            ),
          ),
        ],
      );
    }
    if (controller.rows == null) {
      return const Center(
        child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
      );
    }

    return ListView(
      key: const Key('RankingsList'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 14),
        _Chips(
          keyPrefix: 'Metric',
          options: [
            (value: 'play_time', label: l10n.metricPlayTime),
            (value: 'sessions', label: l10n.metricSessions),
            (value: 'days', label: l10n.metricDays),
          ],
          selected: controller.metric,
          onTap: controller.setMetric,
        ),
        const SizedBox(height: 10),
        _Chips(
          keyPrefix: 'Window',
          options: [
            (value: 'week', label: l10n.windowWeek),
            (value: 'month', label: l10n.windowMonth),
            (value: 'year', label: l10n.windowYear),
            (value: 'all', label: l10n.windowAll),
          ],
          selected: controller.window,
          onTap: controller.setWindow,
        ),
        const SizedBox(height: 18),

        if (controller.rows!.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            child: Column(
              children: [
                Text(
                  l10n.noRankingsYet.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Nyfa.heading,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.noRankingsYetBody,
                  textAlign: TextAlign.center,
                  style: Nyfa.bodyMuted,
                ),
              ],
            ),
          )
        else
          for (final r in controller.rows!)
            _Row(
              key: ValueKey(r.userId),
              row: r,
              metric: controller.metric,
              youLabel: l10n.youLabel,
            ),

        // Said on the screen rather than left to be noticed as a gap. "My kick
        // count isn't on the board" is a reasonable thing to wonder, and the
        // reason is more interesting than silence.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('WhyNotRankedTile'),
              tilePadding: EdgeInsets.zero,
              iconColor: Nyfa.muted,
              collapsedIconColor: Nyfa.muted,
              title: Text(
                l10n.whyNotRanked.toUpperCase(),
                style: Nyfa.eyebrow,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(l10n.whyNotRankedBody, style: Nyfa.bodyMuted),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 34, thickness: 1, color: Nyfa.rule),
        _Heatmap(controller: controller),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onTap;
  final String keyPrefix;

  const _Chips({
    required this.options,
    required this.selected,
    required this.onTap,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              selected: selected == o.value,
              child: InkWell(
                key: Key('$keyPrefix${o.value}'),
                onTap: () => onTap(o.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected == o.value ? Nyfa.green : Colors.transparent,
                    border: Border.all(
                      color: selected == o.value ? Nyfa.green : Nyfa.rule,
                    ),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      o.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: Nyfa.display,
                        fontSize: 16,
                        letterSpacing: 0.8,
                        color: selected == o.value ? Nyfa.ground : Nyfa.paper,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final FootbagRanking row;
  final String metric;
  final String youLabel;

  const _Row({
    required this.row,
    required this.metric,
    required this.youLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      // Your own row is marked rather than left to be found by reading names.
      color: row.isYou ? Nyfa.raised : Colors.transparent,
      border: const Border(top: BorderSide(color: Nyfa.rule)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${row.position}',
              style: TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 20,
                color: row.position <= 3 ? Nyfa.green : Nyfa.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.displayName.toUpperCase(),
                    style: Nyfa.heading.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (row.isYou) ...[
                  const SizedBox(width: 8),
                  Text(youLabel.toUpperCase(), style: Nyfa.eyebrow.copyWith(
                    color: Nyfa.green,
                    fontSize: 13,
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _value(),
            style: const TextStyle(
              fontFamily: Nyfa.display,
              color: Nyfa.paper,
              fontSize: 19,
              letterSpacing: 0.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  String _value() {
    if (metric != 'play_time') return '${row.value}';
    final d = Duration(seconds: row.value);
    return d.inHours > 0
        ? '${d.inHours}H ${d.inMinutes % 60}M'
        : '${d.inMinutes} MIN';
  }
}

/// A contributions-style calendar of your own practice.
///
/// One column per week, oldest on the left. Intensity is duration, which is
/// the doc's choice — it rewards long sessions where a count would reward
/// showing up, and those incentivise different things.
class _Heatmap extends StatelessWidget {
  final RankingsController controller;

  const _Heatmap({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final days = controller.heatmap ?? const <FootbagHeatmapDay>[];

    final byDay = {
      for (final d in days)
        DateTime(d.day.year, d.day.month, d.day.day): d,
    };
    final busiest = days.isEmpty
        ? 1
        : days.map((d) => d.seconds).reduce((a, b) => a > b ? a : b);

    // 21 weeks back, ending on today's week.
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1 + 7 * 20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(l10n.noPracticeYet, style: Nyfa.bodyMuted),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Most recent week in view first.
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var week = 0; week < 21; week++)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Column(
                      children: [
                        for (var weekday = 0; weekday < 7; weekday++)
                          _Cell(
                            day: byDay[start.add(
                              Duration(days: week * 7 + weekday),
                            )],
                            busiest: busiest,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final FootbagHeatmapDay? day;
  final int busiest;

  const _Cell({required this.day, required this.busiest});

  @override
  Widget build(BuildContext context) {
    final d = day;
    // Four steps, not a continuous ramp: a gradient of near-identical greens
    // reads as noise, and the question is "how hard was that day", not "to the
    // minute, how hard".
    final step = d == null || d.seconds == 0
        ? 0
        : (3 * d.seconds / busiest).ceil().clamp(1, 3);
    const fills = [Nyfa.raised, Color(0xFF2F4A12), Color(0xFF6E9A1E), Nyfa.green];

    return Tooltip(
      message: d == null
          ? ''
          : '${d.sessions} · ${Duration(seconds: d.seconds).inMinutes} min',
      child: Container(
        width: 13,
        height: 13,
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(color: fills[step]),
      ),
    );
  }
}
