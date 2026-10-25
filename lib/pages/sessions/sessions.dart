// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/sessions/sessions_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Your sessions: the one that is running, and the ones that are done.
///
/// A session is the primary object in this app — the training log is just
/// these rows, which is why there is no separate "journal" anywhere.
class Sessions extends StatefulWidget {
  const Sessions({super.key});

  @override
  SessionsController createState() => SessionsController();
}

class SessionsController extends State<Sessions> {
  /// `null` while the first load is in flight, so the view can tell "nothing
  /// yet" from "nothing at all" — an empty list is a real answer and deserves
  /// different words from a spinner.
  List<FootbagSession>? sessions;
  Object? error;

  /// Redrawn once a second while something is running, so the elapsed clock
  /// moves. Cancelled the moment nothing is running: a timer that outlives its
  /// reason is a battery cost nobody asked for.
  Timer? _tick;

  FootbagSession? get running =>
      sessions?.where((s) => s.isRunning).firstOrNull;

  List<FootbagSession> get past =>
      sessions?.where((s) => !s.isRunning).toList() ?? const [];

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    if (running != null) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> load() async {
    try {
      final loaded = await Matrix.of(context).client.fetchSessions();
      if (!mounted) return;
      setState(() {
        sessions = loaded;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
    _syncTicker();
  }

  /// Start one. Deliberately takes no arguments.
  ///
  /// The server names it and fills in the rest from defaults, so this is one
  /// tap rather than a form — anything wrong is corrected from the running
  /// session itself.
  Future<void> startAction() async {
    await _run(() => Matrix.of(context).client.startSession());
  }

  Future<void> checkInAction(int id) async {
    await _run(() => Matrix.of(context).client.checkInToSession(id));
  }

  Future<void> stopAction(int id) async {
    await _run(() => Matrix.of(context).client.stopSession(id));
  }

  /// Run an action, then reload.
  ///
  /// Reloading rather than patching the local list keeps one source of truth:
  /// the server decides whether a session is still running, and a client that
  /// guessed would disagree with it exactly when a check-in had lapsed.
  Future<void> _run(Future<FootbagSession> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    try {
      await action();
    } on FootbagApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
      return;
    } catch (e, s) {
      Logs().w('Session action failed', e, s);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.oopsSomethingWentWrong)));
      return;
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => SessionsView(this);
}
