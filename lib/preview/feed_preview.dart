// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A throwaway harness for LOOKING at the feed. Not shipped: build it with
// `flutter build web -t lib/preview/feed_preview.dart` only.
//
// Draws the real PostCard -- not a copy -- from real JSON parsed by the real
// FootbagPost.fromJson, with media served by a local API over signed URLs,
// so what is on screen is what the app would draw.

import 'dart:convert';
import 'dart:typed_data';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/club/club_form.dart';
import 'package:footbag_network/pages/club/club_page.dart';
import 'package:footbag_network/pages/feed/compose.dart';
import 'package:footbag_network/pages/feed/feed.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/comments.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/pages/feed/widgets/trick_header.dart';
import 'package:footbag_network/pages/goals/goals_page.dart';
import 'package:footbag_network/pages/inbox/inbox_bell.dart';
import 'package:footbag_network/pages/inbox/inbox_page.dart';
import 'package:footbag_network/pages/places/pending_places_page.dart';
import 'package:footbag_network/pages/session/session_page.dart';
import 'package:footbag_network/pages/session/where_sheet.dart';
import 'package:footbag_network/pages/welcome/welcome_page.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/footbag_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show Client;

void main() => runApp(const FeedPreviewApp());

const _api = 'http://127.0.0.1:8000';

