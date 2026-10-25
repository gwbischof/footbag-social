// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/sessions/sessions_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
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

class SessionsController extends State<Sessions> with WidgetsBindingObserver {
  /// `null` while the first load is in flight, so the view can tell "nothing
  /// yet" from "nothing at all" — an empty list is a real answer and deserves
  /// different words from a spinner.
  List<FootbagSession>? sessions;
  Object? error;

  /// Redrawn once a second while something is running, so the elapsed clock
  /// moves. Cancelled the moment nothing is running: a timer that outlives its
  /// reason is a battery cost nobody asked for.
  Timer? _tick;

  /// Whether a mutating action is in flight.
  ///
  /// Without it, a double-tap on a slow link posts two sessions, and since
  /// `running` takes the first and `past` excludes anything running, the second
  /// renders nowhere and cannot be stopped.
  bool busy = false;

  /// How long the check-in interval is, mirroring the server's.
  ///
  /// Duplicated from the API rather than fetched because it is a constant the
  /// server has no endpoint for; if it ever changes, this is the one place to
  /// follow it.
  static const checkInInterval = Duration(minutes: 30);

  /// How long the warning is shown for.
  static const checkInWarning = Duration(minutes: 10);

  FootbagSession? get running =>
      sessions?.where((s) => s.isRunning).firstOrNull;

  /// Minutes until the check-in lapses, or null when it is not yet worth saying.
  ///
  /// The doc calls the 30-minute check deliberate friction that must not be
  /// simplified — but friction only works if the deadline is visible, and a
  /// bare button never said one existed. Shown only inside the final ten
  /// minutes: a number counting down for half an hour is nagging, not
  /// informing.
  int? get minutesUntilCheckInDue {
    final session = running;
    final last = session?.lastCheckinAt ?? session?.startedAt;
    if (last == null) return null;
    final remaining = last.add(checkInInterval).difference(DateTime.now());
    if (remaining.isNegative || remaining > checkInWarning) return null;
    // Rounded up, so the last 59 seconds reads "1 min" rather than "0 min".
    return (remaining.inSeconds / 60).ceil();
  }

  /// Scheduled but not yet started.
  List<FootbagSession> get upcoming =>
      sessions?.where((s) => s.isUpcoming).toList() ?? const [];

  List<FootbagSession> get past =>
      sessions
          ?.where((s) => !s.isRunning && !s.isUpcoming)
          .toList() ??
      const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The server auto-stops a session whose check-in lapsed, and it does so
    // whether or not this app was awake. Without this, coming back after two
    // hours shows a running clock and a live "Yes, still here" button for a
    // session that ended long ago -- and tapping it fails.
    if (state == AppLifecycleState.resumed) unawaited(load());
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

  /// Stop, then go straight to reporting.
  ///
  /// The doc is explicit that stopping "leads into reporting" and that
  /// reporting is the step most likely to be skipped. Dropping the session
  /// into a list and hoping the user taps it is how it gets skipped.
  Future<void> stopAction(int id) async {
    if (!await _run(() => Matrix.of(context).client.stopSession(id))) return;
    if (!mounted) return;
    await context.push<bool>('/rooms/sessions/$id/report');
    if (mounted) await load();
  }

  /// Run an action, then reload.
  ///
  /// Reloading rather than patching the local list keeps one source of truth:
  /// the server decides whether a session is still running, and a client that
  /// guessed would disagree with it exactly when a check-in had lapsed.
  /// Run an action, then reload. Returns whether it succeeded.
  ///
  /// Reloading rather than patching the local list keeps one source of truth:
  /// the server decides whether a session is still running, and a client that
  /// guessed would disagree with it exactly when a check-in had lapsed.
  Future<bool> _run(Future<FootbagSession> Function() action) async {
    if (busy) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => busy = true);
    try {
      await action();
    } on FootbagApiException catch (e) {
      if (!mounted) return false;
      setState(() => busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
      return false;
    } catch (e, s) {
      Logs().w('Session action failed', e, s);
      if (!mounted) return false;
      setState(() => busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toLocalizedString(context))),
      );
      return false;
    }
    if (!mounted) return false;
    setState(() => busy = false);
    await load();
    return true;
  }

  @override
  Widget build(BuildContext context) => SessionsView(this);
}
