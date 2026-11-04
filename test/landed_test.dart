// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// "Landed it": the post that says you hit a trick.
//
// The wire format both ways, the card that leads with the trick, and the
// trick page's "who has landed it". Everything is drawn from JSON shaped like
// the API's, through the real parsers, with no network.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/pages/feed/widgets/trick_header.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/test_client.dart';

Map<String, dynamic> _post({Map<String, dynamic>? landed}) => {
  'id': 7,
  'author': {'user_id': '@k:footbagsocial.com', 'display_name': 'Kenji'},
  'caption': 'Three months of footing it.',
  'is_tutorial': false,
  'created_at': '2026-11-03T20:00:00+00:00',
  'media': <Object>[],
  'tags': [
    {'slug': 'paradox-mirage', 'name': 'Paradox Mirage'},
  ],
  'landed': ?landed,
  'reaction_count': 0,
  'reacted': false,
  'comment_count': 0,
  'comments_preview': <Object>[],
  'is_mine': false,
  'removed': false,
};

class _Actions implements PostActions {
  final opened = <String>[];

  @override
  Uri resolve(String path) => Uri.parse('http://localhost/$path');

  @override
  Widget avatar(String userId, String name, double size) =>
      SizedBox(width: size, height: size);

  @override
  Future<({int count, bool reacted})> setReaction(FootbagPost post, bool on) async =>
      (count: post.reactionCount, reacted: on);

  @override
  Future<void> openComments(FootbagPost post, {required bool typing}) async {}

  @override
  void openAuthor(String userId, String name) {}

  @override
  void openTag(FootbagTag tag) => opened.add(tag.slug);

  @override
  void openClub(FootbagClubRef club) {}

  @override
  void openMenu(FootbagPost post) {}
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: L10n.localizationsDelegates,
  supportedLocales: L10n.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

FootbagTrickDetail _trick({int count = 0, List<Map<String, String>> by = const []}) =>
    FootbagTrickDetail.fromJson({
      'entry': {
        'slug': 'paradox-mirage',
        'name': 'Paradox Mirage',
        'kind': 'composite',
        'description': '',
        'aka': <String>[],
        'adds': <String>[],
      },
      'mine': {'best_grade': null, 'hit_sessions': 0, 'favourite': false},
      'landed_count': count,
      'landed_by': by,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wire format', () {
    test('a landed post parses its trick and first', () {
      final post = FootbagPost.fromJson(
        _post(landed: {'slug': 'paradox-mirage', 'name': 'Paradox Mirage', 'first': true}),
      );
      expect(post.landed, (slug: 'paradox-mirage', name: 'Paradox Mirage', first: true));
    });

    test('an ordinary post has no landed trick', () {
      expect(FootbagPost.fromJson(_post()).landed, isNull);
    });

    test('createPost sends the trick, and first only when it is one', () async {
      final sent = <Map<String, dynamic>>[];
      final client = await prepareTestClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/posts')) {
            sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode(_post()),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.createPost(landed: 'paradox-mirage', landedFirst: true);
      await client.createPost(landed: 'paradox-mirage');
      await client.createPost(caption: 'just words', landedFirst: true);

      expect(sent[0]['landed'], 'paradox-mirage');
      expect(sent[0]['landed_first'], isTrue);
      expect(sent[1].containsKey('landed_first'), isFalse);
      // A first with no trick is not a thing the API accepts; never send it.
      expect(sent[2].containsKey('landed'), isFalse);
      expect(sent[2].containsKey('landed_first'), isFalse);
    });
  });

  group('the card', () {
    testWidgets('leads with the trick, and marks a first', (tester) async {
      final actions = _Actions();
      final post = FootbagPost.fromJson(
        _post(landed: {'slug': 'paradox-mirage', 'name': 'Paradox Mirage', 'first': true}),
      );
      await tester.pumpWidget(_app(PostCard(post: post, actions: actions)));
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Landed Paradox Mirage')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('Landed Paradox Mirage')));
      expect(actions.opened, ['paradox-mirage']);
    });

    testWidgets('an ordinary post has no landed line', (tester) async {
      await tester.pumpWidget(
        _app(PostCard(post: FootbagPost.fromJson(_post()), actions: _Actions())),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Landed ')), findsNothing);
      expect(find.text('First'), findsNothing);
    });
  });

  group('the trick page', () {
    setUp(() {
      PlayerAvatar.previewBuilder = (userId, name, size) =>
          SizedBox(key: Key('Face_$userId'), width: size, height: size);
    });
    tearDown(() {
      TrickHeader.preview = null;
      PlayerAvatar.previewBuilder = null;
    });

    testWidgets('shows who has landed it', (tester) async {
      TrickHeader.preview = _trick(
        count: 8,
        by: [
          {'user_id': '@k:x', 'display_name': 'Kenji'},
          {'user_id': '@l:x', 'display_name': 'Landes'},
        ],
      );
      await tester.pumpWidget(_app(const TrickHeader(slug: 'paradox-mirage')));
      await tester.pumpAndSettle();

      expect(find.text('8 players have landed it'), findsOneWidget);
      expect(find.byKey(const Key('Face_@k:x')), findsOneWidget);
      expect(find.byKey(const Key('TrickLanded')), findsOneWidget);
    });

    testWidgets('invites the first landing when nobody has', (tester) async {
      TrickHeader.preview = _trick();
      await tester.pumpWidget(_app(const TrickHeader(slug: 'paradox-mirage')));
      await tester.pumpAndSettle();

      expect(find.text('Nobody has posted landing it yet'), findsOneWidget);
      expect(find.byKey(const Key('TrickLanded')), findsOneWidget);
    });
  });
}