final _posts = [
  for (final p
      in jsonDecode(
            r'''[{"id": 1, "author": {"user_id": "@landes:footbagsocial.com", "display_name": "Landes"}, "caption": "Sunday circle at the park. Six of us, nobody dropped it for the first ten minutes, which has to be some kind of record.", "is_tutorial": false, "created_at": "2026-10-29T03:13:32.476498+00:00", "media": [{"id": 1, "kind": "image", "width": 4000, "height": 3000, "blurhash": "LVKBBc?ayCxb9EbZoznj^-WYs=jE", "url": "media/f898fd4e-588c-4394-8225-4f50f3cdcea7.jpeg?v=feed&exp=1794182400&sig=b259eb10c0ace9e188f7a42d2898b657243f4c51c11dbe102376ccbcbd9002b0", "thumb_url": "media/f898fd4e-588c-4394-8225-4f50f3cdcea7.jpeg?v=thumb&exp=1794182400&sig=87a4ea704abc50ef3401acce786d5b7e429952857e698ca39e191cc220dd6ea7", "poster_url": "media/f898fd4e-588c-4394-8225-4f50f3cdcea7.jpeg?v=feed&exp=1794182400&sig=b259eb10c0ace9e188f7a42d2898b657243f4c51c11dbe102376ccbcbd9002b0"}, {"id": 3, "kind": "image", "width": 4000, "height": 3000, "blurhash": "LiJ@?vt%f,rwWAoyWCV[?dnTWAkU", "url": "media/d83d78f7-7f98-4bba-85e9-5afa6d4901b7.jpeg?v=feed&exp=1794182400&sig=ee2dabbd9f351fb976e45a22f297789996c808c89e0bae7d9a9d629836f34ea5", "thumb_url": "media/d83d78f7-7f98-4bba-85e9-5afa6d4901b7.jpeg?v=thumb&exp=1794182400&sig=0c426bf026465abf54c58bbb9d6d2d354f40271c4ac686de993196898878635a", "poster_url": "media/d83d78f7-7f98-4bba-85e9-5afa6d4901b7.jpeg?v=feed&exp=1794182400&sig=ee2dabbd9f351fb976e45a22f297789996c808c89e0bae7d9a9d629836f34ea5"}, {"id": 2, "kind": "image", "width": 3000, "height": 4000, "blurhash": "TlLWw|-o?H9[R*s:ODR*Mx8waeNG", "url": "media/12641d6b-38fb-4c92-8053-dbfa73efb69d.jpeg?v=feed&exp=1794182400&sig=3c02363cdebbfb4615120ca33c56af1e0e3f6e830f2972a623a7178b0f8e7ab7", "thumb_url": "media/12641d6b-38fb-4c92-8053-dbfa73efb69d.jpeg?v=thumb&exp=1794182400&sig=cd58489614be2d33fb3f4af4c15a5fcd9a645e2cb08cb3cc71ed2a1728c25011", "poster_url": "media/12641d6b-38fb-4c92-8053-dbfa73efb69d.jpeg?v=feed&exp=1794182400&sig=3c02363cdebbfb4615120ca33c56af1e0e3f6e830f2972a623a7178b0f8e7ab7"}], "tags": [], "place_name": "Washington Square Park", "session": null, "reaction_count": 14, "reacted": false, "comment_count": 5, "comments_preview": [{"id": 1, "post_id": 1, "author": {"user_id": "@g:x", "display_name": "Garrett"}, "body": "Next week I'm bringing the 32-panel", "created_at": "2026-10-29T04:13:32.476498+00:00", "is_mine": false}, {"id": 2, "post_id": 1, "author": {"user_id": "@m:x", "display_name": "Marco"}, "body": "that grass was perfect", "created_at": "2026-10-29T04:43:32.476498+00:00", "is_mine": false}], "is_mine": false, "removed": false}, {"id": 2, "author": {"user_id": "@g:footbagsocial.com", "display_name": "Garrett"}, "caption": "How I set a paradox mirage: dex out, catch the body turn late. Slow-mo halfway through.", "is_tutorial": true, "created_at": "2026-10-28T22:13:32.476498+00:00", "media": [{"id": 7, "kind": "video", "width": 1080, "height": 1920, "blurhash": "cKHnyoJD.64TpING~WxsVyInV?nnx9RQ9a", "url": "media/7f985b94-b5be-487c-88d6-6fa700fafc14.mp4?v=original&exp=1794182400&sig=b2ba16837f07ec99261a66d1a56785c7cd30ceef83c8869f3c1ca484ffcbea47", "thumb_url": "media/7f985b94-b5be-487c-88d6-6fa700fafc14.mp4?v=thumb&exp=1794182400&sig=b03e121f9df0d23c7bccfdf09a29042e5d1be5023b9e917476e372e75449e71c", "poster_url": "media/7f985b94-b5be-487c-88d6-6fa700fafc14.mp4?v=feed&exp=1794182400&sig=6cb86404d32c6cfd2b8aef9fd0787eee5edc856d719da679c490656694e802f8"}], "tags": [{"slug": "paradox-mirage", "name": "Paradox Mirage"}, {"slug": "mirage", "name": "Mirage"}], "place_name": null, "session": null, "reaction_count": 31, "reacted": true, "comment_count": 2, "comments_preview": [{"id": 3, "post_id": 2, "author": {"user_id": "@l:x", "display_name": "Landes"}, "body": "the late body turn is the whole trick", "created_at": "2026-10-28T23:13:32.476498+00:00", "is_mine": false}], "is_mine": true, "removed": false}, {"id": 3, "author": {"user_id": "@lamous:footbagsocial.com", "display_name": "Lamous"}, "caption": "Half way through a 32-panel. Panels cut Thursday, 90 stitches in.", "is_tutorial": false, "created_at": "2026-10-28T02:13:32.476498+00:00", "media": [{"id": 4, "kind": "image", "width": 900, "height": 1200, "blurhash": "TkM%yQ%M_3~qWBM{-;M{IUWCt7t7", "url": "media/d3f980aa-2ebf-4c54-b5d5-afe7678cb710.jpeg?v=feed&exp=1794182400&sig=85f712b7e904b421c2862b1a2631c368ed7b0e715aef899a3b404dd156d0fdae", "thumb_url": "media/d3f980aa-2ebf-4c54-b5d5-afe7678cb710.jpeg?v=thumb&exp=1794182400&sig=0c17f03a6208e7f03636458ecd4b9bfe57aa18df4bce041bfddaaa7b2018a032", "poster_url": "media/d3f980aa-2ebf-4c54-b5d5-afe7678cb710.jpeg?v=feed&exp=1794182400&sig=85f712b7e904b421c2862b1a2631c368ed7b0e715aef899a3b404dd156d0fdae"}, {"id": 5, "kind": "image", "width": 900, "height": 1200, "blurhash": "TZKA$jNH?G^*s:ay~AoKIpR+xtoL", "url": "media/b1eba9e0-acc1-4a52-ba41-1ee1b7a83d04.jpeg?v=feed&exp=1794182400&sig=7b8e050ac98e9af028bd1ab9f1d7fb4cb3a9fd4c3e31a9b94893314771d7442c", "thumb_url": "media/b1eba9e0-acc1-4a52-ba41-1ee1b7a83d04.jpeg?v=thumb&exp=1794182400&sig=634b6efb6c15cdfe1c584c2526f8940a4ea5770e161b49291f5423b7748fc3c7", "poster_url": "media/b1eba9e0-acc1-4a52-ba41-1ee1b7a83d04.jpeg?v=feed&exp=1794182400&sig=7b8e050ac98e9af028bd1ab9f1d7fb4cb3a9fd4c3e31a9b94893314771d7442c"}], "tags": [], "place_name": "Brooklyn", "session": {"id": 9, "name": "Stitching night", "type": "stitching", "duration_seconds": 8040, "kicks": null, "lines": []}, "reaction_count": 22, "reacted": false, "comment_count": 0, "comments_preview": [], "is_mine": false, "removed": false}, {"id": 4, "author": {"user_id": "@m:footbagsocial.com", "display_name": "Marco"}, "caption": "", "is_tutorial": false, "created_at": "2026-10-27T05:13:32.476498+00:00", "media": [], "tags": [], "place_name": null, "session": {"id": 8, "name": "Tompkins Square \u2014 evening", "type": "freestyle", "duration_seconds": 4380, "kicks": null, "lines": [{"name": "Spinning Paradox Mirage", "grade": "footing", "count": null, "is_first": true}, {"name": "Atomic Mirage", "grade": "hitting", "count": 12, "is_first": false}, {"name": "Whirl", "grade": "consistent", "count": 40, "is_first": false}]}, "reaction_count": 0, "reacted": false, "comment_count": 0, "comments_preview": [], "is_mine": false, "removed": false}, {"id": 5, "author": {"user_id": "@k:footbagsocial.com", "display_name": "Kenji"}, "caption": "Anyone playing near Union Square tonight? I'll be there from 7 with two bags.", "is_tutorial": false, "created_at": "2026-10-29T05:01:32.476498+00:00", "media": [], "tags": [], "place_name": null, "session": null, "reaction_count": 3, "reacted": false, "comment_count": 0, "comments_preview": [], "is_mine": false, "removed": false}]''',
          )
          as List)
    FootbagPost.fromJson(p as Map<String, dynamic>),
];

