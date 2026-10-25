// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/report/report_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
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
  Object? error;
  bool saving = false;

  /// Working state, keyed by slug. A trick with no entry here is one the player
  /// has not touched, and is left out of the request entirely rather than sent
  /// as an empty claim.
  final Map<String, FootbagReportEntryInput> _entries = {};

  final commentController = TextEditingController();
  bool includeNumbers = true;

  FootbagReportEntryInput? entryFor(String slug) => _entries[slug];

  /// The tricks that will actually be filed.
  List<FootbagReportEntryInput> get claimed =>
      _entries.values.where((e) => e.saysSomething).toList();

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final client = Matrix.of(context).client;
      // Both at once: they are independent, and the screen cannot be drawn
      // without either.
      final results = await Future.wait([
        client.fetchFavourites(),
        client.fetchReport(widget.sessionId),
      ]);
      if (!mounted) return;

      final loaded = results[0] as List<FootbagFavourite>;
      final existing = results[1] as FootbagReport?;

      setState(() {
        favourites = loaded;
        error = null;
        if (existing != null) {
          // Editing an existing report, so start from what was filed rather
          // than from blank — this screen is reachable again after saving.
          _entries
            ..clear()
            ..addEntries(
              existing.entries.map((e) => MapEntry(e.entrySlug, e.toInput())),
            );
          commentController.text = existing.comment;
          includeNumbers = existing.includeNumbers;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  /// Tap a rung. Tapping the one already set clears it.
  ///
  /// Without that, a mis-tap is permanent for the whole session — and the
  /// grade is the one field with no other way to unset it.
  void setGrade(String slug, FootbagGrade grade) {
    setState(() {
      final current = _entries[slug];
      if (current?.grade == grade) {
        _entries[slug] = (current ?? FootbagReportEntryInput(entrySlug: slug))
            .copyWith(clearGrade: true);
      } else {
        _entries[slug] =
            (current ?? FootbagReportEntryInput(entrySlug: slug))
                .copyWith(grade: grade);
      }
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
    messenger.showSnackBar(SnackBar(content: Text(l10n.reportSaved)));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => ReportView(this);
}
