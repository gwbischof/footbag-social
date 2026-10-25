// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/report/report.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Reporting a session: a scorecard, one trick per block.
class ReportView extends StatelessWidget {
  final ReportController controller;

  const ReportView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // A graded report is real work, and BackButton used to discard it without
    // a word. PopScope is already the convention here (chat_view, chat_list_view).
    return PopScope(
      canPop: !controller.hasUnsavedWork,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.confirmDiscard();
      },
      child: _scaffold(context, l10n),
    );
  }

  Widget _scaffold(BuildContext context, L10n l10n) {
    return Scaffold(
      key: const Key('ReportScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(
        title: l10n.reportProgress,
        subtitle: controller.sessionLabel,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              key: const Key('SaveReportButton'),
              onPressed: controller.saving ? null : controller.saveAction,
              child: Text(
                (controller.saving ? l10n.saving : l10n.save).toUpperCase(),
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 18,
                  letterSpacing: 1.1,
                  color: controller.saving ? Nyfa.muted : Nyfa.green,
                ),
              ),
            ),
          ),
        ],
      ),
      body: MaxWidthBody(withScrolling: false, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = L10n.of(context);

    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 88),
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
            child: OutlinedButton(
              onPressed: controller.load,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Nyfa.rule),
                shape: const RoundedRectangleBorder(),
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                l10n.retry.toUpperCase(),
                style: const TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 17,
                  letterSpacing: 1.1,
                  color: Nyfa.paper,
                ),
              ),
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

    final favourites = controller.favourites!;

    return ListView(
      key: const Key('ReportList'),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (favourites.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
            child: Column(
              children: [
                const Icon(Icons.star_outline_rounded, size: 40, color: Nyfa.muted),
                const SizedBox(height: 16),
                Text(
                  l10n.noFavouritesYet.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Nyfa.heading,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.noFavouritesYetBody,
                  textAlign: TextAlign.center,
                  style: Nyfa.bodyMuted,
                ),
                const SizedBox(height: 20),
                // This screen is exactly where someone finds out they need
                // favourites, so it is where the way to add them belongs.
                NyfaForm.action(
                  key: const Key('ReportAddTricksButton'),
                  label: l10n.addTrick,
                  onPressed: () async {
                    await context.push('/rooms/dash/favourites');
                    await controller.load();
                  },
                ),
              ],
            ),
          )
        else
          ...favourites.map(
            (f) => _TrickBlock(
              // Keyed by slug: without it a reorder or reload of favourites
              // would hand one trick's row state to another trick.
              key: ValueKey(f.entrySlug),
              controller: controller,
              favourite: f,
            ),
          ),

        const Divider(height: 36, thickness: 1, color: Nyfa.rule),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            key: const Key('ReportCommentField'),
            controller: controller.commentController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: Nyfa.bodyText,
            cursorColor: Nyfa.green,
            decoration: Nyfa.input(l10n.howDidItGo).copyWith(
              alignLabelWithHint: true,
            ),
          ),
        ),

        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('IncludeNumbersSwitch'),
          value: controller.includeNumbers,
          onChanged: controller.toggleIncludeNumbers,
          activeThumbColor: Nyfa.ground,
          activeTrackColor: Nyfa.green,
          inactiveThumbColor: Nyfa.muted,
          inactiveTrackColor: Nyfa.raised,
          title: Text(
            l10n.includeMyNumbers.toUpperCase(),
            style: Nyfa.heading.copyWith(fontSize: 16),
          ),
          subtitle: Text(l10n.includeMyNumbersBody, style: Nyfa.bodyMuted),
        ),
      ],
    );
  }
}

/// One trick: the ladder, a count, and a first.
class _TrickBlock extends StatelessWidget {
  final ReportController controller;
  final FootbagFavourite favourite;