class FeedPreviewApp extends StatelessWidget {
  const FeedPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Builder(builder: previewBody),
  );
}

/// Which screen, from `?screen=` so a headless shot needs no clicks.
Widget previewBody(BuildContext context) =>
    switch (Uri.base.queryParameters['screen']) {
      'top' => const _PreviewFeed(mode: 'top'),
      'empty' => const _PreviewFeed(mode: 'empty'),
      'loading' => const _PreviewFeed(mode: 'loading'),
      'trick' => _trickPage(),
      'compose' => const _PreviewCompose(),
      'tabs' => const _TabSwap(),
      'inbox' => const _PreviewInbox(),
      'club-organiser' => const _PreviewClub(role: 'organiser'),
      'club-members' => const _PreviewClub(
        role: 'organiser',
        section: 'members',
      ),
      'club-stranger' => const _PreviewClub(role: null),
      'club-requested' => const _PreviewClub(role: 'requested'),
      'club-form' => const ClubForm(),
      'welcome' => WelcomePage(
        me: FootbagPlayer.fromJson({
          'user_id': '@kenji:x',
          'display_name': 'kenji',
          'discoverable': true,
          'show_sessions': true,
          'onboarded': false,
        }),
      ),
      'session-host' => const _PreviewSession(role: 'host'),
      'session-stranger' => const _PreviewSession(role: null),
      'session-requested' => const _PreviewSession(role: 'requested'),
      'session-going' => const _PreviewSession(role: 'approved'),
      'near' => Scaffold(
        backgroundColor: Nyfa.ground,
        appBar: Nyfa.appBar(title: 'Near'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 260,
            child: FootbagMap(
              areas: const [
                FootbagArea(lat: 40.732, lng: -73.975, radiusM: 1609),
                FootbagArea(lat: 40.745, lng: -73.99, radiusM: 4828),
                FootbagArea(lat: 40.70, lng: -73.95, radiusM: 1609),
              ],
              you: const LatLng(40.728, -73.99),
              interactive: true,
              onAreaTap: (_) {},
            ),
          ),
        ),
      ),
      'places' => const _PreviewPlaces(),
      'where' => const _PreviewWhere(),
      'goals' => const _PreviewGoals(),
      _ => const _PreviewFeed(mode: 'recent'),
    };

