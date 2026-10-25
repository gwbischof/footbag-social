// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/pages/discover/discover_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';

/// Finding other players, and sessions worth turning up to.
///
/// Not geographic yet: "near me" needs a location this app deliberately does
/// not collect, so Discover filters by discipline and city. That is also how a
/// small community actually finds each other, so it is useful rather than a
/// placeholder.
class Discover extends StatefulWidget {
  const Discover({super.key});

  @override
  DiscoverController createState() => DiscoverController();
}

class DiscoverController extends State<Discover> {
  List<FootbagPlayer>? players;
  List<FootbagSession>? sessions;
  Object? error;

  /// null means "all disciplines".
  String? style;
  final cityController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    cityController.dispose();
    super.dispose();
  }

  void setStyle(String? value) {
    setState(() => style = value);
    unawaited(load());
  }

  void onCityChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(load());
    });
  }

  Future<void> load() async {
    try {
      final client = Matrix.of(context).client;
      // Both tabs at once: they are independent and the screen shows one of
      // them immediately, so serialising would make the second tab feel slow
      // for no reason.
      final results = await Future.wait([
        client.discoverPlayers(style: style, city: cityController.text.trim()),
        client.discoverSessions(type: style),
      ]);
      if (!mounted) return;
      setState(() {
        players = results[0] as List<FootbagPlayer>;
        sessions = results[1] as List<FootbagSession>;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => DiscoverView(this);
}
