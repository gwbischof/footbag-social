// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The Footbag API client.
///
/// These cover the seam between the app and our own API — the one thing the
/// fork had never exercised. The transport is faked through
/// [prepareTestClient]'s `httpClient` parameter, so nothing here touches the
/// network or needs an API running.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';

import 'utils/test_client.dart';

/// Captures what the client sent, so the auth header can be asserted rather
/// than assumed.
class _Recorder {
  http.BaseRequest? last;
}

Future<Client> _clientReturning(
  _Recorder recorder, {
  required int status,
  required Object body,
}) => prepareTestClient(
  httpClient: MockClient((request) async {
    recorder.last = request;
    return http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mePayload = {
    'user_id': '@g:footbagsocial.com',
    'display_name': 'g',
    'bio': '',
    'city': null,
    'play_styles': <String>[],
    'discoverable': true,
    'show_sessions': true,
  };

  test('fetchMe parses the player', () async {
    final recorder = _Recorder();
    final client = await _clientReturning(recorder, status: 200, body: mePayload);

    final me = await client.fetchMe();

    expect(me.userId, '@g:footbagsocial.com');
    expect(me.displayName, 'g');
    expect(me.city, isNull);
    expect(me.playStyles, isEmpty);
    expect(me.discoverable, isTrue);
  });

  test('sends the Matrix access token as a bearer', () async {
    // The whole authentication design in one assertion: this API verifies the
    // Matrix token against the homeserver, so the app has nothing else to
    // send and nothing else to sign into.
    final recorder = _Recorder();
    final client = await _clientReturning(recorder, status: 200, body: mePayload);

    await client.fetchMe();

    expect(recorder.last!.headers['authorization'], 'Bearer ${client.accessToken}');
  });

  test('calls the configured API host, not the homeserver', () async {
    final recorder = _Recorder();
    final client = await _clientReturning(recorder, status: 200, body: mePayload);

    await client.fetchMe();

    expect(recorder.last!.url.toString(),
        '${AppSettings.footbagApiUrl.value}/me');
  });

  test('401 is reported as not signed in, not as a generic failure', () async {
    // The only failure a user can act on, and the action is specific: sign in
    // again. Everything else is ours to fix and theirs to retry.
    final recorder = _Recorder();
    final client = await _clientReturning(
      recorder,
      status: 401,
      body: {'detail': 'Invalid or expired token'},
    );

    await expectLater(
      client.fetchMe(),
      throwsA(isA<FootbagApiException>().having((e) => e.isNotSignedIn, 'isNotSignedIn', isTrue)),
    );
  });

  test('other failures carry the server detail', () async {
    final recorder = _Recorder();
    final client = await _clientReturning(
      recorder,
      status: 404,
      body: {'detail': "No dictionary entry 'nope'"},
    );

    await expectLater(
      client.fetchMe(),
      throwsA(
        isA<FootbagApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.detail, 'detail', "No dictionary entry 'nope'"),
      ),
    );
  });

  test('a non-JSON error body does not crash the parser', () async {
    // Gateways and the edge answer with HTML, not with FastAPI's `detail`.
    // Falling over while reporting a failure is how one outage becomes two.
    final recorder = _Recorder();
    final client = await _clientReturning(
      recorder,
      status: 502,
      body: '<html><body>Bad gateway</body></html>',
    );

    await expectLater(
      client.fetchMe(),
      throwsA(isA<FootbagApiException>().having((e) => e.statusCode, 'statusCode', 502)),
    );
  });
}
