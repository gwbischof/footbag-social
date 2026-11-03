// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/footbag_map.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Suggested places, for moderators to approve or turn down.
///
/// Each shows on a map: the question a moderator is answering is "is this
/// a park, or is it someone's front door?", and only the map answers it.
class PendingPlacesPage extends StatefulWidget {
  const PendingPlacesPage({super.key});

  @override
  PendingPlacesPageState createState() => PendingPlacesPageState();
}

class PendingPlacesPageState extends State<PendingPlacesPage> {
  List<FootbagPlace>? places;
  Object? error;

  Client get client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final list = await client.fetchPendingPlaces();
      if (mounted) {
        setState(() {
          places = list;
          error = null;
        });
      }
    } catch (e, s) {
      Logs().w('Loading pending places failed', e, s);
      if (mounted) setState(() => error = e);
    }
  }

  /// Decide, and drop the row at once rather than waiting for a reload: the
  /// decision is the whole interaction.
  Future<void> decide(FootbagPlace p, {required bool approve}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => places = places?.where((x) => x.id != p.id).toList());
    try {
      await (approve ? client.approvePlace(p.id) : client.rejectPlace(p.id));
    } on FootbagApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.detail)));
      if (mounted) unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = places;
    return Scaffold(
      key: const Key('PendingPlacesScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.places),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: load,
            backgroundColor: Nyfa.raised,
            color: Nyfa.green,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (list == null && error != null)
                  FeedProblem(error: error!, onRetry: load)
                else if (list == null)
                  const RowsSkeleton(rows: 3)
                else if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.placesPendingEmpty,
                      textAlign: TextAlign.center,
                      style: Nyfa.bodyMuted,
                    ),
                  )
                else
                  for (final p in list)
                    Padding(
                      key: Key('PendingPlace_${p.id}'),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 160,
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: Border.all(color: Nyfa.rule),
                              ),
                              child: FootbagMap(
                                pin: LatLng(p.lat, p.lng),
                                interactive: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: Nyfa.bodyText.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SmallButton(
                                key: Key('RejectPlace_${p.id}'),
                                label: l10n.rejectPlace,
                                onPressed: () => decide(p, approve: false),
                              ),
                              const SizedBox(width: 8),
                              SmallButton(
                                key: Key('ApprovePlace_${p.id}'),
                                label: l10n.approvePlace,
                                accent: true,
                                onPressed: () => decide(p, approve: true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
