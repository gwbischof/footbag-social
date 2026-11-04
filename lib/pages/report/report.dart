// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/report/report_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Reporting what you worked on in a session.
///
/// The favourites list is what makes this fast: the tricks are pre-listed, so
/// a session is graded by tapping a rung rather than searching the dictionary.
class Report extends StatefulWidget {
  final int sessionId;

  const Report({required this.sessionId, super.key});

  @override
  ReportController createState() => ReportController();
}

class ReportController extends State<Report> {
  /// `null` until the first load finishes, so the view can tell "not yet" from
  /// "nothing to show".
  List<FootbagFavourite>? favourites;

  /// What the player meant to work on, read back first: a checklist chosen
  /// an hour ago is answerable in seconds, where a blank list is not.
  List<FootbagFavourite> goals = const [];
  Object? error;
  bool saving = false;

  /// The session being reported on.
  ///
  /// Fetched so the screen can say *which* session it is: you arrive here from
  /// a list of near-identical rows, and a title of just "Report progress"
  /// leaves no way to tell you opened the wrong one.
  FootbagSession? session;

  String? get sessionLabel {
    final s = session;
    if (s == null) return null;
    final when = s.startedAt ?? s.scheduledAt;
    return when == null ? s.name : '${s.name} · ${_day(when)}';
  }

  static String _day(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}'
      '-${when.day.toString().padLeft(2, '0')}';

  /// Whether leaving now would lose work.
  bool get hasUnsavedWork =>
      claimed.isNotEmpty || commentController.text.trim().isNotEmpty;

  /// Redraw when the kicks box changes, so the unsaved-work guard sees it.
  void onKicksChanged() => setState(() {});

  /// Working state, keyed by slug. A trick with no entry here is one the player
  /// has not touched, and is left out of the request entirely rather than sent
  /// as an empty claim.
  final Map<String, FootbagReportEntryInput> _entries = {};

  /// One controller per trick, owned here rather than by the row widget.
  ///
  /// The count field used to be uncontrolled, which split the truth in two: a
  /// count loaded from an existing report never appeared in the box, and a
  /// typed one disappeared as soon as the row scrolled past the lazy list's
  /// cache extent and its element was destroyed. Owning them here means the
  /// text survives both, and there is one source of truth again.
  final Map<String, TextEditingController> _countControllers = {};

  final commentController = TextEditingController();

  /// Consecutive kicks: a number with no trick attached.
  ///
  /// Separate from [_entries], which is keyed by slug, because this row has no
  /// slug to key it by — that is exactly what the `kicks` kind is for.
  final kicksController = TextEditingController();

  bool includeNumbers = true;

  FootbagReportEntryInput? entryFor(String slug) => _entries[slug];

  TextEditingController countControllerFor(String slug) =>
      _countControllers.putIfAbsent(slug, TextEditingController.new);

  int? get kicks {
    final raw = kicksController.text.trim();
    return raw.isEmpty ? null : int.tryParse(raw);
  }

