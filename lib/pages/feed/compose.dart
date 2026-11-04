// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/compose_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

/// One photo or clip in the post being written.
///
/// Uploads start the moment something is picked, not when Share is tapped:
/// by the time a caption is written the bytes are usually already up, so
/// sharing is instant. That is the difference between posting feeling like
/// one tap and feeling like a form.
class Draft {
  final XFile file;
  final bool isVideo;
  final String contentType;

  /// Local bytes for a photo's preview. Clips have none: decoding a frame on
  /// the device is the server's job, and its poster arrives with [media].
  Uint8List? preview;
  double progress = 0;
  FootbagMedia? media;
  Object? error;

  Draft(this.file, {required this.isVideo, required this.contentType});

  bool get done => media != null;
  bool get failed => error != null;
}

class Compose extends StatefulWidget {
  /// Prefill the session -- arriving from "Share to feed" after a report.
  final int? sessionId;

  /// Prefill a trick you landed -- arriving from "I landed it" on its page.
  final ({String slug, String name})? landed;

  /// Prefill the words -- arriving from the welcome, as an introduction.
  final String? caption;

  /// Prefill a challenge entry -- arriving from a challenge's Enter button.
  final String? challengeSlug;

  const Compose({
    this.sessionId,
    this.landed,
    this.caption,
    this.challengeSlug,
    super.key,
  });

  @override
  ComposeController createState() => ComposeController();
}

class ComposeController extends State<Compose> {
  final drafts = <Draft>[];
  final caption = TextEditingController();
  final place = TextEditingController();

  /// Slugs, in the order tagged, and their names for the chips.
  final tags = <String>[];
  final tagNames = <String, String>{};

  bool tutorial = false;
  int? sessionId;

  /// The tagged trick this post says you landed, if any, and whether it was
  /// your first. Always one of [tags]: untagging it clears it.
  String? landed;
  bool landedFirst = false;

  /// Clubs you can post to; the picker is hidden when there are none.
  List<FootbagClub> clubs = const [];
  int? clubId;

  /// Running challenges you still have entries left in; the picker is hidden
  /// when there are none.
  List<FootbagChallenge> challenges = const [];
  int? challengeId;

  /// An entry is a clip or a photo: picked but empty, Share waits for one.
  bool get needsMediaForChallenge => challengeId != null && drafts.isEmpty;

  /// Sessions this post could come from: yours, public, started.
  List<FootbagSession>? sessions;

  bool addArea = false;
  ({double lat, double lng})? area;
  bool locating = false;

  bool sharing = false;

  Client get _client => Matrix.of(context).client;

  bool get uploading => drafts.any((d) => !d.done && !d.failed);

  bool get hasContent =>
      drafts.isNotEmpty ||
      caption.text.trim().isNotEmpty ||
      sessionId != null ||
      landed != null;

  /// Share needs something to post and nothing still in flight. A failed
  /// upload blocks it too, rather than being silently dropped from the post.
  bool get canShare =>
      hasContent &&
      !needsMediaForChallenge &&
      !uploading &&
      !sharing &&
      !drafts.any((d) => d.failed);

  @override
  void initState() {
    super.initState();
    sessionId = widget.sessionId;
    if (widget.caption case final text?) caption.text = text;
    if (widget.landed case final l?) {
      tags.add(l.slug);
      tagNames[l.slug] = l.name;
      landed = l.slug;
    }
    caption.addListener(() => setState(() {}));
    unawaited(loadSessions());
    unawaited(loadClubs());
    unawaited(loadChallenges());
  }

  @override
  void dispose() {
    caption.dispose();
    place.dispose();
    super.dispose();
  }

  Future<void> loadSessions() async {
    try {
      final all = await _client.fetchSessions(limit: 20);
      if (!mounted) return;
      setState(
        () => sessions = all
            .where((s) => s.onFeed == 'public' && s.startedAt != null)
            .take(6)
            .toList(),
      );
    } catch (e) {
      Logs().w('Could not list sessions for the composer', e);
      if (mounted) setState(() => sessions = const []);
    }
  }

  Future<void> pickMedia() async {
    final room = maxPostMedia - drafts.length;
    if (room <= 0) return;
    final picked = await ImagePicker().pickMultipleMedia(
      // A quality setting is what makes iOS hand over JPEG instead of HEIC,
      // which the server cannot decode.
      imageQuality: 90,
      maxWidth: 2160,
      limit: room,
      requestFullMetadata: false,
    );
    if (picked.isEmpty || !mounted) return;
    for (final file in picked.take(room)) {
      final type =
          file.mimeType ??
          lookupMimeType(file.name) ??
          'application/octet-stream';
      final draft = Draft(
        file,
        isVideo: type.startsWith('video/'),
        contentType: type == 'image/jpg' ? 'image/jpeg' : type,
      );
      setState(() => drafts.add(draft));
      if (!draft.isVideo) {
        unawaited(
          file.readAsBytes().then((b) {
            if (mounted) setState(() => draft.preview = b);
          }),
        );
      }
      unawaited(_upload(draft));
    }
  }

