// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/new_session/new_session_view.dart';
import 'package:footbag_network/pages/session/where_sheet.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Scheduling a session for later.
///
/// The doc is firm that **Start stays one tap** — this screen is the other
/// mode, the one the doc says "is the only mode that needs a form". Everything
/// here still has a default, so the form can be submitted without touching
/// anything but the date.
class NewSession extends StatefulWidget {
  /// Preselect a club -- arriving from that club's page.
  final int? clubId;

  const NewSession({this.clubId, super.key});

  @override
  NewSessionController createState() => NewSessionController();
}

class NewSessionController extends State<NewSession> {
  final nameController = TextEditingController();
  final noteController = TextEditingController();

  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 18, minute: 0);

  String type = 'freestyle';
  String joining = 'open';
  bool onFeed = true;
  bool saving = false;

  /// Clubs this player belongs to. The picker is hidden while this is empty:
  /// a field with one possible value is not a question.
  List<FootbagClub> clubs = const [];
  int? clubId;

  /// Optional, like everything here but the date: a session with no
  /// location is still a session, and still in Discover by type.
  FootbagWhere? where;

  @override
  void initState() {
    super.initState();
    clubId = widget.clubId;
    Matrix.of(context).client.fetchClubs(mine: true).then((all) {
      if (!mounted) return;
      setState(() => clubs = all.where((c) => c.isMember).toList());
    }, onError: (_) {});
  }

  void setClub(String value) =>
      setState(() => clubId = value == 'none' ? null : int.parse(value));

  @override
  void dispose() {
    nameController.dispose();
    noteController.dispose();
    super.dispose();
  }

  /// The chosen instant, in local time.
  DateTime get when =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  bool get isFuture => when.isAfter(DateTime.now());

  void setType(String value) => setState(() => type = value);
  void setJoining(String value) => setState(() => joining = value);
  void setOnFeed(bool value) => setState(() => onFeed = value);

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null && mounted) setState(() => time = picked);
  }

  Future<void> pickWhere() async {
    final picked = await showWhereSheet(
      context,
      client: Matrix.of(context).client,
      current: where,
    );
    if (picked != null && mounted) setState(() => where = picked);
  }

  Future<void> createAction() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);

    setState(() => saving = true);
    try {
      await Matrix.of(context).client.startSession(
        name: nameController.text.trim().isEmpty
            ? null
            : nameController.text.trim(),
        type: type,
        joining: joining,
        onFeed: onFeed ? 'public' : 'private',
        note: noteController.text.trim(),
        // .toUtc(): the API rejects a naive timestamp outright, and a local
        // one without an offset would otherwise mean an hour nobody chose.
        scheduledAt: when.toUtc(),
        clubId: clubId,
        where: where,
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
      Logs().w('Scheduling a session failed', e, s);
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toLocalizedString(context))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => saving = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.sessionScheduledToast)));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => NewSessionView(this);
}
