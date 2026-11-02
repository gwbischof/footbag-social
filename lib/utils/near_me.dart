// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:matrix/matrix.dart';

/// One rough fix for "near me", held in memory and never stored or sent
/// anywhere but as the centre of a search.
///
/// Low accuracy on purpose: "near me" means the neighbourhood, and a coarse
/// fix is faster, kinder to the battery, and less to leak.
abstract final class NearMe {
  static LatLng? _last;

  /// The fix from earlier in this run of the app, if there was one.
  static LatLng? get last => _last;

  /// A fix, or null. With [ask] false this never prompts: a screen that
  /// opens should not greet people with a permission dialog, only use a
  /// permission they already gave.
  static Future<LatLng?> fix({bool ask = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _last = LatLng(p.latitude, p.longitude);
    } catch (e) {
      Logs().v('No location for near me', e);
      return null;
    }
  }
}