/// The real Feed screen and controller, with the network swapped out.
class _PreviewFeed extends Feed {
  final String mode;

  const _PreviewFeed({required this.mode})
    : super(
        entrySlug: mode == 'trick' ? 'paradox-mirage' : null,
        entryName: mode == 'trick' ? 'Paradox Mirage' : null,
      );

  @override
  FeedController createState() => _PreviewFeedController();
}

class _PreviewFeedController extends FeedController {
  String get mode => (widget as _PreviewFeed).mode;

  late final PreviewActions _actions = PreviewActions()..context = context;

  @override
  PostActions get actions => _actions;

  @override
  String get memoryKey => 'preview|$mode';

  @override
  Future<void> checkWelcome() async {}

  @override
  String get myUserId {
    PlayerAvatar.previewBuilder = PreviewActions().avatar;
    InboxBell.previewCount = 3;
    return '@g:x';
  }

  @override
  Future<void> refresh() async {
    if (mode == 'top') sort = 'top';
    if (mode == 'loading') return;
    setState(() => posts = mode == 'empty' ? [] : [..._posts]);
  }

  @override
  Future<void> loadMore() async {}
}

class _PreviewCompose extends Compose {
  const _PreviewCompose();

  @override
  ComposeController createState() => _PreviewComposeController();
}

class _PreviewComposeController extends ComposeController {
  @override
  void initState() {
    super.initState();
    final media = [for (final p in _posts) ...p.media];
    for (final (i, m) in media.take(4).indexed) {
      final d = Draft(
        XFile.fromData(Uint8List(0), name: 'p$i.jpg'),
        isVideo: m.isVideo,
        contentType: m.isVideo ? 'video/mp4' : 'image/jpeg',
      );
      // The last one still uploading, to show what that looks like.
      if (i < 3) d.media = m;
      if (i == 3) d.progress = 0.4;
      drafts.add(d);
    }
    caption.text = 'Sunday circle at the park. Six of us.';
    tags.addAll(['paradox-mirage', 'mirage']);
    tagNames.addAll({'paradox-mirage': 'Paradox Mirage', 'mirage': 'Mirage'});
    tutorial = true;
    sessionId = 8;
  }

  @override
  Future<void> loadSessions() async => setState(
    () => sessions = [
      for (final (id, name) in [
        (8, 'Tompkins Square — evening'),
        (9, 'Stitching night'),
      ])
        FootbagSession.fromJson({
          'id': id,
          'name': name,
          'type': 'freestyle',
          'host_id': '@g:x',
          'joining': 'open',
          'on_feed': 'public',
          'started_at': '2026-10-27T18:00:00Z',
        }),
    ],
  );

  @override
  Uri resolveMedia(String path) => Uri.parse('$_api/$path');
}

class PreviewActions implements PostActions {
  @override
  Uri resolve(String path) => Uri.parse('$_api/$path');

  @override
  Widget avatar(String userId, String name, double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Nyfa.greenDim,
      shape: BoxShape.circle,
    ),
    child: Text(
      name.substring(0, 1).toUpperCase(),
      style: TextStyle(
        fontFamily: Nyfa.display,
        fontSize: size * 0.5,
        color: Nyfa.paper,
      ),
    ),
  );

  @override
  Future<({int count, bool reacted})> setReaction(
    FootbagPost post,
    bool on,
  ) async => (count: post.reactionCount, reacted: on);

  BuildContext? context;

  @override
  Future<void> openComments(FootbagPost post, {required bool typing}) =>
      showCommentsSheet(
        context!,
        this,
        thread: _PreviewThread(post),
        me: '@g:x',
        typing: typing,
      );

  @override
  void openAuthor(String userId, String name) {}

  @override
  void openTag(FootbagTag tag) {}

  @override
  void openMenu(FootbagPost post) {}

  @override
  void openClub(FootbagClubRef club) {}
}

/// The real session page with a canned session, one per standing.
class _PreviewSession extends SessionPage {
  final String? role;

  const _PreviewSession({required this.role}) : super(sessionId: 8);

  @override
  SessionPageState createState() => _PreviewSessionState();
}

