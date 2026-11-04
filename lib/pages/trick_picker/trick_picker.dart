// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/pages/trick_picker/trick_picker_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Browse the dictionary and pick tricks to work on.
///
/// Returns the chosen slugs via `pop`, so the caller owns the save — the picker
/// never writes. That keeps "what the dictionary contains" and "what this
/// player is working on" as separate concerns.
class TrickPicker extends StatefulWidget {
  /// Slugs the player already has, shown as added and not selectable twice.
  final Set<String> alreadyHave;

  const TrickPicker({this.alreadyHave = const {}, super.key});

  @override
  TrickPickerController createState() => TrickPickerController();
}

class TrickPickerController extends State<TrickPicker> {
  List<FootbagEntry>? entries;
  Object? error;

  /// Your favourites, in your order: what you are working on is what you are
  /// most likely to tag or have just landed, so with no search they lead the
  /// list instead of sitting somewhere in 277 alphabetical rows.
  List<String> favourites = const [];

  bool get searching => searchController.text.trim().isNotEmpty;

  /// Entries in display order: favourites first when not searching.
  List<FootbagEntry> get ordered {
    final all = entries ?? const <FootbagEntry>[];
    if (searching || favourites.isEmpty) return all;
    final bySlug = {for (final e in all) e.slug: e};
    final first = [
      for (final s in favourites)
        if (bySlug[s] != null) bySlug[s]!,
    ];
    final pinned = {for (final e in first) e.slug};
    return [...first, ...all.where((e) => !pinned.contains(e.slug))];
  }

  /// How many of [ordered] are pinned favourites.
  int get pinnedCount => searching
      ? 0
      : favourites
            .where((s) => entries?.any((e) => e.slug == s) ?? false)
            .length;

  final searchController = TextEditingController();
  final Set<String> chosen = {};

  /// Debounces the search so typing does not fire a request per keystroke.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    unawaited(_loadFavourites());
  }

  Future<void> _loadFavourites() async {
    try {
      final f = await Matrix.of(context).client.fetchFavourites();
      if (!mounted) return;
      setState(() => favourites = [for (final x in f) x.entrySlug]);
    } catch (_) {
      // The full list still works; it just is not reordered.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(load());
    });
  }

  Future<void> load() async {
    try {
      final loaded = await Matrix.of(
        context,
      ).client.fetchEntries(query: searchController.text.trim());
      if (!mounted) return;
      setState(() {
        entries = loaded;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  bool isChosen(String slug) => chosen.contains(slug);

  void toggle(String slug) => setState(() {
    chosen.contains(slug) ? chosen.remove(slug) : chosen.add(slug);
  });

  void confirm() => Navigator.of(context).pop(chosen.toList());

  /// Nothing fits: suggest it, carrying over what was typed, and come back
  /// with it chosen -- it is usable at once, approved or not.
  Future<void> suggest() async {
    final entry = await context.push<FootbagEntry>(
      '/rooms/dash/suggest-trick',
      extra: searchController.text.trim(),
    );
    if (entry == null || !mounted) return;
    searchController.text = entry.name;
    setState(() => chosen.add(entry.slug));
    await load();
  }

  @override
  Widget build(BuildContext context) => TrickPickerView(this);
}
