// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
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
    int? clubId,
    FootbagWhere? where,
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
      'club_id': ?clubId,
      ...?where?.toJson(),
    }),
  );

  /// "Yes, still here." Moves the instant duration is counted to.
  Future<FootbagSession> checkInToSession(int id) async =>
      FootbagSession.fromJson(
        await _apiPostObject('sessions/$id/checkin', null),
      );

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
    bool? onboarded,
  }) async => FootbagPlayer.fromJson(
    await _apiPatchObject('me', {
      'display_name': ?displayName,
      'bio': ?bio,
      'city': ?city,
      'play_styles': ?playStyles,
      'discoverable': ?discoverable,
      'show_sessions': ?showSessions,
      'onboarded': ?onboarded,
    }),
  );

  /// Players who have chosen to be findable.
  ///
  /// Not geographic: "near me" needs a location this API does not store, so
  /// Discover filters by discipline and city until places exist.
  Future<List<FootbagPlayer>> discoverPlayers({
    String? style,
    String? city,
    String? query,
  }) async {
    final params = <String>[
      if (query != null && query.isNotEmpty)
        'q=${Uri.encodeQueryComponent(query)}',
      if (style != null) 'style=$style',
      if (city != null && city.isNotEmpty)
        'city=${Uri.encodeQueryComponent(city)}',
    ];
    final list = await _apiGetList(
      params.isEmpty
          ? 'discover/players'
          : 'discover/players?${params.join('&')}',
    );
    return list
        .map((e) => FootbagPlayer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sessions you could turn up to: running now, or scheduled ahead.
  Future<List<FootbagSession>> discoverSessions({
    String? type,
    double? lat,
    double? lng,
    double radiusKm = 25,
    bool running = false,
  }) async {
    final params = <String>[
      if (type != null) 'type=$type',
      if (lat != null && lng != null) ...[
        'lat=$lat',
        'lng=$lng',
        'radius_km=$radiusKm',
      ],
      if (running) 'running=true',
    ];
    final list = await _apiGetList(
      params.isEmpty
          ? 'discover/sessions'
          : 'discover/sessions?${params.join('&')}',
    );
    return list
        .map((e) => FootbagSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The leaderboard.
  ///
  /// Only corroborated metrics exist: play time, sessions and days played.
  /// Consecutive kicks and tricks landed are deliberately unrankable.
  Future<List<FootbagRanking>> fetchRankings({
    String metric = 'play_time',
    String window = 'month',
    int? club,
  }) async {
    final list = await _apiGetList(
      'rankings?metric=$metric&window=$window${club == null ? '' : '&club=$club'}',
    );
    return list
        .map((e) => FootbagRanking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Your own practice calendar. Days with nothing are absent, not zero.
  Future<List<FootbagHeatmapDay>> fetchHeatmap({int days = 147}) async {
    final list = await _apiGetList('me/heatmap?days=$days');
    return list
        .map((e) => FootbagHeatmapDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Browse the trick dictionary.
  ///
  /// [query] searches nicknames as well as names, which matters because the
  /// dictionary carries them — someone hunting "Atom Smasher" should find
  /// Atomic Mirage.
  Future<List<FootbagEntry>> fetchEntries({String? query, String? kind}) async {
    final params = <String>[
      if (query != null && query.isNotEmpty)
        'q=${Uri.encodeQueryComponent(query)}',
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
    final list = await _apiPutList('me/favourites', {
      'entry_slugs': entrySlugs,
    });
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

  /// Who the moderators are. Public to everyone signed in, per the doc:
  /// people should know who can remove their posts.
  Future<List<FootbagModerator>> fetchModerators() async {
    final list = await _apiGetList('moderators');
    return list
        .map((e) => FootbagModerator.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admins only.
  Future<void> appointModerator(String userId, {String role = 'moderator'}) =>
      _apiSend(
        'PUT',
        'moderators/${Uri.encodeComponent(userId)}',
        body: {'role': role},
      );

  /// Admins only. An admin cannot stand themselves down.
  Future<void> dismissModerator(String userId) =>
      _apiSend('DELETE', 'moderators/${Uri.encodeComponent(userId)}');

  // -- Goals and Try next -------------------------------------------------------

  /// Your goals for a session, in order. Private to you.
  Future<List<FootbagGoal>> fetchGoals(int sessionId) async {
    final list = await _apiGetList('sessions/$sessionId/goals');
    return list
        .map((e) => FootbagGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replace your goals for a session, in order.
  Future<List<FootbagGoal>> setGoals(
    int sessionId,
    List<String> entrySlugs,
  ) async {
    final list = await _apiPutList('sessions/$sessionId/goals', {
      'entry_slugs': entrySlugs,
    });
    return list
        .map((e) => FootbagGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// What the goal picker offers: last time, Try next, favourites.
  Future<List<FootbagIdea>> fetchGoalIdeas(int sessionId) async {
    final list = await _apiGetList('sessions/$sessionId/goal-ideas');
    return list
        .map((e) => FootbagIdea.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A few things to try next, each with its reason. Empty until a first
  /// report.
  Future<List<FootbagIdea>> fetchTryNext() async {
    final list = await _apiGetList('me/try-next');
    return list
        .map((e) => FootbagIdea.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -- Places ------------------------------------------------------------------

  /// Places you can pick -- approved ones and your own suggestions --
  /// nearest first when given a point.
  Future<List<FootbagPlace>> fetchPlaces({
    double? lat,
    double? lng,
    String? query,
  }) async {
    final params = <String>[
      if (lat != null && lng != null) ...['lat=$lat', 'lng=$lng'],
      if (query != null && query.isNotEmpty)
        'q=${Uri.encodeQueryComponent(query)}',
    ];
    final list = await _apiGetList(
      params.isEmpty ? 'places' : 'places?${params.join('&')}',
    );
    return list
        .map((e) => FootbagPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Suggest a place. A moderator's is approved at once.
  Future<FootbagPlace> suggestPlace(
    String name,
    double lat,
    double lng,
  ) async => FootbagPlace.fromJson(
    await _apiPostObject('places', {'name': name, 'lat': lat, 'lng': lng}),
  );

  /// Set, change or clear where a session is. Host only.
  Future<FootbagSession> setSessionLocation(
    int id,
    FootbagWhere? where,
  ) async => FootbagSession.fromJson(
    jsonDecode(
          (await _apiSend(
            'PUT',
            'sessions/$id/location',
            body: where?.toJson() ?? {},
          )).body,
        )
        as Map<String, dynamic>,
  );

  Future<List<FootbagPlace>> fetchPendingPlaces() async {
    final list = await _apiGetList('mod/places');
    return list
        .map((e) => FootbagPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approvePlace(int id) =>
      _apiSend('POST', 'mod/places/$id/approve');

  Future<void> rejectPlace(int id) => _apiSend('DELETE', 'mod/places/$id');

  // -- Clubs -------------------------------------------------------------------

  /// Clubs, biggest first. [mine] limits to clubs you are in or have asked
  /// to join.
  Future<List<FootbagClub>> fetchClubs({
    String? query,
    bool mine = false,
  }) async {
    final params = <String>[
      if (query != null && query.isNotEmpty)
        'q=${Uri.encodeQueryComponent(query)}',
      if (mine) 'mine=true',
    ];
    final list = await _apiGetList(
      params.isEmpty ? 'clubs' : 'clubs?${params.join('&')}',
    );
    return list
        .map((e) => FootbagClub.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FootbagClub> fetchClub(int id) async =>
      FootbagClub.fromJson(await _apiGetObject('clubs/$id'));

  Future<FootbagClub> createClub({
    required String name,
    String description = '',
    String location = '',
  }) async => FootbagClub.fromJson(
    await _apiPostObject('clubs', {
      'name': name,
      'description': description,
      'location': location,
    }),
  );

  Future<FootbagClub> editClub(
    int id, {
    String? name,
    String? description,
    String? location,
  }) async => FootbagClub.fromJson(
    await _apiPatchObject('clubs/$id', {
      'name': ?name,
      'description': ?description,
      'location': ?location,
    }),
  );

  Future<FootbagClub> askToJoinClub(int id) async =>
      FootbagClub.fromJson(await _apiPostObject('clubs/$id/join', null));

  Future<FootbagClub> leaveClub(int id) async => FootbagClub.fromJson(
    jsonDecode((await _apiSend('DELETE', 'clubs/$id/join')).body)
        as Map<String, dynamic>,
  );

  Future<FootbagClub> approveClubMember(int id, String userId) async =>
      FootbagClub.fromJson(
        await _apiPostObject(
          'clubs/$id/members/${Uri.encodeComponent(userId)}/approve',
          null,
        ),
      );

  /// Turn down a request, or remove a member.
  Future<FootbagClub> declineClubMember(int id, String userId) async =>
      FootbagClub.fromJson(
        await _apiPostObject(
          'clubs/$id/members/${Uri.encodeComponent(userId)}/decline',
          null,
        ),
      );

  Future<FootbagClub> inviteToClub(int id, String userId) async =>
      FootbagClub.fromJson(
        jsonDecode(
              (await _apiSend(
                'PUT',
                'clubs/$id/members/${Uri.encodeComponent(userId)}',
              )).body,
            )
            as Map<String, dynamic>,
      );

  Future<FootbagClub> setClubRole(int id, String userId, String role) async =>
      FootbagClub.fromJson(
        await _apiPostObject(
          'clubs/$id/members/${Uri.encodeComponent(userId)}/role',
          {'role': role},
        ),
      );

  /// What the club has on: running now, or scheduled.
  Future<List<FootbagSession>> fetchClubSessions(int id) async {
    final list = await _apiGetList('clubs/$id/sessions');
    return list
        .map((e) => FootbagSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -- Notifications ---------------------------------------------------------

  /// The inbox, grouped. Reading it marks it read on the server; each line
  /// still says whether it was unread, so the screen can show what is new.
  Future<List<FootbagInboxItem>> fetchInbox() async {
    final list = await _apiGetList('notifications');
    return list
        .map((e) => FootbagInboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Unread inbox lines, for the bell. Chat counts its own.
  Future<int> fetchUnreadCount() async =>
      (await _apiGetObject('notifications/unread'))['count'] as int? ?? 0;

  // -- Joining sessions --------------------------------------------------------

  /// Ask to join an open session. The host approves or declines.
  Future<FootbagSession> requestToJoin(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/join', null));

  /// Withdraw a request, or stop going.
  Future<FootbagSession> leaveSession(int id) async => FootbagSession.fromJson(
    jsonDecode((await _apiSend('DELETE', 'sessions/$id/join')).body)
        as Map<String, dynamic>,
  );

  Future<FootbagSession> approveAttendee(int id, String userId) async =>
      FootbagSession.fromJson(
        await _apiPostObject(
          'sessions/$id/attendees/${Uri.encodeComponent(userId)}/approve',
          null,
        ),
      );

  Future<FootbagSession> declineAttendee(int id, String userId) async =>
      FootbagSession.fromJson(
        await _apiPostObject(
          'sessions/$id/attendees/${Uri.encodeComponent(userId)}/decline',
          null,
        ),
      );

  /// Add someone directly -- an invite is an approval made first.
  Future<FootbagSession> inviteToSession(int id, String userId) async =>
      FootbagSession.fromJson(
        jsonDecode(
              (await _apiSend(
                'PUT',
                'sessions/$id/attendees/${Uri.encodeComponent(userId)}',
              )).body,
            )
            as Map<String, dynamic>,
      );

  /// Begin a session that was scheduled for later.
  Future<FootbagSession> startScheduledSession(int id) async =>
      FootbagSession.fromJson(await _apiPostObject('sessions/$id/start', null));

  // -- The feed --------------------------------------------------------------

  /// Resolve a media path from the API (relative and signed) to a URL.
  ///
  /// Media URLs carry their own permission, because a `<video>` element or an
  /// image cache cannot send a bearer token. So these load with no headers.
  Uri footbagMediaUri(String path) =>
      Uri.parse('${AppSettings.footbagApiUrl.value}/$path');

  /// One page of the community feed.
  ///
  /// One feed with filters, not several feeds: [author] is a profile, [entry]
  /// is a trick's clips, [lat]/[lng] is "near me". Pass [FootbagFeedPage.next]
  /// back as [cursor] for the following page.
  Future<FootbagFeedPage> fetchFeed({
    String sort = 'recent',
    String window = 'week',
    String? author,
    int? club,
    String? entry,
    bool tutorial = false,
    double? lat,
    double? lng,
    double radiusKm = 25,
    String? cursor,
    int limit = 10,
  }) async {
    final params = <String>[
      'sort=$sort',
      if (sort == 'top') 'window=$window',
      if (author != null) 'author=${Uri.encodeQueryComponent(author)}',
      if (club != null) 'club=$club',
      if (entry != null) 'entry=${Uri.encodeQueryComponent(entry)}',
      if (tutorial) 'tutorial=true',
      if (lat != null && lng != null) ...[
        'lat=$lat',
        'lng=$lng',
        'radius_km=$radiusKm',
      ],
      if (cursor != null) 'cursor=$cursor',
      'limit=$limit',
    ];
    return FootbagFeedPage.fromJson(
      await _apiGetObject('feed?${params.join('&')}'),
    );
  }

  Future<FootbagPost> fetchPost(int id) async =>
      FootbagPost.fromJson(await _apiGetObject('posts/$id'));

  /// Upload one photo or clip, ahead of the post it will go in.
  ///
  /// Streamed rather than read into memory, so a long clip does not sit in
  /// the app's heap twice. [onProgress] reports bytes sent where the platform
  /// can say; on web the browser buffers the body and progress jumps to done.
  Future<FootbagMedia> uploadMedia({
    required Stream<List<int>> bytes,
    required int length,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final token = accessToken;
    if (token == null) throw const FootbagApiException.notSignedIn();
    final request =
        http.StreamedRequest(
            'POST',
            Uri.parse('${AppSettings.footbagApiUrl.value}/media'),
          )
          ..headers['authorization'] = 'Bearer $token'
          ..headers['accept'] = 'application/json'
          ..headers['content-type'] = contentType
          ..contentLength = length;

    var sent = 0;
    unawaited(
      bytes
          .map((chunk) {
            sent += chunk.length;
            onProgress?.call(sent, length);
            return chunk;
          })
          .pipe(request.sink),
    );
    final response = await http.Response.fromStream(
      await httpClient.send(request),
    );
    if (response.statusCode == 401) {
      throw const FootbagApiException.notSignedIn();
    }
    if (response.statusCode >= 400) {
      throw FootbagApiException(response.statusCode, _detailOf(response));
    }
    return FootbagMedia.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<FootbagPost> createPost({
    String caption = '',
    List<int> mediaIds = const [],
    List<String> tags = const [],
    bool isTutorial = false,
    int? sessionId,
    int? clubId,
    String? placeName,
    double? lat,
    double? lng,
  }) async => FootbagPost.fromJson(
    await _apiPostObject('posts', {
      'caption': caption,
      'media_ids': mediaIds,
      'tags': tags,
      'is_tutorial': isTutorial,
      'session_id': ?sessionId,
      'club_id': ?clubId,
      'place_name': ?placeName,
      'lat': ?lat,
      'lng': ?lng,
    }),
  );

  Future<FootbagPost> editPost(
    int id, {
    String? caption,
    List<String>? tags,
    bool? isTutorial,
  }) async => FootbagPost.fromJson(
    await _apiPatchObject('posts/$id', {
      'caption': ?caption,
      'tags': ?tags,
      'is_tutorial': ?isTutorial,
    }),
  );

  Future<void> deletePost(int id) => _apiSend('DELETE', 'posts/$id');

  /// Give or take back a ♦. Returns the server's count, so a card shows the
  /// truth after an optimistic tap rather than its own guess.
  Future<({int count, bool reacted})> setReaction(int postId, bool on) async {
    final response = await _apiSend(
      on ? 'PUT' : 'DELETE',
      'posts/$postId/reaction',
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      count: json['reaction_count'] as int,
      reacted: json['reacted'] as bool,
    );
  }

  Future<List<FootbagComment>> fetchComments(int postId, {int? after}) async {
    final list = await _apiGetList(
      after == null
          ? 'posts/$postId/comments'
          : 'posts/$postId/comments?after=$after',
    );
    return list
        .map((e) => FootbagComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FootbagComment> addComment(int postId, String body) async =>
      FootbagComment.fromJson(
        await _apiPostObject('posts/$postId/comments', {'body': body}),
      );

  Future<void> deleteComment(int id) => _apiSend('DELETE', 'comments/$id');

  /// Flag a post or comment for the moderators. Exactly one of the two ids.
  Future<void> reportContent({
    int? postId,
    int? commentId,
    required String reason,
    String note = '',
  }) => _apiSend(
    'POST',
    postId != null ? 'posts/$postId/report' : 'comments/$commentId/report',
    body: {'reason': reason, 'note': note},
  );

  /// Someone's profile header: who they are and how much they have posted.
  Future<FootbagPlayerProfile> fetchPlayer(String userId) async =>
      FootbagPlayerProfile.fromJson(
        await _apiGetObject('players/${Uri.encodeComponent(userId)}'),
      );

  // -- Moderation --------------------------------------------------------------

  Future<List<FootbagQueueItem>> fetchModQueue({String state = 'open'}) async {
    final list = await _apiGetList('mod/queue?state=$state');
    return list
        .map((e) => FootbagQueueItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Remove or keep. Closes every open report on the same post or comment.
  Future<void> resolveContentReport(int reportId, {required bool remove}) =>
      _apiSend(
        'POST',
        'mod/reports/$reportId/resolve',
        body: {'action': remove ? 'remove' : 'keep'},
      );

  Future<void> restorePost(int id) => _apiSend('POST', 'mod/posts/$id/restore');

  Future<List<dynamic>> _apiPutList(
    String path,
    Map<String, dynamic> body,
  ) async =>
      jsonDecode((await _apiSend('PUT', path, body: body)).body)
          as List<dynamic>;

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
    return response.body.isEmpty
        ? 'HTTP ${response.statusCode}'
        : response.body;
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

  /// `moderator` or `admin` on your own profile; null for everyone else, and
  /// for you if you are neither.
  final String? role;

  bool get canModerate => role != null;

  /// Has seen the first-run welcome. Only meaningful on your own profile.
  final bool onboarded;

  const FootbagPlayer({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.city,
    required this.playStyles,
    required this.discoverable,
    required this.showSessions,
    this.role,
    this.onboarded = true,
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
    role: json['role'] as String?,
    onboarded: json['onboarded'] as bool? ?? true,
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

  final String? hostName;

  /// The club running it, if any. Its members are let in without asking.
  final FootbagClubRef? club;

  /// The circle anyone who can see the session sees. Centred near the spot,
  /// never on it.
  final FootbagArea? area;

  /// The exact spot. Only sent to the host, to people let in, and to the
  /// club's members for a club session.
  final FootbagPlace? place;

  /// Approved players. Visible to anyone who can see the session.
  final int attendeeCount;

  /// `host`, `requested`, `approved`, `declined`, or null for a stranger.
  final String? myState;

  /// Who is going. Null unless you host it or were approved -- the server
  /// leaves the names out for everyone else, which is the point of approval.
  final List<({String userId, String name})>? attendees;

  /// Pending requests. Only ever sent to the host.
  final List<({String userId, String name})>? requests;

  bool get isHost => myState == 'host';
  bool get isGoing => myState == 'approved';

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
    this.hostName,
    this.club,
    this.area,
    this.place,
    this.attendeeCount = 0,
    this.myState,
    this.attendees,
    this.requests,
  });

  static List<({String userId, String name})>? _people(Object? list) =>
      list == null
      ? null
      : [
          for (final p in list as List)
            (
              userId: (p as Map<String, dynamic>)['user_id'] as String,
              name: p['display_name'] as String,
            ),
        ];

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
    hostName: json['host_name'] as String?,
    club: FootbagClubRef.maybe(json['club']),
    area: json['area'] == null
        ? null
        : FootbagArea.fromJson(json['area'] as Map<String, dynamic>),
    place: json['place'] == null
        ? null
        : FootbagPlace.fromJson(json['place'] as Map<String, dynamic>),
    attendeeCount: json['attendee_count'] as int? ?? 0,
    myState: json['my_state'] as String?,
    attendees: _people(json['attendees']),
    requests: _people(json['requests']),
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
    return (parsed.isUtc
            ? parsed
            : DateTime.utc(
                parsed.year,
                parsed.month,
                parsed.day,
                parsed.hour,
                parsed.minute,
                parsed.second,
                parsed.millisecond,
              ))
        .toLocal();
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
  /// `entry` names a trick; `kicks` is a bare consecutive-kick count.
  ///
  /// Two of the doc's three kinds point at nothing in the dictionary, which is
  /// the whole of a kicking session — so the slug is nullable and the kind
  /// says which shape this row is.
  final String kind;
  final String? entrySlug;
  final FootbagGrade? grade;
  final int? count;
  final bool isFirst;

  const FootbagReportEntryInput({
    this.kind = 'entry',
    this.entrySlug,
    this.grade,
    this.count,
    this.isFirst = false,
  });

  /// A consecutive-kick count, which names no trick.
  const FootbagReportEntryInput.kicks(this.count)
    : kind = 'kicks',
      entrySlug = null,
      grade = null,
      isFirst = false;

  /// Whether this entry claims anything at all.
  ///
  /// Checked client-side so an untouched trick is simply left out of the
  /// request rather than sent and refused — the server's constraint is the
  /// backstop, not the user interface.
  bool get saysSomething => kind == 'kicks'
      ? count != null
      : (grade != null || count != null || isFirst);

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'entry_slug': ?entrySlug,
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
    kind: kind,
    entrySlug: entrySlug,
    grade: clearGrade ? null : (grade ?? this.grade),
    count: clearCount ? null : (count ?? this.count),
    isFirst: isFirst ?? this.isFirst,
  );
}

/// One trick in a filed report.
class FootbagReportEntry {
  final String kind;
  final String? entrySlug;
  final String? name;
  final FootbagGrade? grade;
  final int? count;
  final bool isFirst;

  const FootbagReportEntry({
    required this.kind,
    required this.entrySlug,
    required this.name,
    required this.grade,
    required this.count,
    required this.isFirst,
  });

  factory FootbagReportEntry.fromJson(Map<String, dynamic> json) =>
      FootbagReportEntry(
        kind: json['kind'] as String? ?? 'entry',
        entrySlug: json['entry_slug'] as String?,
        name: json['name'] as String?,
        grade: FootbagGrade.fromWire(json['grade']),
        count: json['count'] as int?,
        isFirst: json['is_first'] as bool? ?? false,
      );

  FootbagReportEntryInput toInput() => FootbagReportEntryInput(
    kind: kind,
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

/// One line of a leaderboard.
class FootbagRanking {
  final int position;
  final String userId;
  final String displayName;
  final String? city;

  /// Seconds for play time, a plain count for the others. The caller asked for
  /// a metric, so it already knows which.
  final int value;
  final bool isYou;

  const FootbagRanking({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.city,
    required this.value,
    required this.isYou,
  });

  factory FootbagRanking.fromJson(Map<String, dynamic> json) => FootbagRanking(
    position: json['position'] as int,
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    city: json['city'] as String?,
    value: json['value'] as int,
    isYou: json['is_you'] as bool? ?? false,
  );
}

/// One day of practice.
class FootbagHeatmapDay {
  final DateTime day;
  final int seconds;
  final int sessions;

  const FootbagHeatmapDay({
    required this.day,
    required this.seconds,
    required this.sessions,
  });

  factory FootbagHeatmapDay.fromJson(Map<String, dynamic> json) =>
      FootbagHeatmapDay(
        // A bare date, so no zone conversion: 2026-10-25 is that calendar day
        // wherever you read it, and toLocal() could shift it to the 24th.
        day: DateTime.parse(json['day'] as String),
        seconds: json['seconds'] as int,
        sessions: json['sessions'] as int,
      );
}

// ---------------------------------------------------------------------------
// The feed
// ---------------------------------------------------------------------------

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

/// Someone else's profile, as the header above their posts.
class FootbagPlayerProfile {
  final FootbagPlayer player;
  final int postCount;

  const FootbagPlayerProfile({required this.player, required this.postCount});

  factory FootbagPlayerProfile.fromJson(Map<String, dynamic> json) =>
      FootbagPlayerProfile(
        player: FootbagPlayer.fromJson(json),
        postCount: json['post_count'] as int? ?? 0,
      );
}

/// An image or clip in a post.
///
/// The size arrives with it so a card can reserve the right box before a byte
/// loads — a feed that jumps as images arrive is the most obvious sign of an
/// unfinished app — and the blurhash fills that box meanwhile.
class FootbagMedia {
  final int id;
  final bool isVideo;
  final int width;
  final int height;
  final String? blurhash;

  /// Relative and signed; resolve with [FootbagApi.footbagMediaUri].
  final String url;
  final String thumbUrl;

  /// Full-width still: the photo, or a clip's first frame before it plays.
  final String posterUrl;

  const FootbagMedia({
    required this.id,
    required this.isVideo,
    required this.width,
    required this.height,
    required this.blurhash,
    required this.url,
    required this.thumbUrl,
    required this.posterUrl,
  });

  double get aspectRatio => width / height;

  factory FootbagMedia.fromJson(Map<String, dynamic> json) => FootbagMedia(
    id: json['id'] as int,
    isVideo: json['kind'] == 'video',
    width: json['width'] as int,
    height: json['height'] as int,
    blurhash: json['blurhash'] as String?,
    url: json['url'] as String,
    thumbUrl: json['thumb_url'] as String,
    posterUrl: json['poster_url'] as String? ?? json['thumb_url'] as String,
  );
}

class FootbagTag {
  final String slug;
  final String name;

  const FootbagTag({required this.slug, required this.name});

  factory FootbagTag.fromJson(Map<String, dynamic> json) =>
      FootbagTag(slug: json['slug'] as String, name: json['name'] as String);
}

/// One trick on a shared session, and how it went.
class FootbagSessionLine {
  final String name;
  final String? grade;

  /// Absent unless the player chose to share numbers on their report.
  final int? count;
  final bool isFirst;

  const FootbagSessionLine({
    required this.name,
    required this.grade,
    required this.count,
    required this.isFirst,
  });

  factory FootbagSessionLine.fromJson(Map<String, dynamic> json) =>
      FootbagSessionLine(
        name: json['name'] as String,
        grade: json['grade'] as String?,
        count: json['count'] as int?,
        isFirst: json['is_first'] as bool? ?? false,
      );
}

/// The session a post came from: the post carries the media, this the results.
class FootbagSessionSummary {
  final int id;
  final String name;
  final String type;
  final Duration? duration;
  final int? kicks;
  final List<FootbagSessionLine> lines;

  const FootbagSessionSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.duration,
    required this.kicks,
    required this.lines,
  });

  factory FootbagSessionSummary.fromJson(Map<String, dynamic> json) =>
      FootbagSessionSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String,
        duration: json['duration_seconds'] == null
            ? null
            : Duration(seconds: json['duration_seconds'] as int),
        kicks: json['kicks'] as int?,
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            FootbagSessionLine.fromJson(l as Map<String, dynamic>),
        ],
      );
}

class FootbagComment {
  final int id;
  final int postId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  const FootbagComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  factory FootbagComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>;
    return FootbagComment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      authorId: author['user_id'] as String,
      authorName: author['display_name'] as String,
      body: json['body'] as String,
      createdAt: _time(json['created_at']),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}

/// A feed post: everything one card needs to draw, in one object.
///
/// [reactionCount] and [reacted] are mutable on purpose: a ♦ is applied to the
/// card the instant it is tapped and corrected from the server's answer, and
/// rebuilding an immutable post for one integer would be ceremony.
class FootbagPost {
  final int id;
  final String authorId;
  final String authorName;
  final String caption;
  final bool isTutorial;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<FootbagMedia> media;
  final List<FootbagTag> tags;
  final String? placeName;
  final FootbagSessionSummary? session;
  final FootbagClubRef? club;
  int reactionCount;
  bool reacted;
  int commentCount;
  final List<FootbagComment> commentsPreview;
  final bool isMine;
  final bool removed;

  FootbagPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.caption,
    required this.isTutorial,
    required this.createdAt,
    required this.editedAt,
    required this.media,
    required this.tags,
    required this.placeName,
    required this.session,
    this.club,
    required this.reactionCount,
    required this.reacted,
    required this.commentCount,
    required this.commentsPreview,
    required this.isMine,
    required this.removed,
  });

  factory FootbagPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>;
    return FootbagPost(
      id: json['id'] as int,
      authorId: author['user_id'] as String,
      authorName: author['display_name'] as String,
      caption: json['caption'] as String? ?? '',
      isTutorial: json['is_tutorial'] as bool? ?? false,
      createdAt: _time(json['created_at']),
      editedAt: json['edited_at'] == null ? null : _time(json['edited_at']),
      media: [
        for (final m in (json['media'] as List? ?? const []))
          FootbagMedia.fromJson(m as Map<String, dynamic>),
      ],
      tags: [
        for (final t in (json['tags'] as List? ?? const []))
          FootbagTag.fromJson(t as Map<String, dynamic>),
      ],
      placeName: json['place_name'] as String?,
      club: FootbagClubRef.maybe(json['club']),
      session: json['session'] == null
          ? null
          : FootbagSessionSummary.fromJson(
              json['session'] as Map<String, dynamic>,
            ),
      reactionCount: json['reaction_count'] as int? ?? 0,
      reacted: json['reacted'] as bool? ?? false,
      commentCount: json['comment_count'] as int? ?? 0,
      commentsPreview: [
        for (final c in (json['comments_preview'] as List? ?? const []))
          FootbagComment.fromJson(c as Map<String, dynamic>),
      ],
      isMine: json['is_mine'] as bool? ?? false,
      removed: json['removed'] as bool? ?? false,
    );
  }
}

class FootbagFeedPage {
  final List<FootbagPost> posts;

  /// Pass back as the cursor for the next page; null at the end.
  final String? next;

  const FootbagFeedPage({required this.posts, required this.next});

  factory FootbagFeedPage.fromJson(Map<String, dynamic> json) =>
      FootbagFeedPage(
        posts: [
          for (final p in (json['posts'] as List? ?? const []))
            FootbagPost.fromJson(p as Map<String, dynamic>),
        ],
        next: json['next'] as String?,
      );
}

/// One reported thing in the mod queue, with every report against it.
class FootbagQueueItem {
  final List<int> reportIds;
  final List<String> reasons;
  final List<String> notes;
  final String state;
  final FootbagPost? post;
  final FootbagComment? comment;
  final DateTime firstReportedAt;
  final String? actionedBy;

  const FootbagQueueItem({
    required this.reportIds,
    required this.reasons,
    required this.notes,
    required this.state,
    required this.post,
    required this.comment,
    required this.firstReportedAt,
    required this.actionedBy,
  });

  bool get isUrgent => reasons.contains('illegal');

  factory FootbagQueueItem.fromJson(Map<String, dynamic> json) =>
      FootbagQueueItem(
        reportIds: (json['report_ids'] as List).cast<int>(),
        reasons: (json['reasons'] as List).cast<String>(),
        notes: (json['notes'] as List? ?? const []).cast<String>(),
        state: json['state'] as String,
        post: json['post'] == null
            ? null
            : FootbagPost.fromJson(json['post'] as Map<String, dynamic>),
        comment: json['comment'] == null
            ? null
            : FootbagComment.fromJson(json['comment'] as Map<String, dynamic>),
        firstReportedAt: _time(json['first_reported_at']),
        actionedBy: json['actioned_by'] as String?,
      );
}

/// One line of the inbox.
class FootbagInboxItem {
  final String key;

  /// `reaction`, `comment`, `join_request`, `join_approved`, `post_removed`
  /// or `report_resolved`.
  final String kind;
  final List<({String userId, String name})> actors;
  final int actorCount;
  final int? postId;
  final String? postThumbUrl;
  final String postCaption;
  final int? sessionId;
  final String? sessionName;
  final FootbagClubRef? club;
  final String? outcome;
  final DateTime at;
  final bool unread;

  const FootbagInboxItem({
    required this.key,
    required this.kind,
    required this.actors,
    required this.actorCount,
    required this.postId,
    required this.postThumbUrl,
    required this.postCaption,
    required this.sessionId,
    required this.sessionName,
    this.club,
    required this.outcome,
    required this.at,
    required this.unread,
  });

  factory FootbagInboxItem.fromJson(Map<String, dynamic> json) {
    final post = json['post'] as Map<String, dynamic>?;
    final session = json['session'] as Map<String, dynamic>?;
    return FootbagInboxItem(
      key: json['key'] as String,
      kind: json['kind'] as String,
      actors: [
        for (final a in (json['actors'] as List? ?? const []))
          (
            userId: (a as Map<String, dynamic>)['user_id'] as String,
            name: a['display_name'] as String,
          ),
      ],
      actorCount: json['actor_count'] as int? ?? 0,
      postId: post?['id'] as int?,
      postThumbUrl: post?['thumb_url'] as String?,
      postCaption: post?['caption'] as String? ?? '',
      sessionId: session?['id'] as int?,
      sessionName: session?['name'] as String?,
      club: FootbagClubRef.maybe(json['club']),
      outcome: json['outcome'] as String?,
      at: _time(json['at']),
      unread: json['unread'] as bool? ?? false,
    );
  }
}

/// A club, named where something belongs to one.
class FootbagClubRef {
  final int id;
  final String name;

  const FootbagClubRef({required this.id, required this.name});

  static FootbagClubRef? maybe(Object? json) => json is Map<String, dynamic>
      ? FootbagClubRef(id: json['id'] as int, name: json['name'] as String)
      : null;
}

class FootbagClubMember {
  final String userId;
  final String name;
  final bool isOrganiser;
  final bool isCreator;

  const FootbagClubMember({
    required this.userId,
    required this.name,
    required this.isOrganiser,
    required this.isCreator,
  });
}

/// A club. All clubs are public, roster included.
class FootbagClub {
  final int id;
  final String name;
  final String description;
  final String location;
  final int memberCount;

  /// `requested`, `approved`, `declined`, or null.
  final String? myState;

  /// `member` or `organiser` once approved.
  final String? myRole;

  /// Only on a single club, not in lists.
  final List<FootbagClubMember>? members;

  /// Pending requests. Only ever sent to organisers.
  final List<({String userId, String name})>? requests;

  const FootbagClub({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.memberCount,
    required this.myState,
    required this.myRole,
    required this.members,
    required this.requests,
  });

  bool get isMember => myState == 'approved';
  bool get isOrganiser => myRole == 'organiser';

  factory FootbagClub.fromJson(Map<String, dynamic> json) => FootbagClub(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    location: json['location'] as String? ?? '',
    memberCount: json['member_count'] as int? ?? 0,
    myState: json['my_state'] as String?,
    myRole: json['my_role'] as String?,
    members: json['members'] == null
        ? null
        : [
            for (final m in json['members'] as List)
              FootbagClubMember(
                userId: (m as Map<String, dynamic>)['user_id'] as String,
                name: m['display_name'] as String,
                isOrganiser: m['role'] == 'organiser',
                isCreator: m['is_creator'] as bool? ?? false,
              ),
          ],
    requests: json['requests'] == null
        ? null
        : [
            for (final r in json['requests'] as List)
              (
                userId: (r as Map<String, dynamic>)['user_id'] as String,
                name: r['display_name'] as String,
              ),
          ],
  );
}

class FootbagModerator {
  final String userId;
  final String name;
  final bool isAdmin;

  /// Reports this moderator has decided.
  final int actions;

  const FootbagModerator({
    required this.userId,
    required this.name,
    required this.isAdmin,
    required this.actions,
  });

  factory FootbagModerator.fromJson(Map<String, dynamic> json) =>
      FootbagModerator(
        userId: json['user_id'] as String,
        name: json['display_name'] as String,
        isAdmin: json['role'] == 'admin',
        actions: json['actions'] as int? ?? 0,
      );
}

/// A known place to play.
class FootbagPlace {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final bool approved;
  final double? distanceKm;

  const FootbagPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.approved,
    this.distanceKm,
  });

  factory FootbagPlace.fromJson(Map<String, dynamic> json) => FootbagPlace(
    id: json['id'] as int,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    approved: json['approved'] as bool? ?? true,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
  );
}

/// The circle a session shows.
class FootbagArea {
  final double lat;
  final double lng;
  final int radiusM;

  const FootbagArea({
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  factory FootbagArea.fromJson(Map<String, dynamic> json) => FootbagArea(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    radiusM: json['radius_m'] as int,
  );
}

/// Where a session is, as chosen: a known place, or "somewhere else" from a
/// device fix the server uses once to draw the circle and does not keep.
class FootbagWhere {
  final int? placeId;
  final double? lat;
  final double? lng;
  final int radiusMiles;

  /// What to show back to the person choosing, e.g. the place's name.
  final String label;

  const FootbagWhere.place(int id, {required this.label, this.radiusMiles = 3})
    : placeId = id,
      lat = null,
      lng = null;

  const FootbagWhere.spot(
    double this.lat,
    double this.lng, {
    required this.label,
    this.radiusMiles = 3,
  }) : placeId = null;

  FootbagWhere withRadius(int miles) => placeId != null
      ? FootbagWhere.place(placeId!, label: label, radiusMiles: miles)
      : FootbagWhere.spot(lat!, lng!, label: label, radiusMiles: miles);

  Map<String, dynamic> toJson() => {
    'place_id': ?placeId,
    'lat': ?lat,
    'lng': ?lng,
    'radius_miles': radiusMiles,
  };
}

/// A goal for one session.
class FootbagGoal {
  final String entrySlug;
  final String name;

  const FootbagGoal({required this.entrySlug, required this.name});

  factory FootbagGoal.fromJson(Map<String, dynamic> json) => FootbagGoal(
    entrySlug: json['entry_slug'] as String,
    name: json['name'] as String,
  );
}

/// Something to work on, and the rule that offered it -- turned into a
/// sentence by the app, so it can be said in the player's language.
class FootbagIdea {
  final String entrySlug;
  final String name;

  /// next_step | string_ready | string_again | ease_off | unmet |
  /// last_session | favourite.
  final String rule;
  final String? becauseName;
  final int? count;

  const FootbagIdea({
    required this.entrySlug,
    required this.name,
    required this.rule,
    this.becauseName,
    this.count,
  });

  factory FootbagIdea.fromJson(Map<String, dynamic> json) => FootbagIdea(
    entrySlug: json['entry_slug'] as String,
    name: json['name'] as String,
    rule: json['rule'] as String,
    becauseName: json['because_name'] as String?,
    count: json['count'] as int?,
  );

  /// Where the goal picker files it.
  String get source => switch (rule) {
    'unmet' || 'last_session' => 'last',
    'favourite' => 'favourite',
    _ => 'next',
  };
}