class _PreviewSessionState extends SessionPageState {
  @override
  Future<void> load() async {
    PlayerAvatar.previewBuilder = PreviewActions().avatar;
    final role = (widget as _PreviewSession).role;
    final host = role == 'host';
    final named = host || role == 'approved';
    adopt(
      FootbagSession.fromJson({
        'id': 8,
        'name': 'Tompkins Square — evening',
        'type': 'freestyle',
        'host_id': '@landes:x',
        'host_name': 'Landes',
        'joining': 'open',
        'on_feed': 'public',
        'note': 'Bring a spare bag. Meeting by the basketball courts.',
        'scheduled_at': DateTime.now()
            .add(const Duration(days: 1, hours: 3))
            .toUtc()
            .toIso8601String(),
        'is_running': false,
        'attendee_count': 3,
        'my_state': role,
        'area': {'lat': 40.732, 'lng': -73.975, 'radius_m': 1609},
        'place': named
            ? {
                'id': 1,
                'name': 'Tompkins Square Park',
                'lat': 40.7265,
                'lng': -73.9815,
                'approved': true,
              }
            : null,
        'attendees': named
            ? [
                {'user_id': '@g:x', 'display_name': 'Garrett'},
                {'user_id': '@m:x', 'display_name': 'Marco'},
                {'user_id': '@k:x', 'display_name': 'Kenji'},
              ]
            : null,
        'requests': host
            ? [
                {'user_id': '@l:x', 'display_name': 'Lamous'},
                {'user_id': '@j:x', 'display_name': 'Jake'},
              ]
            : null,
      }),
    );
  }
}

/// Comments with no server: the preview's thread answers from memory.
class _PreviewThread extends CommentThread {
  _PreviewThread(FootbagPost post) : super(null, post);

  @override
  Future<void> load() async {
    comments = [
      for (final (i, (who, text)) in [
        ('Garrett', 'Next week I\'m bringing the 32-panel'),
        ('Marco', 'that grass was perfect'),
        ('Kenji', 'the late body turn on the second one is clean'),
        ('Lamous', 'who stitched the orange one?'),
        ('Landes', 'G did, it\'s LX'),
      ].indexed)
        FootbagComment(
          id: i,
          postId: post.id,
          authorId: '@$who:x',
          authorName: who,
          body: text,
          createdAt: DateTime.now().subtract(Duration(minutes: 50 - i * 9)),
          isMine: who == 'Garrett',
        ),
    ];
    notifyListeners();
  }
}

/// Feed and an empty "other tab", swapped by a button -- the Feed is torn
/// down and rebuilt exactly as switching tabs in the app does, so its
/// snapshot can be seen working.
class _TabSwap extends StatefulWidget {
  const _TabSwap();

  @override
  State<_TabSwap> createState() => _TabSwapState();
}

class _TabSwapState extends State<_TabSwap> {
  bool feed = true;
  int loads = 0;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (feed)
        const _PreviewFeed(mode: 'recent')
      else
        const ColoredBox(color: Nyfa.ground, child: SizedBox.expand()),
      Positioned(
        right: 8,
        bottom: 90,
        child: FilledButton(
          key: const Key('SwapTab'),
          onPressed: () => setState(() => feed = !feed),
          child: Text(feed ? 'OTHER TAB' : 'BACK TO FEED'),
        ),
      ),
    ],
  );
}

class _PreviewInbox extends InboxPage {
  const _PreviewInbox();

  @override
  InboxPageState createState() => _PreviewInboxState();
}

class _PreviewInboxState extends InboxPageState {
  @override
  int chatCount(BuildContext context) => 2;

  @override
  Uri resolveMedia(String path) => Uri.parse('$_api/$path');

