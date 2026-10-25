// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/dash/dash_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The home screen.
///
/// The doc is explicit: "Dash is what you land on after login, not the feed.
/// The app opens on *is anyone playing?* rather than *what did people post?*"
///
/// Three of Dash's four jobs work with nobody else on the platform — session
/// logging, goals and the trick database — and only the map needs other people.
/// That is what makes this screen worth opening on day one, and why the empty
/// state leads with the action that works alone rather than an empty map.
class Dash extends StatefulWidget {
  const Dash({super.key});

  @override
  DashController createState() => DashController();
}

class DashController extends State<Dash> with WidgetsBindingObserver {
  /// `null` while the first load is in flight, so the view can tell "not yet"
  /// from "nothing at all" — an empty list is a real answer.
  List<FootbagSession>? sessions;
  Object? error;
  bool busy = false;

  /// Redrawn once a second while something is running, so the clock moves.
  /// Cancelled the moment nothing is: a timer that outlives its reason is a
  /// battery cost nobody asked for.
  Timer? _tick;

  /// Mirrors the server's check-in interval. A constant with no endpoint, so
  /// this is the one place to follow it if it changes.
  static const checkInInterval = Duration(minutes: 30);
  static const checkInWarning = Duration(minutes: 10);

  FootbagSession? get running =>
      sessions?.where((s) => s.isRunning).firstOrNull;

  List<FootbagSession> get upcoming =>
      sessions?.where((s) => s.isUpcoming).toList() ?? const [];

  List<FootbagSession> get past =>
      sessions?.where((s) => !s.isRunning && !s.isUpcoming).toList() ?? const [];

  /// Minutes until the check-in lapses, or null when it is not worth saying.
  ///
  /// Shown only inside the final ten minutes: a number counting down for half
  /// an hour is nagging, not informing.
  int? get minutesUntilCheckInDue {
    final last = running?.lastCheckinAt ?? running?.startedAt;
    if (last == null) return null;
    final remaining = last.add(checkInInterval).difference(DateTime.now());
    if (remaining.isNegative || remaining > checkInWarning) return null;
    return (remaining.inSeconds / 60).ceil();
  }

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
    // The server auto-stops a session whose check-in lapsed, awake or not.
    // Without this, returning after two hours shows a running clock and a live
    // check-in button for a session that ended long ago.
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

  /// Start a session. Deliberately takes no arguments — the doc's whole point
  /// is that this is one tap, not a form.
  Future<void> startAction() async {
    await _run(() => Matrix.of(context).client.startSession());
  }

  Future<void> checkInAction(int id) async {
    await _run(() => Matrix.of(context).client.checkInToSession(id));
  }

  /// Stop, then go straight to reporting — the doc says stopping "leads into
  /// reporting", and reporting is the step most likely to be skipped.
  Future<void> stopAction(int id) async {
    if (!await _run(() => Matrix.of(context).client.stopSession(id))) return;
    if (!mounted) return;
    await context.push<bool>('/rooms/dash/$id/report');
    if (mounted) await load();
  }

  Future<void> openReport(int id) async {
    final filed = await context.push<bool>('/rooms/dash/$id/report');
    if (filed == true && mounted) await load();
  }

  /// Run an action, then reload. Returns whether it succeeded.
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
  Widget build(BuildContext context) => DashView(this);
}
