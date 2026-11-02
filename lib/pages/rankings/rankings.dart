// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/pages/rankings/rankings_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';

/// The leaderboard, and your own practice calendar.
///
/// Only corroborated numbers are ranked. The two metrics people would most
/// expect — kick counts and tricks landed — are deliberately absent, and the
/// screen says why rather than leaving it to be noticed as a gap.
class Rankings extends StatefulWidget {
  const Rankings({super.key});

  @override
  RankingsController createState() => RankingsController();
}

class RankingsController extends State<Rankings> {
  List<FootbagRanking>? rows;
  List<FootbagHeatmapDay>? heatmap;
  Object? error;

  String metric = 'play_time';
  String window = 'month';

  /// Your clubs, and which board is showing: a club's id, or null for
  /// everyone. The doc wants local scopes to lead -- a club table is the one
  /// a player cares about -- so a member opens on their club, not the world.
  List<FootbagClub> clubs = const [];
  int? club;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final mine = await Matrix.of(context).client.fetchClubs(mine: true);
      if (!mounted) return;
      clubs = mine.where((c) => c.isMember).toList();
      club = clubs.firstOrNull?.id;
    } catch (_) {
      // No clubs to offer is the same screen as having none.
    }
    await load();
  }

  void setClub(String value) {
    setState(() => club = value == 'all' ? null : int.parse(value));
    unawaited(load());
  }

  void setMetric(String value) {
    setState(() => metric = value);
    unawaited(load());
  }

  void setWindow(String value) {
    setState(() => window = value);
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final client = Matrix.of(context).client;
      final results = await Future.wait([
        client.fetchRankings(metric: metric, window: window, club: club),
        client.fetchHeatmap(),
      ]);
      if (!mounted) return;
      setState(() {
        rows = results[0] as List<FootbagRanking>;
        heatmap = results[1] as List<FootbagHeatmapDay>;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => RankingsView(this);
}
