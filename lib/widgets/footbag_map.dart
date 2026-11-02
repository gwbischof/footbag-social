// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:footbag_network/config/app_config.dart';
import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// The app's map: where sessions are, never where people are.
///
/// Sessions are circles -- the area a stranger is allowed to see -- and an
/// exact spot, when the viewer has been let in, is the club's ♦. Tiles are
/// OpenStreetMap's, turned to dim greys so the map sits back in the club's
/// black and the green is the only colour on it -- and the credit their
/// licence asks for is always on the map.
class FootbagMap extends StatelessWidget {
  /// Luminance, inverted and squeezed into a narrow dark band: paper-white
  /// land lands near the ground colour, roads and labels a few steps above.
  /// The library's own dark mode inverts hue as well, which leaves pink
  /// roads and blue water fighting the green.
  static const _dimGreys = ColorFilter.matrix([
    -0.106, -0.358, -0.036, 0, 142, //
    -0.106, -0.358, -0.036, 0, 140,
    -0.106, -0.358, -0.036, 0, 136,
    0, 0, 0, 1, 0,
  ]);

  final List<FootbagArea> areas;

  /// An exact spot, for someone allowed to see it.
  final LatLng? pin;

  /// Where the viewer is, on their own screen only. Never sent anywhere.
  final LatLng? you;

  /// Tapped inside a circle: which one.
  final ValueChanged<int>? onAreaTap;

  final bool interactive;

  const FootbagMap({
    this.areas = const [],
    this.pin,
    this.you,
    this.onAreaTap,
    this.interactive = false,
    super.key,
  });

  /// The box a circle occupies, so the map can frame it.
  static LatLngBounds _bounds(
    Iterable<({LatLng centre, double radiusM})> shapes,
  ) {
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final s in shapes) {
      final dLat = s.radiusM / 111320;
      final dLng =
          s.radiusM /
          (111320 *
              math.max(math.cos(s.centre.latitude * math.pi / 180), 0.01));
      south = math.min(south, s.centre.latitude - dLat);
      north = math.max(north, s.centre.latitude + dLat);
      west = math.min(west, s.centre.longitude - dLng);
      east = math.max(east, s.centre.longitude + dLng);
    }
    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final shapes = [
      for (final a in areas)
        (centre: LatLng(a.lat, a.lng), radiusM: a.radiusM.toDouble()),
      if (pin != null) (centre: pin!, radiusM: 250.0),
      if (you != null) (centre: you!, radiusM: 1500.0),
    ];
    final fit = shapes.isEmpty
        ? null
        : CameraFit.bounds(
            bounds: _bounds(shapes),
            padding: const EdgeInsets.all(24),
          );

    return ClipRect(
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: fit,
          initialCenter: const LatLng(40.7308, -73.9973),
          initialZoom: 11,
          backgroundColor: Nyfa.raised,
          interactionOptions: InteractionOptions(
            flags: interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
          onTap: onAreaTap == null
              ? null
              : (_, point) {
                  // The innermost circle containing the tap, so overlapping
                  // sessions resolve to the one that is most specifically here.
                  const distance = Distance();
                  int? best;
                  for (var i = 0; i < areas.length; i++) {
                    final d = distance.as(
                      LengthUnit.Meter,
                      point,
                      LatLng(areas[i].lat, areas[i].lng),
                    );
                    if (d <= areas[i].radiusM &&
                        (best == null ||
                            areas[i].radiusM < areas[best].radiusM)) {
                      best = i;
                    }
                  }
                  if (best != null) onAreaTap!(best);
                },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: AppConfig.appId,
            tileBuilder: (context, tile, _) =>
                ColorFiltered(colorFilter: _dimGreys, child: tile),
            maxZoom: 19,
          ),
          CircleLayer(
            circles: [
              for (final a in areas)
                CircleMarker(
                  point: LatLng(a.lat, a.lng),
                  radius: a.radiusM.toDouble(),
                  useRadiusInMeter: true,
                  // A wash, not text, so alpha is fine here: the map must
                  // show through so the area means something.
                  color: Nyfa.green.withValues(alpha: 0.16),
                  borderColor: Nyfa.green,
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (you != null)
                Marker(
                  point: you!,
                  width: 16,
                  height: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Nyfa.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: Nyfa.ground, width: 3),
                    ),
                  ),
                ),
              if (pin != null)
                Marker(
                  point: pin!,
                  width: 24,
                  height: 30,
                  child: const Diamond(size: 30, color: Nyfa.green),
                ),
            ],
          ),
          // The credit OpenStreetMap's licence requires, in the app's own
          // type rather than the library's unstyled default.
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              color: Nyfa.ground,
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
              child: Text(
                l10n.mapAttribution,
                style: Nyfa.bodyMuted.copyWith(fontSize: 10, height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