  @override
  Future<void> load() async {
    PlayerAvatar.previewBuilder = PreviewActions().avatar;
    final now = DateTime.now().toUtc();
    String ago(Duration d) => now.subtract(d).toIso8601String();
    Map<String, dynamic> a(String n) => {'user_id': '@$n:x', 'display_name': n};
    setState(
      () => items = [
        for (final j in [
          {
            'key': 'r1',
            'kind': 'join_request',
            'actors': [a('Lamous')],
            'actor_count': 1,
            'session': {'id': 8, 'name': 'Tompkins Square — evening'},
            'at': ago(const Duration(minutes: 4)),
            'unread': true,
          },
          {
            'key': 'r2',
            'kind': 'reaction',
            'actors': [a('Marco'), a('Kenji'), a('Landes')],
            'actor_count': 5,
            'post': {
              'id': 1,
              'thumb_url':
                  'media/f898fd4e-588c-4394-8225-4f50f3cdcea7.jpeg?v=thumb&exp=1794182400&sig=87a4ea704abc50ef3401acce786d5b7e429952857e698ca39e191cc220dd6ea7',
              'caption': 'Sunday circle',
            },
            'at': ago(const Duration(minutes: 18)),
            'unread': true,
          },
          {
            'key': 'r3',
            'kind': 'comment',
            'actors': [a('Kenji'), a('Marco')],
            'actor_count': 2,
            'post': {
              'id': 2,
              'thumb_url':
                  'media/d3f980aa-2ebf-4c54-b5d5-afe7678cb710.jpeg?v=thumb&exp=1794182400&sig=0c17f03a6208e7f03636458ecd4b9bfe57aa18df4bce041bfddaaa7b2018a032',
              'caption': '',
            },
            'at': ago(const Duration(hours: 2)),
            'unread': false,
          },
          {
            'key': 'r4',
            'kind': 'join_approved',
            'actors': [a('Landes')],
            'actor_count': 1,
            'session': {'id': 9, 'name': 'Washington Sq Saturday'},
            'at': ago(const Duration(hours: 9)),
            'unread': false,
          },
          {
            'key': 'r5',
            'kind': 'reaction',
            'actors': [a('Jake')],
            'actor_count': 1,
            'post': {
              'id': 5,
              'thumb_url': null,
              'caption': 'Anyone playing near Union Square tonight?',
            },
            'at': ago(const Duration(days: 1)),
            'unread': false,
          },
          {
            'key': 'r6',
            'kind': 'report_resolved',
            'actors': [],
            'actor_count': 0,
            'outcome': 'removed',
            'post': {'id': 7, 'thumb_url': null, 'caption': ''},
            'at': ago(const Duration(days: 3)),
            'unread': false,
          },
        ])
          FootbagInboxItem.fromJson(j),
      ],
    );
  }
}

class _PreviewClub extends ClubPage {
  final String? role;
  final String section;

  const _PreviewClub({required this.role, this.section = 'posts'})
    : super(clubId: 3);

  @override
  ClubPageState createState() => _PreviewClubState();
}

class _PreviewClubState extends ClubPageState {
  @override
  String get me => '@Garrett:x';

  @override
  Uri resolveMedia(String path) => Uri.parse('$_api/$path');

  @override
  Future<void> load() async {
    PlayerAvatar.previewBuilder = PreviewActions().avatar;
    final w = widget as _PreviewClub;
    final organiser = w.role == 'organiser';
    Map<String, dynamic> m(String n, String role, {bool creator = false}) => {
      'user_id': '@$n:x',
      'display_name': n,
      'role': role,
      'is_creator': creator,
    };
    setState(() {
      section = w.section == 'members'
          ? ClubSection.members
          : ClubSection.posts;
      club = FootbagClub.fromJson({
        'id': 3,
        'name': 'Tompkins Footbag',
        'location': 'Tompkins Square Park, by the chess tables',
        'description':
            'Freestyle most Tuesday and Thursday evenings from 6. '
            'All levels; bring a bag if you have one, we have spares.',
        'member_count': 4,
        'my_state': organiser ? 'approved' : w.role,
        'my_role': organiser ? 'organiser' : null,
        'members': [
          m('Landes', 'organiser', creator: true),
          m('Garrett', 'organiser'),
          m('Marco', 'member'),
          m('Kenji', 'member'),
        ],
        'requests': organiser
            ? [
                {'user_id': '@Lamous:x', 'display_name': 'Lamous'},
              ]
            : null,
      });
      posts = [..._posts];
      sessions = [];
    });
  }
}

/// Suggestions waiting, with no server.
class _PreviewPlaces extends PendingPlacesPage {
  const _PreviewPlaces();

  @override
  PendingPlacesPageState createState() => _PreviewPlacesState();
}

class _PreviewPlacesState extends PendingPlacesPageState {
  @override
  Future<void> load() async => setState(
    () => places = const [
      FootbagPlace(
        id: 3,
        name: 'Union Square, south steps',
        lat: 40.7347,
        lng: -73.9907,
        approved: false,
      ),
      FootbagPlace(
        id: 4,
        name: 'Pier 45',
        lat: 40.7334,
        lng: -74.0114,
        approved: false,
      ),
    ],
  );
}

