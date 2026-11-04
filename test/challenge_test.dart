// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// Challenges: the banner on the feed, the page's header in each state, the
// label on an entry, and the "how long is left" wording.

import 'package:flutter_test/flutter_test.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/l10n/l10n_en.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/challenge_card.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';

final _now = DateTime.now();

FootbagChallenge _challenge({
  String state = 'active',
  Duration startsIn = const Duration(days: -3),
  Duration endsIn = const Duration(days: 12, hours: 1),
  int entries = 12,
  int players = 7,
  int mine = 0,
  int max = 3,
}) => FootbagChallenge.fromJson({
  'id': 1,
  'slug': 'noplantnovember-2026',
  'title': 'NoPlantNovember',
  'body': 'Film yourself not planting while freestyling.',
  'starts_at': _now.add(startsIn).toUtc().toIso8601String(),
  'ends_at': _now.add(endsIn).toUtc().toIso8601String(),
  'max_entries': max,
  'state': state,
  'entry_count': entries,
  'entrant_count': players,
  'entrants': [
    {'user_id': '@d:x', 'display_name': 'Derek'},
    {'user_id': '@k:x', 'display_name': 'Kenji'},
  ],
  'my_entries': mine,
});

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: L10n.localizationsDelegates,
  supportedLocales: L10n.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

class _Actions implements PostActions {
  final opened = <String>[];
  @override
  Uri resolve(String path) => Uri.parse('http://localhost/$path');
  @override
  Widget avatar(String userId, String name, double size) =>
      SizedBox(width: size, height: size);
  @override
  Future<({int count, bool reacted})> setReaction(
    FootbagPost post,
    bool on,
  ) async => (count: post.reactionCount, reacted: on);
  @override
  Future<void> openComments(FootbagPost post, {required bool typing}) async {}
  @override
  void openAuthor(String userId, String name) {}
  @override
  void openTag(FootbagTag tag) {}
  @override
  void openClub(FootbagClubRef club) {}
  @override
  void openChallenge(String slug, String title) => opened.add(slug);
  @override
  void openMenu(FootbagPost post) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = L10nEn();

  setUp(() {
    PlayerAvatar.previewBuilder = (userId, name, size) =>
        SizedBox(width: size, height: size);
  });
  tearDown(() {
    ChallengeBanner.preview = null;
    ChallengeHeader.preview = null;
    PlayerAvatar.previewBuilder = null;
  });

  group('timing', () {
    test('days left while running', () {
      expect(challengeTiming(l10n, _challenge(), _now), '12 days left');
    });
    test('hours on the last day', () {
      expect(
        challengeTiming(
          l10n,
          _challenge(endsIn: const Duration(hours: 5, minutes: 10)),
          _now,
        ),
        '5 hours left',
      );
    });
    test('when an upcoming one starts', () {
      final c = _challenge(
        state: 'upcoming',
        startsIn: const Duration(days: 1),
      );
      expect(challengeTiming(l10n, c, _now), 'Starts tomorrow');
    });
    test('ended', () {
      expect(challengeTiming(l10n, _challenge(state: 'ended'), _now), 'Ended');
    });
  });

  group('the banner', () {
    testWidgets('shows the running challenge with Enter', (tester) async {
      ChallengeBanner.preview = [_challenge()];
      await tester.pumpWidget(_app(const ChallengeBanner()));
      await tester.pumpAndSettle();
      expect(find.text('NOPLANTNOVEMBER'), findsOneWidget);
      expect(find.text('12 entries  ·  7 players'), findsOneWidget);
      expect(
        find.byKey(const Key('ChallengeEnter_noplantnovember-2026')),
        findsOneWidget,
      );
    });

    testWidgets('has no Enter once your entries are used', (tester) async {
      ChallengeBanner.preview = [_challenge(mine: 3)];
      await tester.pumpWidget(_app(const ChallengeBanner()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ChallengeEnter_noplantnovember-2026')),
        findsNothing,
      );
    });

    testWidgets('is absent when nothing is running', (tester) async {
      ChallengeBanner.preview = [];
      await tester.pumpWidget(_app(const ChallengeBanner()));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('the page', () {
    Future<void> pump(WidgetTester tester, FootbagChallenge c) async {
      ChallengeHeader.preview = c;
      await tester.pumpWidget(
        _app(ChallengeHeader(key: UniqueKey(), slug: 'noplantnovember-2026')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the rules whole and offers Enter', (tester) async {
      await pump(tester, _challenge());
      expect(
        find.text('Film yourself not planting while freestyling.'),
        findsOneWidget,
      );
      expect(find.text('Enter'), findsOneWidget);
    });

    testWidgets('says how many entries are left', (tester) async {
      await pump(tester, _challenge(mine: 1));
      expect(find.text('Enter again (1 of 3)'), findsOneWidget);
    });

    testWidgets('says when you have used them all', (tester) async {
      await pump(tester, _challenge(mine: 3));
      expect(find.text("You've entered 3 of 3"), findsOneWidget);
      expect(find.text('Enter'), findsNothing);
    });

    testWidgets('says when it starts, and that it ended', (tester) async {
      await pump(
        tester,
        _challenge(state: 'upcoming', startsIn: const Duration(days: 4)),
      );
      expect(find.text('Starts in 4 days'), findsWidgets);
      await pump(tester, _challenge(state: 'ended', entries: 0));
      expect(find.text('Ended'), findsWidgets);
      expect(find.text('No entries yet'), findsOneWidget);
    });
  });

  testWidgets('an entry is labelled and opens its challenge', (tester) async {
    final actions = _Actions();
    final post = FootbagPost.fromJson({
      'id': 9,
      'author': {'user_id': '@d:x', 'display_name': 'Derek'},
      'caption': 'paradox symposium',
      'is_tutorial': false,
      'created_at': _now.toUtc().toIso8601String(),
      'media': <Object>[],
      'tags': <Object>[],
      'challenge': {
        'id': 1,
        'slug': 'noplantnovember-2026',
        'title': 'NoPlantNovember',
      },
      'reaction_count': 0,
      'reacted': false,
      'comment_count': 0,
      'comments_preview': <Object>[],
      'is_mine': false,
      'removed': false,
    });
    await tester.pumpWidget(_app(PostCard(post: post, actions: actions)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ChallengeTag_noplantnovember-2026')),
    );
    expect(actions.opened, ['noplantnovember-2026']);
  });
}