  const _TrickBlock({
    required this.controller,
    required this.favourite,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entry = controller.entryFor(favourite.entrySlug);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  favourite.name.toUpperCase(),
                  style: Nyfa.heading.copyWith(fontSize: 19),
                ),
              ),
              if (entry?.isFirst ?? false)
                const Icon(Icons.star_rounded, size: 20, color: Nyfa.green),
            ],
          ),
          const SizedBox(height: 12),
          _Ladder(
            selected: entry?.grade,
            onTap: (grade) => controller.setGrade(favourite.entrySlug, grade),
          ),
          const SizedBox(height: 12),
          // Wrap, not Row: at 360px with a large text scale a fixed-width
          // field beside an expanding chip overflows.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 108,
                child: TextField(
                  key: Key('Count_${favourite.entrySlug}'),
                  controller: controller.countControllerFor(favourite.entrySlug),
                  keyboardType: TextInputType.number,
                  // keyboardType is a hint, not a restriction — hardware
                  // keyboards, some IMEs and paste all get past it, and a
                  // half-numeric string used to clear the count silently while
                  // still showing the text.
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Nyfa.bodyText,
                  cursorColor: Nyfa.green,
                  decoration: Nyfa.input(l10n.howMany),
                  onChanged: (raw) =>
                      controller.setCount(favourite.entrySlug, raw),
                ),
              ),
              _FirstToggle(
                key: Key('First_${favourite.entrySlug}'),
                selected: entry?.isFirst ?? false,
                label: l10n.firstTime,
                onTap: () => controller.toggleFirst(favourite.entrySlug),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The four rungs, as one strip.
///
/// Built by hand rather than with SegmentedButton for two reasons. The widget
/// lays its children out at a tight `maxWidth / childCount`, which clips
/// "CONSISTENT" at 360px; and its clear signal is an empty set, which is easy
/// to drop by accident — here tapping the selected rung is plainly a null.
///
/// Bebas condensed caps are what make four labels fit the width at all, so the
/// club's display face is carrying a layout constraint, not just the look.
class _Ladder extends StatelessWidget {
  final FootbagGrade? selected;
  final void Function(FootbagGrade? grade) onTap;

  const _Ladder({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(border: Border.fromBorderSide(
        BorderSide(color: Nyfa.rule),
      )),
      child: Row(
        children: [
          for (final grade in FootbagGrade.values)
            Expanded(
              child: _Rung(
                label: _label(l10n, grade),
                // The rungs are a progression, so everything up to the chosen
                // one reads as attained — the ladder shows how far you got,
                // not which radio button is on.
                reached: selected != null && grade.index <= selected!.index,
                current: selected == grade,
                isLast: grade == FootbagGrade.values.last,
                // Tapping the current rung clears it, so a mis-tap is not
                // permanent for the whole session.
                onTap: () => onTap(selected == grade ? null : grade),
              ),
            ),
        ],
      ),
    );
  }

  String _label(L10n l10n, FootbagGrade grade) => switch (grade) {
    FootbagGrade.tried => l10n.gradeTried,
    FootbagGrade.footing => l10n.gradeFooting,
    FootbagGrade.hitting => l10n.gradeHitting,
    FootbagGrade.consistent => l10n.gradeConsistent,
  };
}

class _Rung extends StatelessWidget {
  final String label;
  final bool reached;
  final bool current;
  final bool isLast;
  final VoidCallback onTap;

  const _Rung({
    required this.label,
    required this.reached,
    required this.current,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48, // A real tap target, and the strip's rhythm.
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: reached
                ? (current ? Nyfa.green : Nyfa.greenDim)
                : Colors.transparent,
            border: isLast
                ? null
                : const Border(right: BorderSide(color: Nyfa.rule)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  fontSize: 15,
                  letterSpacing: 0.6,
                  // Solid colours throughout: the previous version dimmed text
                  // with alpha and failed 4.5:1 on both themes.
                  color: current
                      ? Nyfa.ground
                      : (reached ? Nyfa.paper : Nyfa.muted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstToggle extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _FirstToggle({
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Nyfa.green : Colors.transparent,
          border: Border.all(color: selected ? Nyfa.green : Nyfa.rule),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: selected ? Nyfa.ground : Nyfa.muted,
            ),
            const SizedBox(width: 7),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 16,
                letterSpacing: 0.8,
                color: selected ? Nyfa.ground : Nyfa.paper,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
