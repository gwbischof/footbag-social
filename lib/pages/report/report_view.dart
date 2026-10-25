// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/report/report.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class ReportView extends StatelessWidget {
  final ReportController controller;

  const ReportView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      key: const Key('ReportScaffold'),
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(l10n.reportProgress),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              key: const Key('SaveReportButton'),
              onPressed: controller.saving ? null : controller.saveAction,
              child: Text(controller.saving ? l10n.saving : l10n.save),
            ),
          ),
        ],
      ),
      body: MaxWidthBody(withScrolling: false, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '${controller.error}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (controller.favourites == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final favourites = controller.favourites!;

    return ListView(
      key: const Key('ReportList'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (favourites.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Column(
              spacing: 8,
              children: [
                Text(l10n.noFavouritesYet, style: theme.textTheme.titleMedium),
                Text(
                  l10n.noFavouritesYetBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...favourites.map(
            (f) => _TrickRow(controller: controller, favourite: f),
          ),

        const Divider(height: 32),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('ReportCommentField'),
            controller: controller.commentController,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.howDidItGo,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),

        SwitchListTile(
          key: const Key('IncludeNumbersSwitch'),
          value: controller.includeNumbers,
          onChanged: controller.toggleIncludeNumbers,
          title: Text(l10n.includeMyNumbers),
          subtitle: Text(l10n.includeMyNumbersBody),
        ),
      ],
    );
  }
}

/// One trick: the ladder, a count, and a first.
class _TrickRow extends StatelessWidget {
  final ReportController controller;
  final FootbagFavourite favourite;

  const _TrickRow({required this.controller, required this.favourite});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final entry = controller.entryFor(favourite.entrySlug);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(favourite.name, style: theme.textTheme.titleSmall),

          // The ladder. A segmented control rather than four buttons, because
          // the rungs are a progression and only one can be true at a time.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FootbagGrade>(
              segments: [
                for (final grade in FootbagGrade.values)
                  ButtonSegment(
                    value: grade,
                    label: Text(
                      _gradeLabel(l10n, grade),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
              selected: {?entry?.grade},
              // Nothing selected is a real state -- an untouched trick -- and
              // tapping the selected rung clears it, so a mis-tap is not
              // permanent for the whole session.
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                controller.setGrade(favourite.entrySlug, selection.first);
              },
            ),
          ),

          Row(
            spacing: 12,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: Key('Count_${favourite.entrySlug}'),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.howMany,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (raw) =>
                      controller.setCount(favourite.entrySlug, raw),
                ),
              ),
              Expanded(
                child: FilterChip(
                  key: Key('First_${favourite.entrySlug}'),
                  selected: entry?.isFirst ?? false,
                  onSelected: (_) =>
                      controller.toggleFirst(favourite.entrySlug),
                  avatar: const Icon(Icons.star_outline, size: 18),
                  label: Text(l10n.firstTime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _gradeLabel(L10n l10n, FootbagGrade grade) => switch (grade) {
    FootbagGrade.tried => l10n.gradeTried,
    FootbagGrade.footing => l10n.gradeFooting,
    FootbagGrade.hitting => l10n.gradeHitting,
    FootbagGrade.consistent => l10n.gradeConsistent,
  };
}
