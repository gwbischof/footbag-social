// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/feed_actions.dart';
import 'package:footbag_network/pages/feed/feed_view.dart';
import 'package:footbag_network/pages/feed/widgets/post_card.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The community feed.
///
/// **One feed, no follows.** Sorted Recent or Top, filtered by tutorial and
/// by distance. The same screen, given an [entrySlug], is a trick's page: its
/// clips, with tutorials one tap away -- "tag it once and it becomes findable
/// by name, for everyone".
class Feed extends StatefulWidget {
  /// Show only posts tagged with this trick, titled [entryName].
  final String? entrySlug;
  final String? entryName;

  const Feed({this.entrySlug, this.entryName, super.key});

  bool get isTrickPage => entrySlug != null;

  @override
  FeedController createState() => FeedController();
}

/// The feed as it was when you left it.
///
/// Kept in memory, not on disk: its job is that switching to Chat and back
/// shows the same posts at the same place, instantly, as every feed app
/// does. Keyed by account as well as by trick, so a different person signing
/// in on the same browser never sees the last one's feed.
class _Snapshot {
  final List<FootbagPost> posts;
  final String? next;
  final String sort;
  final String window;
  final bool tutorialsOnly;
  final ({double lat, double lng})? near;
  final double offset;
  final DateTime at;

  _Snapshot({
    required this.posts,
    required this.next,
    required this.sort,
    required this.window,
    required this.tutorialsOnly,
    required this.near,
    required this.offset,
  }) : at = DateTime.now();
}

class FeedController extends State<Feed> {
  static final _memory = <String, _Snapshot>{};

  /// Older than this and the feed reloads on return rather than resuming --
  /// coming back after lunch should show what is new.
  static const _stale = Duration(minutes: 15);

  late final ScrollController scroll;

  /// Whose avatar the header shows. Overridden by the preview harness.
  String get myUserId => Matrix.of(context).client.userID ?? '';

  /// Which snapshot this screen resumes. Overridden by the preview harness,
  /// which has no Matrix client.
  String get memoryKey =>
      '${Matrix.of(context).client.userID}|${widget.entrySlug ?? ''}';

  /// `null` until the first page arrives, so the view can tell "loading" from
  /// "nothing here".
  List<FootbagPost>? posts;
  String? _next;
  Object? error;
  bool loadingMore = false;
  bool moreFailed = false;

  String sort = 'recent';
  String window = 'week';
  bool tutorialsOnly = false;

  /// Where "near me" is measured from, once the player has turned it on.
  ({double lat, double lng})? near;
  bool locating = false;

  /// Discards answers to requests that a newer filter change has superseded,
  /// so a slow first response cannot overwrite a fast second one.
  int _generation = 0;

  bool get hasMore => _next != null;

  bool get isFiltered => tutorialsOnly || near != null;

  late final PostActions actions = AppPostActions(
    context,
    onRemoved: (post) =>
        setState(() => posts?.removeWhere((p) => p.id == post.id)),
    onReplaced: (updated) => setState(() {
      final i = posts?.indexWhere((p) => p.id == updated.id) ?? -1;
      if (i >= 0) posts![i] = updated;
    }),
  );

  /// Asked once per app run, not on every visit to the feed.
  static bool _welcomeChecked = false;

