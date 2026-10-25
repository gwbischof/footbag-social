// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/trick_picker/trick_picker.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class TrickPickerView extends StatelessWidget {
  final TrickPickerController controller;

  const TrickPickerView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final count = controller.chosen.length;

    return Scaffold(
      key: const Key('TrickPickerScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(
        title: l10n.trickDictionary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              key: const Key('ConfirmTricksButton'),
              onPressed: count == 0 ? null : controller.confirm,
              child: Text(
                // The count is the point: it says how many taps are about to
                // take effect, so "Add" never fires on an empty selection.
                (count == 0 ? l10n.addTrick : '${l10n.addTrick} ($count)')
                    .toUpperCase(),
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 18,
                  letterSpacing: 1.1,
                  color: count == 0 ? Nyfa.muted : Nyfa.green,
                ),
              ),
            ),
          ),
        ],
      ),
      body: MaxWidthBody(withScrolling: false, child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, L10n l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: TextField(
            key: const Key('TrickSearchField'),
            controller: controller.searchController,
            onChanged: controller.onSearchChanged,
            textInputAction: TextInputAction.search,
            style: Nyfa.bodyText,
            cursorColor: Nyfa.green,
            decoration: Nyfa.input(l10n.searchTricks).copyWith(
              prefixIcon: const Icon(Icons.search, color: Nyfa.muted, size: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.searchTricksHelp,
              style: Nyfa.bodyMuted.copyWith(fontSize: 12),
            ),
          ),
        ),
        Expanded(child: _list(context, l10n)),
      ],
    );
  }

  Widget _list(BuildContext context, L10n l10n) {
    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 56),
          const Icon(Icons.cloud_off_rounded, size: 44, color: Nyfa.muted),
          const SizedBox(height: 18),
          Text(
            l10n.oopsSomethingWentWrong.toUpperCase(),
            textAlign: TextAlign.center,
            style: Nyfa.heading,
          ),
          const SizedBox(height: 8),
          Text(
            controller.error!.toLocalizedString(context),
            textAlign: TextAlign.center,
            style: Nyfa.bodyMuted,
          ),
          const SizedBox(height: 20),
          Center(
            child: NyfaForm.action(
              label: l10n.retry,
              filled: false,
              onPressed: controller.load,
            ),
          ),
        ],
      );
    }
    if (controller.entries == null) {
      return const Center(
        child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
      );
    }
    if (controller.entries!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 56),
          Text(
            l10n.noTricksFound.toUpperCase(),
            textAlign: TextAlign.center,
            style: Nyfa.heading,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noTricksFoundBody,
            textAlign: TextAlign.center,
            style: Nyfa.bodyMuted,
          ),
        ],
      );
    }

    return ListView.builder(
      key: const Key('TrickList'),
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: controller.entries!.length,
      itemBuilder: (context, i) {
        final e = controller.entries![i];
        final have = controller.widget.alreadyHave.contains(e.slug);
        final chosen = controller.isChosen(e.slug);
        return _EntryRow(
          key: ValueKey(e.slug),
          entry: e,
          alreadyHave: have,
          chosen: chosen,
          kindLabel: _kindLabel(l10n, e.kind),
          addedLabel: l10n.alreadyAdded,
          onTap: have ? null : () => controller.toggle(e.slug),
        );
      },
    );
  }

  String _kindLabel(L10n l10n, String kind) => switch (kind) {
    'trick' => l10n.kindTrick,
    'composite' => l10n.kindComposite,
    'string' => l10n.kindString,
    _ => kind,
  };
}

class _EntryRow extends StatelessWidget {
  final FootbagEntry entry;
  final bool alreadyHave;
  final bool chosen;
  final String kindLabel;
  final String addedLabel;
  final VoidCallback? onTap;

  const _EntryRow({
    required this.entry,
    required this.alreadyHave,
    required this.chosen,
    required this.kindLabel,
    required this.addedLabel,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // The breakdown is the dictionary's own shorthand: "dex · dex · del".
    final detail = [
      kindLabel,
      if (entry.adds.isNotEmpty) entry.adds.join(' · '),
      if (entry.aka.isNotEmpty) 'aka ${entry.aka.first}',
    ].join('   ·   ');

    return Semantics(
      button: onTap != null,
      selected: chosen,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chosen ? Nyfa.raised : Colors.transparent,
          border: const Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name.toUpperCase(),
                        style: Nyfa.heading.copyWith(
                          fontSize: 17,
                          // An entry already in the list is context, not an
                          // option, so it steps back rather than disappearing.
                          color: alreadyHave ? Nyfa.muted : Nyfa.paper,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: Nyfa.bodyMuted.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (alreadyHave)
                  Text(
                    addedLabel.toUpperCase(),
                    style: Nyfa.eyebrow.copyWith(fontSize: 13),
                  )
                else
                  Icon(
                    chosen
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: chosen ? Nyfa.green : Nyfa.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
