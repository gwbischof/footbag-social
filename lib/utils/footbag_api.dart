// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:footbag_network/config/setting_keys.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// The Footbag API — sessions, reports, clubs and the trick dictionary.
///
/// Everything Matrix does not: Matrix carries the chat, this carries the
/// product. It is a separate service on its own host, so the two never share a
/// database and neither can take the other down.
///
/// Written as an extension on [Client] rather than a service object, matching
/// `client_download_content_extension.dart`. That is not only for consistency:
/// every call needs the Matrix access token and the configured http client,
/// and both already live on [Client]. A separate service would have to be
/// handed the same object to be useful.
///
/// **Authentication is the Matrix token.** This API verifies it against the
/// homeserver's `whoami`, so there is one session across chat and the app and
/// one identity — an MXID. There is nothing extra to sign into, and an account
/// still awaiting moderator approval holds no token to present.
extension FootbagApi on Client {
  /// The signed-in player, created on the server on first call.
  Future<FootbagPlayer> fetchMe() async =>
      FootbagPlayer.fromJson(await _apiGet('me'));

  Future<Map<String, dynamic>> _apiGet(String path) async {
    final response = await _apiSend('GET', path);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _apiSend(String method, String path) async {
    // Read the token per request, never cached. `client_manager.dart` wires
    // onSoftLogout to refreshAccessToken, so it rotates underneath us; a token
    // captured once would start failing at a moment unrelated to anything the
    // user did.
    final token = accessToken;
    if (token == null) throw const FootbagApiException.notSignedIn();

    final uri = Uri.parse('${AppSettings.footbagApiUrl.value}/$path');

    // `httpClient`, not a bare http.Client: this is the RetryClient carrying
    // the bundled ISRG roots from custom_http_client.dart, so retries and the
    // Android TLS fix come for free.
    final request = http.Request(method, uri)
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'application/json';

    final response = await http.Response.fromStream(
      await httpClient.send(request),
    );

    if (response.statusCode == 401) {
      // The token the homeserver issued is not one it will vouch for. Worth
      // distinguishing from every other failure, because it is the only one a
      // client can fix, and it fixes it by signing in again.
      throw const FootbagApiException.notSignedIn();
    }
    if (response.statusCode >= 400) {
      throw FootbagApiException(response.statusCode, _detailOf(response));
    }
    return response;
  }

  /// FastAPI puts the human-readable reason in `detail`. Falling back to the
  /// raw body matters when the failure came from in front of the app — a
  /// gateway or the edge — where the body is HTML and `detail` does not exist.
  static String _detailOf(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Not JSON. Fall through to the body.
    }
    return response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body;
  }
}

/// A person, as the API describes them.
class FootbagPlayer {
  /// The MXID, e.g. `@g:footbagsocial.com`. The same identifier as in chat,
  /// deliberately — one person should not have two names depending on which
  /// half of the app you are looking at.
  final String userId;
  final String displayName;
  final String bio;
  final String? city;
  final List<String> playStyles;
  final bool discoverable;
  final bool showSessions;

  const FootbagPlayer({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.city,
    required this.playStyles,
    required this.discoverable,
    required this.showSessions,
  });

  factory FootbagPlayer.fromJson(Map<String, dynamic> json) => FootbagPlayer(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    bio: json['bio'] as String? ?? '',
    city: json['city'] as String?,
    playStyles:
        (json['play_styles'] as List?)?.cast<String>() ?? const <String>[],
    discoverable: json['discoverable'] as bool? ?? true,
    showSessions: json['show_sessions'] as bool? ?? true,
  );
}

/// A call to the Footbag API failed.
///
/// [notSignedIn] is separated from the rest because it is the only failure the
/// user can act on, and the action is specific: sign in again. Everything else
/// is ours to fix and theirs to retry.
class FootbagApiException implements Exception {
  final int statusCode;
  final String detail;

  const FootbagApiException(this.statusCode, this.detail);

  const FootbagApiException.notSignedIn()
    : statusCode = 401,
      detail = 'Not signed in';

  bool get isNotSignedIn => statusCode == 401;

  @override
  String toString() => 'FootbagApiException($statusCode): $detail';
}
