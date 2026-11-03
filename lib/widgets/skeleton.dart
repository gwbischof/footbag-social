// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The colour a placeholder shape is drawn in, pulsing slowly between two
/// solid tokens -- held still under Reduce Motion.
///
/// Every loading shape in the app shares this one pulse, so a screen half
/// made of placeholders breathes as one thing rather than several.
class SkeletonPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color color) builder;

  const SkeletonPulse({required this.builder, super.key});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.builder(context, Nyfa.raised);
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => widget.builder(
        context,
        // Between raised and rule: both solid tokens, nothing dimmed with
        // alpha.
        Color.lerp(Nyfa.raised, Nyfa.rule, _pulse.value)!,
      ),
    );
  }
}

/// A list's rows, before the list arrives.
///
/// Laid out like the app's real rows -- a rule above, 20 in from the edge,
/// a name over a line of detail -- so the content lands in place instead of
/// replacing a spinner in the middle of an empty screen.
class RowsSkeleton extends StatelessWidget {
  final int rows;

  /// A circle before each row, for lists of people.
  final bool avatar;

  /// A heading bar above the rows, for a page that opens with a title.
  final bool header;

  const RowsSkeleton({
    this.rows = 6,
    this.avatar = false,
    this.header = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    builder: (context, c) {
      Widget bar(double w, double h) =>
          Container(width: w, height: h, color: c);
      return Semantics(
        label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(180, 22),
                    const SizedBox(height: 12),
                    bar(240, 12),
                  ],
                ),
              ),
            for (var i = 0; i < rows; i++)
              Container(
                constraints: const BoxConstraints(minHeight: 68),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Nyfa.rule)),
                ),
                child: Row(
                  children: [
                    if (avatar) ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Varied widths, so it reads as text, not a grid.
                        bar(const [140.0, 110.0, 160.0][i % 3], 13),
                        const SizedBox(height: 8),
                        bar(const [200.0, 170.0, 120.0][i % 3], 10),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
