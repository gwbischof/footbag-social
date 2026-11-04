// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/post_events.dart';
import 'package:footbag_network/pages/feed/widgets/face_stack.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show Logs;

/// "12 days left", "Starts tomorrow", "Ended" -- when, in the words people
/// use, never a date to work out.
String challengeTiming(L10n l10n, FootbagChallenge c, DateTime now) {
  if (c.isUpcoming) {
    final days = _calendarDays(now, c.startsAt);
    return l10n.challengeStartsInDays(days);
  }
  if (!c.isActive) return l10n.challengeEnded;
  final left = c.endsAt.difference(now);
  return left.inHours < 24
      ? l10n.challengeHoursLeft(left.inHours < 1 ? 1 : left.inHours)
      : l10n.challengeDaysLeft(left.inDays);
}

int _calendarDays(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.toLocal().year, to.toLocal().month, to.toLocal().day);
  return b.difference(a).inDays.clamp(0, 9999);
}

void _enter(BuildContext context, FootbagChallenge c) => unawaited(
  context.push(
    Uri(
      path: '/rooms/feed/new',
      queryParameters: {'challenge': c.slug},
    ).toString(),
  ),
);

/// The running challenge, at the top of the feed.
///
/// A clip on its own got no more replies on the Modified forum than words
/// did; inside a format it did, for years. So while a challenge runs it is
/// the first thing on the feed -- what it is, how long is left, who is in --
/// with the button to enter right there. One at a time: two banners would be
/// a list of things to ignore.
class ChallengeBanner extends StatefulWidget {
  /// Test seam: challenges to show, with no server. Null in the app.
  static List<FootbagChallenge>? preview;

  const ChallengeBanner({super.key});

  @override
  State<ChallengeBanner> createState() => _ChallengeBannerState();
}

class _ChallengeBannerState extends State<ChallengeBanner> {
  FootbagChallenge? challenge;
  StreamSubscription<FootbagPost>? _published;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // An entry just posted: fresh counts, faces and entries left.
    _published = PostEvents.published.listen((p) {
      if (p.challenge != null) unawaited(_load());
    });
  }

  @override
  void dispose() {
    unawaited(_published?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all =
          ChallengeBanner.preview ??
          await Matrix.of(context).client.fetchChallenges();
      if (!mounted) return;
      setState(
        () => challenge =
            all.where((c) => c.isActive).firstOrNull ?? all.firstOrNull,
      );
    } catch (e) {
      // The feed is the point of this screen; a missing banner is not news.
      Logs().w('Loading challenges failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    if (c == null) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Material(
        color: Nyfa.raised,
        shape: Nyfa.sheetShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('ChallengeBanner_${c.slug}'),
          onTap: () => context.push(
            '/rooms/feed/challenge/${Uri.encodeComponent(c.slug)}',
            extra: c.title,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _When(challenge: c),
                const SizedBox(height: 6),
                Text(
                  c.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Nyfa.display,
                    fontSize: 36,
                    height: 0.95,
                    color: Nyfa.paper,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (c.entrants.isNotEmpty) ...[
                      FaceStack(people: c.entrants, size: 28, max: 5),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        _counts(l10n, c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Nyfa.bodyMuted,
                      ),
                    ),
                    if (c.canEnter) ...[
                      const SizedBox(width: 12),
                      FilledButton(
                        key: Key('ChallengeEnter_${c.slug}'),
                        onPressed: () => _enter(context, c),
                        style: FilledButton.styleFrom(
                          backgroundColor: Nyfa.green,
                          foregroundColor: Nyfa.ground,
                          minimumSize: const Size(88, 44),
                          shape: Nyfa.controlShape,
                          textStyle: const TextStyle(
                            fontFamily: Nyfa.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        child: Text(l10n.enterChallenge),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _counts(L10n l10n, FootbagChallenge c) => c.entryCount == 0
    ? l10n.challengeNoEntriesYet
    : '${l10n.challengeEntryCount(c.entryCount)}  ·  ${l10n.challengePlayerCount(c.entrantCount)}';

/// A live dot and how long is left, or when it starts, or that it ended.
class _When extends StatelessWidget {
  final FootbagChallenge challenge;

  const _When({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final live = challenge.isActive;
    return Row(
      children: [
        if (live) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Nyfa.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          '${l10n.challenge}  ·  ${challengeTiming(l10n, challenge, DateTime.now())}',
          style: Nyfa.label.copyWith(color: live ? Nyfa.paper : Nyfa.muted),
        ),
      ],
    );
  }
}

/// The top of a challenge's page: the event in full, above its entries.
///
/// The rules are the organiser's own words, shown whole -- they are what
/// people argue about, so nothing gets trimmed. The button says exactly where
/// you stand: enter, entered N of M, starts Friday, ended.
class ChallengeHeader extends StatefulWidget {
  final String slug;

  /// Test seam: the challenge to show, with no server. Null in the app.
  static FootbagChallenge? preview;

  const ChallengeHeader({required this.slug, super.key});

  @override
  State<ChallengeHeader> createState() => _ChallengeHeaderState();
}

class _ChallengeHeaderState extends State<ChallengeHeader> {
  FootbagChallenge? challenge;
  StreamSubscription<FootbagPost>? _published;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _published = PostEvents.published.listen((p) {
      if (p.challenge?.slug == widget.slug) unawaited(_load());
    });
  }

  @override
  void dispose() {
    unawaited(_published?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c =
          ChallengeHeader.preview ??
          await Matrix.of(context).client.fetchChallenge(widget.slug);
      if (mounted) setState(() => challenge = c);
    } catch (e) {
      // The entries below still load; a page without its header is better
      // than an error in place of both.
      Logs().w('Loading a challenge failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    if (c == null) return const SizedBox(height: 8);
    final l10n = L10n.of(context);

    final status = c.canEnter
        ? null
        : c.isUpcoming
        ? challengeTiming(l10n, c, DateTime.now())
        : c.isActive
        ? l10n.challengeEnteredAll(c.myEntries, c.maxEntries)
        : l10n.challengeEnded;

    return Column(
      key: const Key('ChallengeHeader'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _When(challenge: c),
              const SizedBox(height: 8),
              Text(
                c.title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 48,
                  height: 0.95,
                  color: Nyfa.paper,
                ),
              ),
              if (c.body.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(c.body, style: Nyfa.bodyText.copyWith(height: 1.5)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (c.entrants.isNotEmpty) ...[
                    FaceStack(people: c.entrants),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(_counts(l10n, c), style: Nyfa.bodyText)),
                ],
              ),
              const SizedBox(height: 18),
              if (status == null)
                NyfaForm.action(
                  key: Key('ChallengeEnter_${c.slug}'),
                  label: c.myEntries == 0
                      ? l10n.enterChallenge
                      : l10n.enterAgain(c.myEntries, c.maxEntries),
                  onPressed: () => _enter(context, c),
                )
              else
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Nyfa.tonal,
                    borderRadius: Nyfa.rounded,
                  ),
                  child: Text(
                    status,
                    style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        NyfaForm.section(l10n.challengeEntries),
      ],
    );
  }
}
