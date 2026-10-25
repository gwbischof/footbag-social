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
    DateTime? scheduledAt,
  }) async => FootbagSession.fromJson(
    await _apiPostObject('sessions', {
      'name': ?name,
      'type': type,
      'joining': joining,
      'on_feed': onFeed,
      'broadcast': broadcast,
      'note': note,
      // The API takes AwareDatetime and refuses a naive one, so always send
      // UTC with an offset rather than the device's wall clock.
      'scheduled_at': ?scheduledAt?.toUtc().toIso8601String(),
    }),
  );

  /// "Yes, still here." Moves the instant duration is counted to.
  Future<FootbagSession> checkInToSession(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/checkin', null));

  Future<FootbagSession> stopSession(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/stop', null));

  /// Edit your own profile.
  ///
  /// PATCH semantics: anything left null is untouched, so a screen that edits
  /// one switch cannot clobber fields it never showed. [city] is the exception
  /// — pass an empty string to clear it, since null already means "unchanged".
  Future<FootbagPlayer> updateMe({
    String? displayName,
    String? bio,
    String? city,
    List<String>? playStyles,
    bool? discoverable,
    bool? showSessions,
  }) async => FootbagPlayer.fromJson(
    await _apiPatchObject('me', {
      'display_name': ?displayName,
      'bio': ?bio,
      'city': ?city,
      'play_styles': ?playStyles,
      'discoverable': ?discoverable,
      'show_sessions': ?showSessions,
    }),
  );

  /// Browse the trick dictionary.
  ///
  /// [query] searches nicknames as well as names, which matters because the
  /// dictionary carries them — someone hunting "Atom Smasher" should find
  /// Atomic Mirage.
  Future<List<FootbagEntry>> fetchEntries({String? query, String? kind}) async {
    final params = <String>[
      if (query != null && query.isNotEmpty) 'q=${Uri.encodeQueryComponent(query)}',
      if (kind != null) 'kind=$kind',
    ];
    final list = await _apiGetList(
      params.isEmpty ? 'tricks' : 'tricks?${params.join('&')}',
    );
    return list
        .map((e) => FootbagEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The tricks this player is working on, in their own order.
  Future<List<FootbagFavourite>> fetchFavourites() async {
    final list = await _apiGetList('me/favourites');
    return list
        .map((e) => FootbagFavourite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replace the favourites list, in order.
  ///
  /// The whole list, not one trick at a time — reordering is the common edit,
  /// and positions are unique per player, so an incremental update would have
  /// to pass through a state the server rejects.
  Future<List<FootbagFavourite>> setFavourites(List<String> entrySlugs) async {
    final list = await _apiPutList('me/favourites', {'entry_slugs': entrySlugs});
    return list
        .map((e) => FootbagFavourite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The report for a session, or `null` if none has been filed.
  ///
  /// Absence is a normal state — most sessions are unreported until they end —
  /// so it is a return value rather than an exception.
  Future<FootbagReport?> fetchReport(int sessionId) async {
    try {
      return FootbagReport.fromJson(
        await _apiGetObject('sessions/$sessionId/report'),
      );
    } on FootbagApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// File or replace a session's report.
  Future<FootbagReport> fileReport(
    int sessionId, {
    String comment = '',
    bool includeNumbers = true,
    List<FootbagReportEntryInput> entries = const [],
  }) async => FootbagReport.fromJson(
    await _apiPutObject('sessions/$sessionId/report', {
      'comment': comment,
      'include_numbers': includeNumbers,
      'entries': entries.map((e) => e.toJson()).toList(),
    }),
  );

  Future<List<dynamic>> _apiPutList(
    String path,
    Map<String, dynamic> body,
  ) async =>
      jsonDecode((await _apiSend('PUT', path, body: body)).body) as List<dynamic>;

  Future<Map<String, dynamic>> _apiPatchObject(
    String path,
    Map<String, dynamic> body,
  ) async =>
      jsonDecode((await _apiSend('PATCH', path, body: body)).body)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> _apiPutObject(
    String path,
    Map<String, dynamic> body,
  ) async =>
      jsonDecode((await _apiSend('PUT', path, body: body)).body)
          as Map<String, dynamic>;

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
  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.parse(value as String);
    // A timestamp without an offset parses as *local*, so toLocal() is a no-op
    // and every time is off by the zone -- which would start the elapsed clock
    // at +5:00 in New York. The API sends UTC, so read a naive value as UTC
    // rather than trusting the device's zone to be the server's.
    return (parsed.isUtc ? parsed : DateTime.utc(
      parsed.year, parsed.month, parsed.day,
      parsed.hour, parsed.minute, parsed.second, parsed.millisecond,
    )).toLocal();
  }

  /// Scheduled, and not yet begun.
  ///
  /// Neither running nor finished, so without this a session scheduled for
  /// Saturday files itself under "Past sessions" and offers to report on a
  /// thing that has not happened.
  bool get isUpcoming => startedAt == null && scheduledAt != null;

  /// How long the session has run *right now*, for a ticking clock.
  ///
  /// Only the live view should use this. [duration] is what the server counted
  /// and is the figure that gets recorded; this is the one that moves while
  /// you watch it, and the two deliberately disagree once a check-in lapses.
  Duration get elapsedNow {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final span = (endedAt ?? DateTime.now()).difference(start);
    // Clamped: Dart's % is non-negative, so a skewed device clock would render
    // -5 minutes as a plausible-looking 00:55:00 rather than as obviously wrong.
    return span.isNegative ? Duration.zero : span;
  }
}

/// The four rungs of the ladder, in order.
///
/// A progression, not a set of labels, so the order is meaningful and
/// [index] is the rung. "Footing" sits between trying and hitting because
/// getting a foot on the bag is the real first milestone on most tricks.
enum FootbagGrade {
  tried,
  footing,
  hitting,
  consistent;

  /// The wire value. Matches the API's `grade` strings exactly.
  String get wire => name;

  /// Unknown rungs decode to null rather than throwing.
  ///
  /// firstWhere without orElse would turn a fifth rung added server-side into
  /// "Bad state: No element" on the report screen -- a client crash caused by
  /// a backwards-compatible server change.
  static FootbagGrade? fromWire(Object? value) =>
      FootbagGrade.values.where((g) => g.wire == value).firstOrNull;
}

/// A trick a player is working on.
class FootbagFavourite {
  final String entrySlug;
  final String name;
  final int position;

  const FootbagFavourite({
    required this.entrySlug,
    required this.name,
    required this.position,
  });

  factory FootbagFavourite.fromJson(Map<String, dynamic> json) =>
      FootbagFavourite(
        entrySlug: json['entry_slug'] as String,
        name: json['name'] as String,
        position: json['position'] as int,
      );
}

/// One trick being reported on, as the client builds it.
///
/// Both [grade] and [count] are nullable, and the API rejects an entry that
/// carries neither and is not a first. That asymmetry is deliberate: a player
/// who only wants to say "worked on this" should not have to invent a number.
class FootbagReportEntryInput {
  final String entrySlug;
  final FootbagGrade? grade;
  final int? count;
  final bool isFirst;

  const FootbagReportEntryInput({
    required this.entrySlug,
    this.grade,
    this.count,
    this.isFirst = false,
  });

  /// Whether this entry claims anything at all.
  ///
  /// Checked client-side so an untouched trick is simply left out of the
  /// request rather than sent and refused — the server's constraint is the
  /// backstop, not the user interface.
  bool get saysSomething => grade != null || count != null || isFirst;

  Map<String, dynamic> toJson() => {
    'entry_slug': entrySlug,
    'grade': ?grade?.wire,
    'count': ?count,
    'is_first': isFirst,
  };

  FootbagReportEntryInput copyWith({
    FootbagGrade? grade,
    bool clearGrade = false,
    int? count,
    bool clearCount = false,
    bool? isFirst,
  }) => FootbagReportEntryInput(
    entrySlug: entrySlug,
    grade: clearGrade ? null : (grade ?? this.grade),
    count: clearCount ? null : (count ?? this.count),
    isFirst: isFirst ?? this.isFirst,
  );
}

/// One trick in a filed report.
class FootbagReportEntry {
  final String entrySlug;
  final String name;
  final FootbagGrade? grade;
  final int? count;
  final bool isFirst;

  const FootbagReportEntry({
    required this.entrySlug,
    required this.name,
    required this.grade,
    required this.count,
    required this.isFirst,
  });

  factory FootbagReportEntry.fromJson(Map<String, dynamic> json) =>
      FootbagReportEntry(
        entrySlug: json['entry_slug'] as String,
        name: json['name'] as String,
        grade: FootbagGrade.fromWire(json['grade']),
        count: json['count'] as int?,
        isFirst: json['is_first'] as bool? ?? false,
      );

  FootbagReportEntryInput toInput() => FootbagReportEntryInput(
    entrySlug: entrySlug,
    grade: grade,
    count: count,
    isFirst: isFirst,
  );
}

/// A filed report.
class FootbagReport {
  final int id;
  final int sessionId;
  final String comment;
  final bool includeNumbers;
  final List<FootbagReportEntry> entries;

  /// The tricks landed for the first time. Derived by the server.
  final List<String> firsts;

  const FootbagReport({
    required this.id,
    required this.sessionId,
    required this.comment,
    required this.includeNumbers,
    required this.entries,
    required this.firsts,
  });

  factory FootbagReport.fromJson(Map<String, dynamic> json) => FootbagReport(
    id: json['id'] as int,
    sessionId: json['session_id'] as int,
    comment: json['comment'] as String? ?? '',
    includeNumbers: json['include_numbers'] as bool? ?? true,
    entries: (json['entries'] as List? ?? const [])
        .map((e) => FootbagReportEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    firsts: (json['firsts'] as List? ?? const []).cast<String>(),
  );
}

/// The four play-style disciplines.
///
/// Deliberately the same four words as four of the five session types: the doc
/// requires one vocabulary in both places so "freestyle players near me" and
/// "freestyle sessions near me" hit the same enum. Casual is the fifth session
/// type and has no chip, because it is not a discipline.
enum FootbagDiscipline {
  kicking,
  freestyle,
  net,
  stitching;

  String get wire => name;
}

/// A dictionary entry: a trick, a composite, or a string.
class FootbagEntry {
  final String slug;
  final String name;

  /// `trick`, `composite` or `string`.
  final String kind;
  final String description;

  /// Nicknames. The dictionary carries 94 of them, so they are worth showing.
  final List<String> aka;

  /// The breakdown, e.g. `['dex', 'dex', 'del']`.
  final List<String> adds;

  const FootbagEntry({
    required this.slug,
    required this.name,
    required this.kind,
    required this.description,
    required this.aka,
    required this.adds,
  });

  factory FootbagEntry.fromJson(Map<String, dynamic> json) => FootbagEntry(
    slug: json['slug'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String,
    description: json['description'] as String? ?? '',
    aka: (json['aka'] as List? ?? const []).cast<String>(),
    adds: (json['adds'] as List? ?? const []).cast<String>(),
  );
}
