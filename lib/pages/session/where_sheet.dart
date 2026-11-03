// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/near_me.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Choose where a session is: a known place, or "somewhere else", plus how
/// findable it is.
///
/// One low-accuracy fix is taken when the sheet opens, to list the nearest
/// places -- the doc's "nearest uses a device fix transiently to pick a
/// place". The fix is only ever sent as "somewhere else", where the server
/// uses it to draw a shifted circle and keeps nothing more precise. Without
/// location, places can still be found by name.
Future<FootbagWhere?> showWhereSheet(
  BuildContext context, {
  required Client client,
  FootbagWhere? current,
}) => showModalBottomSheet<FootbagWhere>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Nyfa.ground,
  shape: const RoundedRectangleBorder(),
  builder: (_) => _WhereSheet(client: client, current: current),
);

/// Preview seam: places and a fix without a server or a GPS. Null in the app.
abstract final class WhereSheetPreview {
  static List<FootbagPlace>? places;
  static ({double lat, double lng})? fix;
}

class _WhereSheet extends StatefulWidget {
  final Client client;
  final FootbagWhere? current;

  const _WhereSheet({required this.client, required this.current});

  @override
  State<_WhereSheet> createState() => _WhereSheetState();
}

class _WhereSheetState extends State<_WhereSheet> {
  final query = TextEditingController();
  Timer? _debounce;
  ({double lat, double lng})? fix;
  bool locating = true;
  List<FootbagPlace>? places;
  late FootbagWhere? choice = widget.current;
  late int radius = widget.current?.radiusMiles ?? 3;

  @override
  void initState() {
    super.initState();
    unawaited(_locate());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    if (WhereSheetPreview.places != null) {
      return setState(() {
        fix = WhereSheetPreview.fix;
        locating = false;
        places = WhereSheetPreview.places;
      });
    }
    final here = await NearMe.fix(ask: true);
    if (here != null) fix = (lat: here.latitude, lng: here.longitude);
    if (!mounted) return;
    setState(() => locating = false);
    await _search();
  }

  Future<void> _search() async {
    try {
      final found = await widget.client.fetchPlaces(
        lat: fix?.lat,
        lng: fix?.lng,
        query: query.text.trim(),
      );
      if (mounted) setState(() => places = found);
    } catch (e) {
      Logs().w('Place search failed', e);
      if (mounted) setState(() => places = const []);
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _suggest() async {
    final f = fix;
    if (f == null) return;
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = TextEditingController(text: query.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Nyfa.raised,
        shape: const RoundedRectangleBorder(),
        title: Text(l10n.suggestPlace.toUpperCase(), style: Nyfa.heading),
        content: TextField(
          controller: name,
          autofocus: true,
          style: Nyfa.bodyText,
          cursorColor: Nyfa.green,
          textCapitalization: TextCapitalization.words,
          decoration: Nyfa.input(l10n.suggestPlaceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel, style: Nyfa.bodyMuted),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.suggest,
              style: Nyfa.bodyText.copyWith(color: Nyfa.green),
            ),
          ),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    try {
      final place = await widget.client.suggestPlace(text, f.lat, f.lng);
      if (!mounted) return;
      if (!place.approved) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.suggestPlaceSent)));
      }
      setState(() {
        places = [place, ...?places];
        choice = FootbagWhere.place(
          place.id,
          label: place.name,
          radiusMiles: radius,
        );
      });
    } catch (e) {
      Logs().w('Suggesting a place failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = places;
    final selectedPlace = choice?.placeId;
    final spot = choice != null && choice!.placeId == null;

    Widget row({
      required Key key,
      required IconData icon,
      required String title,
      String? subtitle,
      String? badge,
      required bool selected,
      required VoidCallback onTap,
    }) => InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Nyfa.green : Nyfa.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Nyfa.bodyText.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? Nyfa.green : Nyfa.paper,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Nyfa.meta,
                    ),
                ],
              ),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  badge.toUpperCase(),
                  style: Nyfa.eyebrow.copyWith(fontSize: 12),
                ),
              ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18, color: Nyfa.green),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NyfaForm.section(l10n.where),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  key: const Key('PlaceSearch'),
                  controller: query,
                  onChanged: _onQuery,
                  style: Nyfa.bodyText,
                  cursorColor: Nyfa.green,
                  decoration: Nyfa.input(l10n.searchPlaces).copyWith(
                    prefixIcon: const Icon(Icons.search, color: Nyfa.muted),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (locating || list == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Nyfa.green,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else ...[
                      for (final p in list)
                        row(
                          key: Key('Place_${p.id}'),
                          icon: Icons.place_outlined,
                          title: p.name,
                          subtitle: p.distanceKm == null
                              ? null
                              : _miles(p.distanceKm!),
                          badge: p.approved ? null : l10n.pendingPlace,
                          selected: selectedPlace == p.id,
                          onTap: () => setState(
                            () => choice = FootbagWhere.place(
                              p.id,
                              label: p.name,
                              radiusMiles: radius,
                            ),
                          ),
                        ),
                      if (fix != null) ...[
                        row(
                          key: const Key('SomewhereElse'),
                          icon: Icons.my_location_outlined,
                          title: l10n.somewhereElse,
                          subtitle: l10n.somewhereElseExplain,
                          selected: spot,
                          onTap: () => setState(
                            () => choice = FootbagWhere.spot(
                              fix!.lat,
                              fix!.lng,
                              label: l10n.usingYourArea,
                              radiusMiles: radius,
                            ),
                          ),
                        ),
                        row(
                          key: const Key('SuggestPlace'),
                          icon: Icons.add_location_alt_outlined,
                          title: l10n.suggestPlace,
                          selected: false,
                          onTap: _suggest,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              NyfaForm.section(l10n.radiusLabel),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(l10n.radiusExplain, style: Nyfa.bodyMuted),
              ),
              NyfaForm.chips(
                keyPrefix: 'Radius',
                options: [
                  for (final m in const [1, 3, 10, 25])
                    (value: '$m', label: l10n.radiusMiles(m)),
                ],
                selected: {'$radius'},
                onToggle: (v) => setState(() {
                  radius = int.parse(v);
                  choice = choice?.withRadius(radius);
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: NyfaForm.action(
                  key: const Key('WhereDone'),
                  label: l10n.setLocation,
                  onPressed: choice == null
                      ? null
                      : () => Navigator.of(context).pop(choice),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miles, as the radius choices are: one unit on one sheet.
String _miles(double km) {
  final mi = km * 0.621371;
  return '${mi < 10 ? mi.toStringAsFixed(1) : mi.round()} mi';
}
