// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/favourites/favourites.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class FavouritesView extends StatelessWidget {
  final FavouritesController controller;

  const FavouritesView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      key: const Key('FavouritesScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(
        title: l10n.favourites,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              key: const Key('AddTrickButton'),
              onPressed: controller.saving ? null : controller.addAction,
              icon: const Icon(Icons.add, color: Nyfa.green, size: 20),
              label: Text(
                l10n.addTrick.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 17,
                  letterSpacing: 1.1,
                  color: Nyfa.green,
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
    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 80),
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
    if (controller.favourites == null) {
      return const Center(
        child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
      );
    }

    if (controller.working.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 72),
          const Icon(Icons.star_outline_rounded, size: 44, color: Nyfa.muted),
          const SizedBox(height: 18),
          Text(
            l10n.noFavouritesHere.toUpperCase(),
            textAlign: TextAlign.center,
            style: Nyfa.heading,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noFavouritesHereBody,
            textAlign: TextAlign.center,
            style: Nyfa.bodyMuted,
          ),
          const SizedBox(height: 22),
          Center(
            child: NyfaForm.action(
              key: const Key('AddFirstTrickButton'),
              label: l10n.addTrick,
              onPressed: controller.saving ? null : controller.addAction,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(l10n.favouritesHelp, style: Nyfa.bodyMuted),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              const Icon(Icons.drag_handle, size: 16, color: Nyfa.muted),
              const SizedBox(width: 6),
              Text(l10n.reorderHint.toUpperCase(), style: Nyfa.eyebrow),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('FavouritesList'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: controller.working.length,
            onReorderItem: controller.reorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Nyfa.raised,
              child: child,
            ),
            itemBuilder: (context, i) {
              final f = controller.working[i];
              return DecoratedBox(
                key: ValueKey(f.entrySlug),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Nyfa.rule)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          // Padded to a real target rather than a bare icon.
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Icon(Icons.drag_handle, color: Nyfa.muted),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          f.name.toUpperCase(),
                          style: Nyfa.heading.copyWith(fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: Key('Remove_${f.entrySlug}'),
                        tooltip: l10n.removeTrick,
                        onPressed: controller.saving
                            ? null
                            : () => controller.removeAction(f.entrySlug),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Nyfa.muted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
