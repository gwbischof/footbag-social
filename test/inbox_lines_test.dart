// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// The inbox lines added for a small community: replies in a thread you are
// in, someone new arriving, and a challenge starting.

import 'package:flutter_test/flutter_test.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/inbox/inbox_page.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:material_ui/material_ui.dart';

FootbagInboxItem _item(
  String kind, {
  Map<String, dynamic>? challenge,
  bool actor = true,
}) => FootbagInboxItem.fromJson({
  'key': '$kind:1',
  'kind': kind,
  'actors': [
    if (actor) {'user_id': '@k:x', 'display_name': 'Kenji'},
  ],
  'actor_count': actor ? 1 : 0,
  'challenge': ?challenge,
  'at': DateTime.now().toUtc().toIso8601String(),
  'unread': true,
});

Future<String> _line(WidgetTester tester, FootbagInboxItem item) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
        body: InboxRow(item: item, resolve: Uri.parse, onTap: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((t) => t.text.toPlainText())
      .join(' ');
}

void main() {
  setUp(() {
    PlayerAvatar.previewBuilder = (userId, name, size) =>
        SizedBox(width: size, height: size);
  });
  tearDown(() => PlayerAvatar.previewBuilder = null);

  test('a challenge line carries its challenge', () {
    final item = _item(
      'challenge_started',
      actor: false,
      challenge: {
        'id': 1,
        'slug': 'noplantnovember-2026',
        'title': 'NoPlantNovember 2026',
      },
    );
    expect(item.challenge, (
      slug: 'noplantnovember-2026',
      title: 'NoPlantNovember 2026',
    ));
  });

  testWidgets('a reply in your thread', (tester) async {
    expect(
      await _line(tester, _item('also_commented')),
      contains('Kenji also commented on a post you commented on'),
    );
  });

  testWidgets('someone new, with a nudge to say hi', (tester) async {
    expect(
      await _line(tester, _item('new_member')),
      contains('Kenji just joined. Say hi!'),
    );
  });

  testWidgets('a challenge starting, by name', (tester) async {
    final text = await _line(
      tester,
      _item(
        'challenge_started',
        actor: false,
        challenge: {
          'id': 1,
          'slug': 'noplantnovember-2026',
          'title': 'NoPlantNovember 2026',
        },
      ),
    );
    expect(text, contains('NoPlantNovember 2026 has started'));
  });
}
