// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

/// The club's look, as newyorkfootbag.com sets it.
///
/// Near-black ground, warm paper type, the club green, Bebas Neue in caps.
/// Lives here rather than privately in each page because it is now used by the
/// intro screen and the session screens, and a palette copied three times is a
/// palette that drifts.
///
/// Deliberately not derived from [ThemeData]: the rest of the app is Material 3
/// seeded from a different green, and these screens are the club's own surface.
/// Reading the M3 scheme here would mean half-inheriting a palette this does
/// not want.
class Nyfa {
  const Nyfa._();

  /// The page.
  static const ground = Color(0xFF0A0A0A);

  /// Rows and cards: a lift off the ground rather than a grey.
  ///
  /// Warm-shifted, because [paper] and [muted] both are — a neutral mixed from
  /// pure grey against a warm type colour reads as an accident.
  static const raised = Color(0xFF14130F);

  /// Primary text. ~15:1 on [ground].
  static const paper = Color(0xFFEDEBE7);

  /// Secondary text. ~5.6:1 on [ground], so it clears 4.5:1 as a solid colour —
  /// which is why nothing here dims text with alpha instead.
  static const muted = Color(0xFF89867F);

  /// The club green. The clock, the active rung, the primary action.
  static const green = Color(0xFFB0F42F);

  /// A rung already attained, below the current one.
  ///
  /// A solid colour, not green at low alpha. The first attempt used 18% green,
  /// which gives perfectly readable text but only **1.68:1** against the
  /// ground — so the fill that was supposed to show how far up the ladder you
  /// got was invisible. This is 3.11:1 against [ground] (clears the 3:1 for a
  /// non-text UI state) and 5.34:1 under [paper].
  static const greenDim = Color(0xFF4C6819);

  /// Hairlines. The structural device this look uses instead of cards.
  static const rule = Color(0xFF26251F);

  static const display = 'BebasNeue';
  static const body = 'DMSans';

  /// Section headings and anything set like a scoreboard label.
  static const heading = TextStyle(
    fontFamily: display,
    color: paper,
    fontSize: 20,
    letterSpacing: 1.2,
    height: 1.1,
  );

  /// Small caps labels above a group.
  static const eyebrow = TextStyle(
    fontFamily: display,
    color: muted,
    fontSize: 14,
    letterSpacing: 1.6,
  );

  static const bodyText = TextStyle(
    fontFamily: body,
    color: paper,
    fontSize: 14,
    height: 1.45,
  );

  static const bodyMuted = TextStyle(
    fontFamily: body,
    color: muted,
    fontSize: 13,
    height: 1.45,
  );

  /// The scoreboard clock.
  ///
  /// Tabular figures so the digits do not shift as the seconds change, which on
  /// a one-second repaint is the difference between a clock and a twitch.
  static const clock = TextStyle(
    fontFamily: display,
    color: green,
    fontSize: 64,
    height: 0.92,
    letterSpacing: 2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// An input's text and its label, in the body face.
  static InputDecoration input(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontFamily: body, color: muted, fontSize: 13),
    floatingLabelStyle: const TextStyle(fontFamily: body, color: green),
    isDense: true,
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: rule),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: green),
    ),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: rule),
    ),
  );

  /// The app bar these screens share.
  static AppBar appBar({
    required String title,
    String? subtitle,
    List<Widget>? actions,
  }) => AppBar(
    backgroundColor: ground,
    surfaceTintColor: ground,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: paper),
    leading: const Center(child: BackButton(color: paper)),
    // AppBar centres its title on web, which left these screens disagreeing
    // with Dash's left-aligned wordmark.
    centerTitle: false,
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title.toUpperCase(), style: heading),
        // The subtitle exists because you arrive at a report from a list of
        // near-identical rows and need to know which session you are filling in.
        if (subtitle != null)
          Text(subtitle, style: bodyMuted.copyWith(fontSize: 12)),
      ],
    ),
    actions: actions,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, thickness: 1, color: rule),
    ),
  );
}

/// Form furniture shared by every club-themed screen.
///
/// Extracted the moment a second screen needed a switch: four screens each
/// styling their own switch is how the set stops looking like one system.
class NyfaForm {
  const NyfaForm._();

  /// A section heading with a hairline above it.
  static Widget section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
    child: Text(label.toUpperCase(), style: Nyfa.eyebrow),
  );

  /// A labelled text field.
  static Widget field({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? helper,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalization = TextCapitalization.sentences,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: key,
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: capitalization,
          onChanged: onChanged,
          style: Nyfa.bodyText,
          cursorColor: Nyfa.green,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          decoration: Nyfa.input(label).copyWith(alignLabelWithHint: true),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(helper, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
          ),
      ],
    ),
  );

  /// A switch row. The explanation is not optional: every switch in this app
  /// governs something a person would reasonably want explained before
  /// flipping it.
  static Widget toggle({
    Key? key,
    required String label,
    required String explain,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    key: key,
    value: value,
    onChanged: onChanged,
    activeThumbColor: Nyfa.ground,
    activeTrackColor: Nyfa.green,
    inactiveThumbColor: Nyfa.muted,
    inactiveTrackColor: Nyfa.raised,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    title: Text(label.toUpperCase(), style: Nyfa.heading.copyWith(fontSize: 16)),
    subtitle: Text(explain, style: Nyfa.bodyMuted),
  );

  /// A row of selectable chips. Wraps, so a long set never clips at 360px.
  static Widget chips({
    required List<({String value, String label})> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
    String keyPrefix = 'Chip',
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          _Chip(
            key: Key('$keyPrefix${o.value}'),
            label: o.label,
            selected: selected.contains(o.value),
            onTap: () => onToggle(o.value),
          ),
      ],
    ),
  );

  /// The one primary action a screen has.
  static Widget action({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    bool filled = true,
  }) => SizedBox(
    height: 48,
    child: filled
        ? FilledButton(
            key: key,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Nyfa.green,
              disabledBackgroundColor: Nyfa.rule,
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 17,
                letterSpacing: 1.1,
                color: onPressed == null ? Nyfa.muted : Nyfa.ground,
              ),
            ),
          )
        : OutlinedButton(
            key: key,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Nyfa.rule),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 17,
                letterSpacing: 1.1,
                color: Nyfa.paper,
              ),
            ),
          ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      // No `alignment` here, deliberately. A Container with alignment set and
      // no explicit width expands to fill its constraints -- inside a Wrap that
      // made every chip full width and stacked them one per row, which looked
      // like a broken list rather than a set of options. Centring comes from
      // the symmetric padding instead.
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Nyfa.green : Colors.transparent,
          border: Border.all(color: selected ? Nyfa.green : Nyfa.rule),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: Nyfa.display,
              fontSize: 16,
              letterSpacing: 0.8,
              // Solid either way: dimming paper with alpha was what failed
              // contrast the first time round.
              color: selected ? Nyfa.ground : Nyfa.paper,
            ),
          ),
        ),
      ),
    ),
  );
}