  /// The first run: if this account has not seen the welcome, show it over
  /// the feed. The feed loads underneath, so finishing lands on content.
  Future<void> checkWelcome() async {
    if (_welcomeChecked || widget.isTrickPage) return;
    _welcomeChecked = true;
    try {
      final me = await Matrix.of(context).client.fetchMe();
      if (mounted && !me.onboarded) {
        await context.push('/rooms/welcome', extra: me);
      }
    } catch (_) {
      // No welcome is better than a feed that will not open.
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(checkWelcome());
    final snap = _memory[memoryKey];
    if (snap != null && DateTime.now().difference(snap.at) < _stale) {
      posts = snap.posts;
      _next = snap.next;
      sort = snap.sort;
      window = snap.window;
      tutorialsOnly = snap.tutorialsOnly;
      near = snap.near;
      scroll = ScrollController(initialScrollOffset: snap.offset);
    } else {
      scroll = ScrollController();
      unawaited(refresh());
    }
    // Tracked as it moves, not read at dispose: by the time this State is
    // disposed the scroll view below it is already gone, and the offset
    // reads as zero -- which brought you back to the top every time.
    _offset = scroll.initialScrollOffset;
    scroll.addListener(() => _offset = scroll.offset);
  }

  double _offset = 0;

  @override
  void dispose() {
    final list = posts;
    if (list != null) {
      _memory[memoryKey] = _Snapshot(
        posts: list,
        next: _next,
        sort: sort,
        window: window,
        tutorialsOnly: tutorialsOnly,
        near: near,
        offset: _offset,
      );
    }
    scroll.dispose();
    super.dispose();
  }

  /// The Feed tab, tapped while already on the feed: back to the top, or --
  /// already there -- check for anything new. What every feed app does.
  Future<void> scrollToTop() async {
    if (scroll.hasClients && scroll.offset > 0) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      await refresh();
    }
  }

  Future<FootbagFeedPage> _fetch({String? cursor}) =>
      Matrix.of(context).client.fetchFeed(
        sort: sort,
        window: window,
        entry: widget.entrySlug,
        tutorial: tutorialsOnly,
        lat: near?.lat,
        lng: near?.lng,
        cursor: cursor,
      );

  Future<void> refresh() async {
    final generation = ++_generation;
    try {
      final page = await _fetch();
      if (!mounted || generation != _generation) return;
      setState(() {
        posts = page.posts;
        _next = page.next;
        error = null;
        moreFailed = false;
      });
    } catch (e, s) {
      Logs().w('Loading the feed failed', e, s);
      if (!mounted || generation != _generation) return;
      setState(() => error = e);
    }
  }

  /// Called as the list nears its end. Guarded so a fast fling past the
  /// threshold does not fire the same page three times.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore || moreFailed) return;
    final generation = _generation;
    setState(() => loadingMore = true);
    try {
      final page = await _fetch(cursor: _next);
      if (!mounted || generation != _generation) return;
      setState(() {
        // De-duplicated by id: Top pages by offset, and a post that gains a
        // ♦ between pages can move into the next one.
        final seen = {for (final p in posts!) p.id};
        posts!.addAll(page.posts.where((p) => !seen.contains(p.id)));
        _next = page.next;
      });
    } catch (e, s) {
      Logs().w('Loading more of the feed failed', e, s);
      if (mounted) setState(() => moreFailed = true);
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void retryMore() {
    setState(() => moreFailed = false);
    unawaited(loadMore());
  }

  void _reload(VoidCallback change) {
    setState(() {
      change();
      posts = null;
      _next = null;
      error = null;
    });
    unawaited(refresh());
  }

  void setSort(String value) {
    if (value == sort) return;
    _reload(() => sort = value);
  }

  void setWindow(String value) {
    if (value == window) return;
    _reload(() => window = value);
  }

  void toggleTutorials() => _reload(() => tutorialsOnly = !tutorialsOnly);

  void clearFilters() => _reload(() {
    tutorialsOnly = false;
    near = null;
  });

  /// Turn "near me" on or off.
  ///
  /// The fix is asked for at low accuracy and never sent anywhere but the
  /// feed query -- the API stores nothing about where a reader is.
  Future<void> toggleNear() async {
    if (near != null) {
      _reload(() => near = null);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(null);
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _reload(() => near = (lat: fix.latitude, lng: fix.longitude));
    } catch (e) {
      Logs().w('Near me: no location', e);
      messenger.showSnackBar(SnackBar(content: Text(l10n.locationUnavailable)));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> compose() async {
    final posted = await context.push<FootbagPost>('/rooms/feed/new');
    if (posted == null || !mounted) return;
    // The new post goes straight to the top, rather than waiting on a
    // refresh: under Top it would otherwise be nowhere to be seen.
    setState(() => posts = [posted, ...?posts]);
  }

  @override
  Widget build(BuildContext context) => FeedView(this);
}
