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
      FootbagPlayer.fromJson(await _apiGetObject('me'));

  /// The caller's own sessions, newest first.
  Future<List<FootbagSession>> fetchSessions({int limit = 50}) async {
    final list = await _apiGetList('sessions?limit=$limit');
    return list
        .map((e) => FootbagSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FootbagSession> fetchSession(int id) async =>
      FootbagSession.fromJson(await _apiGetObject('sessions/$id'));

  /// Start a session now.
  ///
  /// Every argument has a default because starting one is meant to be a single
  /// tap: the server names it, and the visibility switches come from their
  /// defaults. Anything wrong is fixed from the running screen.
  Future<FootbagSession> startSession({
    String? name,
    String type = 'freestyle',
    String joining = 'open',
    String onFeed = 'public',
    bool broadcast = true,
    String note = '',
  }) async => FootbagSession.fromJson(
    await _apiPostObject('sessions', {
      'name': ?name,
      'type': type,
      'joining': joining,
      'on_feed': onFeed,
      'broadcast': broadcast,
      'note': note,
    }),
  );

  /// "Yes, still here." Moves the instant duration is counted to.
  Future<FootbagSession> checkInToSession(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/checkin', null));

  Future<FootbagSession> stopSession(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/stop', null));

  Future<Map<String, dynamic>> _apiGetObject(String path) async =>
      jsonDecode((await _apiSend('GET', path)).body) as Map<String, dynamic>;

  Future<List<dynamic>> _apiGetList(String path) async =>
      jsonDecode((await _apiSend('GET', path)).body) as List<dynamic>;

  Future<Map<String, dynamic>> _apiPostObject(
    String path,
    Map<String, dynamic>? body,
  ) async =>
      jsonDecode((await _apiSend('POST', path, body: body)).body)
          as Map<String, dynamic>;

  Future<http.Response> _apiSend(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
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

    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

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

/// A session, as the API describes it.
class FootbagSession {
  final int id;
  final String name;
  final String type;
  final String hostId;
  final String joining;
  final String onFeed;
  final bool broadcast;
  final String note;

  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? lastCheckinAt;

  final bool isRunning;

  /// Counted to the last check-in, never to now. A session left running
  /// overnight reports the play that was confirmed, not the hours that passed.
  final Duration? duration;

  const FootbagSession({
    required this.id,
    required this.name,
    required this.type,
    required this.hostId,
    required this.joining,
    required this.onFeed,
    required this.broadcast,
    required this.note,
    required this.scheduledAt,
    required this.startedAt,
    required this.endedAt,
    required this.lastCheckinAt,
    required this.isRunning,
    required this.duration,
  });

  factory FootbagSession.fromJson(Map<String, dynamic> json) => FootbagSession(
    id: json['id'] as int,
    name: json['name'] as String,
    type: json['type'] as String,
    hostId: json['host_id'] as String,
    joining: json['joining'] as String,
    onFeed: json['on_feed'] as String,
    broadcast: json['broadcast'] as bool? ?? true,
    note: json['note'] as String? ?? '',
    scheduledAt: _parse(json['scheduled_at']),
    startedAt: _parse(json['started_at']),
    endedAt: _parse(json['ended_at']),
    lastCheckinAt: _parse(json['last_checkin_at']),
    isRunning: json['is_running'] as bool? ?? false,
    duration: json['duration_seconds'] == null
        ? null
        : Duration(seconds: json['duration_seconds'] as int),
  );

  /// The API sends UTC; everything on screen is local. Converting here rather
  /// than at each call site means a timestamp cannot reach a widget still in
  /// the wrong zone.
  static DateTime? _parse(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// How long the session has run *right now*, for a ticking clock.
  ///
  /// Only the live view should use this. [duration] is what the server counted
  /// and is the figure that gets recorded; this is the one that moves while
  /// you watch it, and the two deliberately disagree once a check-in lapses.
  Duration get elapsedNow {
    final start = startedAt;
    if (start == null) return Duration.zero;
    return (endedAt ?? DateTime.now()).difference(start);
  }
}
