// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/pages/trick_picker/trick_picker_view.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
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

  final searchController = TextEditingController();
  final Set<String> chosen = {};

  /// Debounces the search so typing does not fire a request per keystroke.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(load());
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
      final loaded = await Matrix.of(context).client.fetchEntries(
        query: searchController.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) => TrickPickerView(this);
}