  Future<void> _upload(Draft d) async {
    setState(() {
      d.error = null;
      d.progress = 0;
    });
    try {
      final media = await _client.uploadMedia(
        bytes: d.file.openRead(),
        length: await d.file.length(),
        contentType: d.contentType,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => d.progress = total == 0 ? 0 : sent / total);
        },
      );
      if (mounted) setState(() => d.media = media);
    } catch (e, s) {
      Logs().w('Upload failed', e, s);
      if (mounted) setState(() => d.error = e);
    }
  }

  Future<void> loadClubs() async {
    try {
      final all = await _client.fetchClubs(mine: true);
      if (!mounted) return;
      setState(() => clubs = all.where((c) => c.isMember).toList());
    } catch (e) {
      Logs().w('Could not list clubs for the composer', e);
    }
  }

  void setClub(int? id) => setState(() => clubId = id);

  Future<void> loadChallenges() async {
    try {
      final all = await _client.fetchChallenges();
      if (!mounted) return;
      setState(() {
        challenges = all.where((c) => c.canEnter).toList();
        challengeId ??= challenges
            .where((c) => c.slug == widget.challengeSlug)
            .firstOrNull
            ?.id;
      });
    } catch (e) {
      Logs().w('Could not list challenges for the composer', e);
    }
  }

  void setChallenge(int? id) => setState(() => challengeId = id);

  Uri resolveMedia(String path) => _client.footbagMediaUri(path);

  void retry(Draft d) => unawaited(_upload(d));

  void remove(Draft d) => setState(() => drafts.remove(d));

  void reorder(int oldIndex, int newIndex) => setState(() {
    // onReorderItem hands back an index already adjusted for the removal.
    final moved = drafts.removeAt(oldIndex);
    drafts.insert(newIndex, moved);
  });

  void setLanded(String? slug) => setState(() {
    landed = slug;
    if (slug == null) landedFirst = false;
  });

  void setLandedFirst(bool v) => setState(() => landedFirst = v);

  Future<void> tagTricks() async {
    final added = await context.push<List<String>>(
      '/rooms/feed/new/tag',
      extra: tags.toSet(),
    );
    if (added == null || added.isEmpty || !mounted) return;
    setState(
      () => tags.addAll(
        added.where((s) => !tags.contains(s)).take(10 - tags.length),
      ),
    );
    // Names for the chips. The dictionary is small, and the picker returns
    // slugs only, so look them up rather than widen the picker's contract.
    try {
      final entries = await _client.fetchEntries();
      if (!mounted) return;
      setState(() {
        for (final e in entries) {
          tagNames[e.slug] = e.name;
        }
      });
    } catch (_) {
      // The chips fall back to slugs, which are readable enough.
    }
  }

  void untag(String slug) => setState(() {
    tags.remove(slug);
    if (landed == slug) {
      landed = null;
      landedFirst = false;
    }
  });

  void setTutorial(bool v) => setState(() => tutorial = v);

  void setSession(int? id) => setState(() => sessionId = id);

  /// The host's Share results, on by default: a finished session you ran is
  /// most often posted to show how it went for everyone.
  bool shareResults = true;
  void setShareResults(bool v) => setState(() => shareResults = v);

  /// Offered only where it can apply: your session, over, not yet shared.
  bool get canShareResults {
    final s = sessions?.where((s) => s.id == sessionId).firstOrNull;
    return s != null && s.isHost && s.endedAt != null && !s.resultsShared;
  }

  Future<void> setAddArea(bool on) async {
    if (!on) {
      setState(() {
        addArea = false;
        area = null;
      });
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
      setState(() {
        addArea = true;
        area = (lat: fix.latitude, lng: fix.longitude);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.locationUnavailable)));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> share() async {
    if (!canShare) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final router = GoRouter.of(context);
    setState(() => sharing = true);
    try {
      final post = await _client.createPost(
        caption: caption.text.trim(),
        mediaIds: [for (final d in drafts) d.media!.id],
        tags: tags,
        isTutorial: tutorial,
        landed: landed,
        landedFirst: landedFirst,
        challengeId: challengeId,
        sessionId: sessionId,
        shareResults: canShareResults && shareResults,
        clubId: clubId,
        placeName: addArea && place.text.trim().isNotEmpty
            ? place.text.trim()
            : null,
        lat: addArea ? area?.lat : null,
        lng: addArea ? area?.lng : null,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.posted)));
      leaving = true;
      if (router.canPop()) {
        router.pop(post);
      } else {
        router.go('/rooms/feed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => sharing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FootbagApiException ? e.detail : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
    }
  }

  bool leaving = false;

  /// Leaving with work in the composer asks first. Uploaded media that is
  /// never posted is left for the server's sweep, not deleted from here.
  Future<bool> confirmLeave() async {
    if (leaving || !hasContent) return true;
    final l10n = L10n.of(context);
    final result = await showOkCancelAlertDialog(
      context: context,
      title: l10n.discardPostTitle,
      okLabel: l10n.discard,
      cancelLabel: l10n.cancel,
      isDestructive: true,
    );
    return result == OkCancelResult.ok;
  }

  @override
  Widget build(BuildContext context) => ComposeView(this);
}

/// Mirrors the API's carousel limit.
const maxPostMedia = 10;