/// The place picker, opened over a blank page as it opens over the form.
class _PreviewWhere extends StatefulWidget {
  const _PreviewWhere();

  @override
  State<_PreviewWhere> createState() => _PreviewWhereState();
}

class _PreviewWhereState extends State<_PreviewWhere> {
  @override
  void initState() {
    super.initState();
    WhereSheetPreview.fix = (lat: 40.728, lng: -73.99);
    WhereSheetPreview.places = const [
      FootbagPlace(
        id: 1,
        name: 'Tompkins Square Park',
        lat: 40.7265,
        lng: -73.9815,
        approved: true,
        distanceKm: 0.8,
      ),
      FootbagPlace(
        id: 2,
        name: 'Washington Square Park',
        lat: 40.7308,
        lng: -73.9973,
        approved: true,
        distanceKm: 1.1,
      ),
      FootbagPlace(
        id: 3,
        name: 'Union Square, south steps',
        lat: 40.7347,
        lng: -73.9907,
        approved: false,
        distanceKm: 1.4,
      ),
      FootbagPlace(
        id: 5,
        name: 'McCarren Park',
        lat: 40.7203,
        lng: -73.9516,
        approved: true,
        distanceKm: 3.4,
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showWhereSheet(context, client: _NoClient()),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Nyfa.ground);
}

/// A client the preview never calls: its seams answer first.
class _NoClient implements Client {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No server in the preview');
}

/// The goal step after Start, with one goal picked and ideas from each source.
class _PreviewGoals extends GoalsPage {
  const _PreviewGoals() : super(sessionId: 8);

  @override
  GoalsPageState createState() => _PreviewGoalsState();
}

class _PreviewGoalsState extends GoalsPageState {
  @override
  Future<void> load() async => setState(() {
    goals = const [
      FootbagGoal(entrySlug: 'paradox-mirage', name: 'Paradox Mirage'),
    ];
    ideas = const [
      FootbagIdea(
        entrySlug: 'atomic-mirage',
        name: 'Atomic Mirage',
        rule: 'unmet',
        count: 2,
      ),
      FootbagIdea(entrySlug: 'whirl', name: 'Whirl', rule: 'last_session'),
      FootbagIdea(
        entrySlug: 'blurry-whirl',
        name: 'Blurry Whirl',
        rule: 'next_step',
        becauseName: 'Whirl',
      ),
      FootbagIdea(
        entrySlug: 'mirage',
        name: 'Mirage',
        rule: 'ease_off',
        becauseName: 'Spinning Paradox Mirage',
        count: 3,
      ),
      FootbagIdea(entrySlug: 'butterfly', name: 'Butterfly', rule: 'favourite'),
      FootbagIdea(entrySlug: 'osis', name: 'Osis', rule: 'favourite'),
    ];
  });

  @override
  Future<List<FootbagGoal>> save(List<String> slugs) async => [
    for (final slug in slugs)
      FootbagGoal(
        entrySlug: slug,
        name: [
          ...?goals,
          ...ideas.map(
            (i) => FootbagGoal(entrySlug: i.entrySlug, name: i.name),
          ),
        ].firstWhere((g) => g.entrySlug == slug).name,
      ),
  ];
}

/// A trick's page: the header from canned data, the clips from the preview
/// feed.
Widget _trickPage() {
  TrickHeader.preview = FootbagTrickDetail.fromJson({
    'entry': {
      'slug': 'paradox-mirage',
      'name': 'Paradox Mirage',
      'kind': 'composite',
      'description':
          'A mirage taken paradox: the set crosses behind the plant leg before the dex.',
      'aka': ['PDX Mirage'],
      'adds': ['pdx', 'dex', 'del'],
    },
    'built_on': [
      {'slug': 'mirage', 'name': 'Mirage'},
    ],
    'builds_into': [
      {'slug': 'spinning-paradox-mirage', 'name': 'Spinning Paradox Mirage'},
      {'slug': 'blurry-paradox-mirage', 'name': 'Blurry Paradox Mirage'},
      {'slug': 'atomic-paradox-mirage', 'name': 'Atomic Paradox Mirage'},
    ],
    'mine': {
      'best_grade': 'hitting',
      'hit_sessions': 4,
      'last_reported': '2026-10-30T18:00:00Z',
      'favourite': true,
    },
  });
  return const _PreviewFeed(mode: 'trick');
}
