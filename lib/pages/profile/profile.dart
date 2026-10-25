// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/profile/profile_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Editing your own profile.
///
/// `ProfilePage`, not `Profile`: `package:matrix` exports a `Profile` of its
/// own, and an ambiguous import in the router is a confusing way to find out.
///
/// This screen is also the only way to reach the two privacy switches. Both
/// default to on when a player is provisioned, and `show_sessions` gates the
/// heatmap and rankings — until this existed there was no opt-out at all.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfileController createState() => ProfileController();
}

class ProfileController extends State<ProfilePage> {
  FootbagPlayer? player;
  Object? error;
  bool saving = false;

  final nameController = TextEditingController();
  final bioController = TextEditingController();
  final cityController = TextEditingController();

  final Set<String> styles = {};
  bool discoverable = true;
  bool showSessions = true;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final me = await Matrix.of(context).client.fetchMe();
      if (!mounted) return;
      setState(() {
        player = me;
        error = null;
        nameController.text = me.displayName;
        bioController.text = me.bio;
        cityController.text = me.city ?? '';
        styles
          ..clear()
          ..addAll(me.playStyles);
        discoverable = me.discoverable;
        showSessions = me.showSessions;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  void toggleStyle(String value) => setState(() {
    styles.contains(value) ? styles.remove(value) : styles.add(value);
  });

  void setDiscoverable(bool v) => setState(() => discoverable = v);

  /// Redraw so the save button enables the moment a name exists.
  ///
  /// The name field is the only required one, and `canSave` reads it straight
  /// from the controller — without a rebuild the button would stay disabled
  /// while a perfectly good name sat in the box.
  void onNameChanged() => setState(() {});
  void setShowSessions(bool v) => setState(() => showSessions = v);

  bool get canSave => !saving && nameController.text.trim().isNotEmpty;

  Future<void> saveAction() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);

    setState(() => saving = true);
    try {
      await Matrix.of(context).client.updateMe(
        displayName: nameController.text.trim(),
        bio: bioController.text.trim(),
        // Empty clears it — null would mean "leave it alone", so a player
        // could never remove a city they no longer want shown.
        city: cityController.text.trim(),
        playStyles: styles.toList(),
        discoverable: discoverable,
        showSessions: showSessions,
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
      Logs().w('Saving the profile failed', e, s);
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toLocalizedString(context))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => saving = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => ProfileView(this);
}