  /// The rows that will actually be filed.
  List<FootbagReportEntryInput> get claimed {
    final k = kicks;
    return [
      if (k != null) FootbagReportEntryInput.kicks(k),
      ..._entries.values.where((e) => e.saysSomething),
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    kicksController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final client = Matrix.of(context).client;
      // All at once: they are independent, and the screen cannot be drawn
      // without any of them.
      final results = await Future.wait([
        client.fetchFavourites(),
        client.fetchReport(widget.sessionId),
        client.fetchSession(widget.sessionId),
        client.fetchGoals(widget.sessionId),
      ]);
      if (!mounted) return;

      final loaded = results[0] as List<FootbagFavourite>;
      final existing = results[1] as FootbagReport?;
      final loadedSession = results[2] as FootbagSession;

      final goalRows = results[3] as List<FootbagGoal>;
      final goalSlugs = {for (final g in goalRows) g.entrySlug};
      setState(() {
        goals = [
          for (final (i, g) in goalRows.indexed)
            FootbagFavourite(entrySlug: g.entrySlug, name: g.name, position: i),
        ];
        // A goal is listed once, with the goals.
        favourites = loaded
            .where((f) => !goalSlugs.contains(f.entrySlug))
            .toList();
        session = loadedSession;
        error = null;
        if (existing != null) {
          // Editing an existing report, so start from what was filed rather
          // than from blank — this screen is reachable again after saving.
          _entries
            ..clear()
            ..addEntries(
              existing.entries
                  .where((e) => e.entrySlug != null)
                  .map((e) => MapEntry(e.entrySlug!, e.toInput())),
            );
          for (final e in existing.entries) {
            if (e.kind == 'kicks') {
              kicksController.text = e.count?.toString() ?? '';
            } else if (e.entrySlug != null) {
              countControllerFor(e.entrySlug!).text = e.count?.toString() ?? '';
            }
          }
          commentController.text = existing.comment;
          includeNumbers = existing.includeNumbers;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  /// Set or clear a rung.
  ///
  /// Takes a nullable grade because that is what the widget actually reports:
  /// tapping the selected segment of a SegmentedButton with
  /// `emptySelectionAllowed` emits the *empty set*, and an earlier version
  /// dropped that on the floor — so clearing a mis-tap was described in three
  /// comments and implemented nowhere.
  void setGrade(String slug, FootbagGrade? grade) {
    setState(() {
      final current =
          _entries[slug] ?? FootbagReportEntryInput(entrySlug: slug);
      _entries[slug] = grade == null
          ? current.copyWith(clearGrade: true)
          : current.copyWith(grade: grade);
    });
  }

  void setCount(String slug, String raw) {
    final trimmed = raw.trim();
    final parsed = trimmed.isEmpty ? null : int.tryParse(trimmed);
    setState(() {
      final current =
          _entries[slug] ?? FootbagReportEntryInput(entrySlug: slug);
      _entries[slug] = parsed == null
          ? current.copyWith(clearCount: true)
          : current.copyWith(count: parsed);
    });
  }

  void toggleFirst(String slug) {
    setState(() {
      final current =
          _entries[slug] ?? FootbagReportEntryInput(entrySlug: slug);
      _entries[slug] = current.copyWith(isFirst: !current.isFirst);
    });
  }

  void toggleIncludeNumbers(bool value) =>
      setState(() => includeNumbers = value);

  /// Ask before throwing away a filled-in report.
  ///
  /// Uses the repo's own adaptive dialog rather than a bare AlertDialog, so it
  /// matches every other confirmation in the app.
  Future<void> confirmDiscard() async {
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);
    final result = await showOkCancelAlertDialog(
      context: context,
      title: l10n.discardReportTitle,
      message: l10n.discardReportBody,
      okLabel: l10n.discard,
      cancelLabel: l10n.keepEditing,
      isDestructive: true,
    );
    if (result == OkCancelResult.ok && mounted) navigator.pop();
  }

  Future<void> saveAction() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);

    setState(() => saving = true);
    try {
      await Matrix.of(context).client.fileReport(
        widget.sessionId,
        comment: commentController.text.trim(),
        includeNumbers: includeNumbers,
        entries: claimed,
      );
    } on FootbagApiException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
      return;
    } catch (e, s) {
      Logs().w('Filing a report failed', e, s);
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => saving = false);

    // The moment after a session is the moment there is something to show.
    // A first is the best of it -- "I just landed this" was the Modified
    // forum's biggest thread ever -- so a first leads, and posting it is one
    // tap: the composer opens with the trick marked landed, first time. A
    // first can be posted even from a private session; the session simply
    // stays off the card. With no first, a public session is offered to the
    // feed as before, and a private one just saves.
    final router = GoRouter.of(context);
    final s = session;
    final public = s?.onFeed == 'public';
    final names = {
      for (final f in [...?favourites, ...goals]) f.entrySlug: f.name,
    };
    final firsts = [
      for (final e in _entries.values)
        if (e.isFirst && e.entrySlug != null)
          (slug: e.entrySlug!, name: names[e.entrySlug] ?? e.entrySlug!),
    ];
    if (firsts.isEmpty && !public) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.reportSaved)));
      navigator.pop(true);
      return;
    }
    final first = firsts.firstOrNull;
    final share = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Nyfa.ground,
      shape: Nyfa.sheetShape,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (first != null) ...[
                Text(
                  l10n.firstTrickTitle(first.name).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: Nyfa.display,
                    fontSize: 40,
                    height: 0.95,
                    color: Nyfa.paper,
                  ),
                ),
                if (firsts.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.andMoreFirsts(firsts.length - 1),
                    style: Nyfa.bodyMuted,
                  ),
                ],
                const SizedBox(height: 8),
                Text(l10n.postYourFirstPrompt, style: Nyfa.bodyMuted),
              ] else ...[
                Text(l10n.reportSavedTitle, style: Nyfa.heading),
                const SizedBox(height: 8),
                Text(
                  s!.isHost
                      ? l10n.shareSessionPromptHost
                      : l10n.shareSessionPrompt,
                  style: Nyfa.bodyMuted,
                ),
              ],
              const SizedBox(height: 20),
              NyfaForm.action(
                key: const Key('ReportShareToFeed'),
                label: first != null ? l10n.postIt : l10n.shareToFeed,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              NyfaForm.action(
                key: const Key('ReportNotNow'),
                label: l10n.notNow,
                filled: false,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    navigator.pop(true);
    if (share != true) return;
    unawaited(
      router.push(
        Uri(
          path: '/rooms/feed/new',
          queryParameters: {
            if (first != null) ...{
              'landed': first.slug,
              'name': first.name,
              'first': '1',
            },
          },
        ).toString(),
        extra: public ? widget.sessionId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ReportView(this);
}
