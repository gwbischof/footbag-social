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

  @override
  void initState() {
    super.initState();
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
        client.fetchRankings(metric: metric, window: window),
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
