// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/favourites/favourites_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The tricks a player is working on.
///
/// This is the screen the report depends on: the report pre-lists favourites so
/// a session is graded by tapping a rung rather than searching the dictionary.
/// Without it the report opens empty for everyone, which is why it exists
/// before clubs, feeds or anything else.
class Favourites extends StatefulWidget {
  const Favourites({super.key});

  @override
  FavouritesController createState() => FavouritesController();
}

class FavouritesController extends State<Favourites> {
  List<FootbagFavourite>? favourites;
  Object? error;
  bool saving = false;

  /// Working order, held locally so a drag feels instant.
  ///
  /// Saved on every change rather than behind a Save button: reordering a list
  /// and then losing it to a back button is a worse failure than an extra
  /// request, and the endpoint takes the whole list anyway.
  List<FootbagFavourite> working = [];

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final loaded = await Matrix.of(context).client.fetchFavourites();
      if (!mounted) return;
      setState(() {
        favourites = loaded;
        working = List.of(loaded);
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  Future<void> addAction() async {
    // The picker returns the slugs it wants added.
    final added = await context.push<List<String>>(
      '/rooms/dash/favourites/add',
      extra: working.map((f) => f.entrySlug).toSet(),
    );
    if (added == null || added.isEmpty || !mounted) return;

    final slugs = [...working.map((f) => f.entrySlug), ...added];
    await _save(slugs);
  }

  Future<void> removeAction(String slug) async {
    final slugs = working
        .map((f) => f.entrySlug)
        .where((s) => s != slug)
        .toList();
    await _save(slugs);
  }

  void reorder(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem, not the deprecated onReorder: it hands back an index
      // already adjusted for the removal, so the usual
      // `newIndex > oldIndex ? newIndex - 1 : newIndex` correction is not only
      // unnecessary here but would move every downward drag one place short.
      final moved = working.removeAt(oldIndex);
      working.insert(newIndex, moved);
    });
    unawaited(_save(working.map((f) => f.entrySlug).toList()));
  }

  Future<void> _save(List<String> slugs) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => saving = true);
    try {
      final saved = await Matrix.of(context).client.setFavourites(slugs);
      if (!mounted) return;
      setState(() {
        favourites = saved;
        working = List.of(saved);
        saving = false;
      });
    } on FootbagApiException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotSignedIn ? l10n.signedOutAgain : e.detail),
        ),
      );
      // Put the list back the way the server has it, so the screen never shows
      // an order that was not accepted.
      unawaited(load());
    } catch (e, s) {
      Logs().w('Saving favourites failed', e, s);
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toLocalizedString(context))),
      );
      unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) => FavouritesView(this);
}
