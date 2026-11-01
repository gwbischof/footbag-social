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
import 'package:footbag_network/pages/feed/compose.dart';
import 'package:footbag_network/pages/feed/feed.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/pages/session/session_page.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

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
      'trick' => const _PreviewFeed(mode: 'trick'),
      'compose' => const _PreviewCompose(),
      'session-host' => const _PreviewSession(role: 'host'),
      'session-stranger' => const _PreviewSession(role: null),
      'session-requested' => const _PreviewSession(role: 'requested'),
      'session-going' => const _PreviewSession(role: 'approved'),
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

  @override
  PostActions get actions => PreviewActions();

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

  @override
  void openComments(FootbagPost post) {}

  @override
  void openAuthor(String userId, String name) {}

  @override
  void openTag(FootbagTag tag) {}

  @override
  void openMenu(FootbagPost post) {}
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
