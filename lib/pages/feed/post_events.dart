// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/utils/footbag_api.dart';

/// Every post published from this device, as it is published.
///
/// The composer is opened from many places -- the feed's +, a challenge's
/// Enter, a trick's "I landed it", the welcome, the report sheet -- and only
/// the feed's + used to get the new post back. Everything else returned to a
/// screen that did not show it: you entered a challenge and the entries list
/// was missing yours. Now the composer announces each post here, and every
/// feed and header on screen decides for itself whether it belongs.
abstract final class PostEvents {
  static final _published = StreamController<FootbagPost>.broadcast();

  static Stream<FootbagPost> get published => _published.stream;

  static void announce(FootbagPost post) => _published.add(post);
}
