// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
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
  /// pure grey against a warm type colour reads as an accident. 1.15:1 off
  /// the ground: the old 1.07:1 was a step nobody could see, so a raised row
  /// read as nothing.
  static const raised = Color(0xFF1C1B17);

  /// The fill of a secondary control -- a chip, a quiet button, an input.
  ///
  /// Fill, not outline: a screen of outlined rectangles is the busiest thing
  /// a dark UI can be, and visual complexity is what most lowers how good a
  /// screen looks at a glance (see best-practices/beautiful-mobile-app-ui).
  /// The control's label carries its contrast; the fill only says "tap me".
  static const tonal = Color(0xFF2A2923);

  /// The one outline that must read as an edge: an input's underline, a
  /// focus ring. 3.3:1 on [ground], clearing WCAG 1.4.11's 3:1 for controls.
  static const edge = Color(0xFF66645C);

  /// Primary text. ~15:1 on [ground].
  static const paper = Color(0xFFEDEBE7);

  /// Secondary text people actually read: captions, metadata, explanations.
  ///
  /// APCA Lc 58 on [ground]. The old #89867F passed WCAG 2 at 5.45:1 but is
  /// only Lc 38 -- WCAG 2 overstates light-on-dark contrast, and Lc 38 is
  /// placeholder territory, not reading text.
  static const muted = Color(0xFFB2AEA5);

  /// Text nobody needs to read closely: timestamps, placeholders, disabled
  /// labels. Lc 40 -- above APCA's floor of 30 for any text, and no more.
  static const faint = Color(0xFF8F8C84);

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

  /// Avatar tones for people without a photo: the club olive, then rust,
  /// slate, plum, teal and ochre. Muted, so none competes with [green];
  /// dark, so a [paper] letter on any of them is APCA Lc 74 or better.
  /// One flat colour for everyone made a feed of five people read as one.
  static const _tones = [
    Color(0xFF4C6819),
    Color(0xFF5C3424),
    Color(0xFF2B4257),
    Color(0xFF4B2F52),
    Color(0xFF235049),
    Color(0xFF5E4B1E),
  ];

  /// The same person always gets the same tone, on every device.
  static Color toneFor(String id) {
    var h = 0;
    for (final unit in id.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return _tones[h % _tones.length];
  }

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

  /// Reading text. 15, up from 14: bigger reads measurably better and the
  /// platforms sit at 16-17, but this is also row and caption text in a
  /// dense feed, where 16 would crowd.
  static const bodyText = TextStyle(
    fontFamily: body,
    color: paper,
    fontSize: 15,
    height: 1.45,
  );

  static const bodyMuted = TextStyle(
    fontFamily: body,
    color: muted,
    fontSize: 14,
    height: 1.45,
  );

  /// Timestamps and asides.
  static const bodyFaint = TextStyle(
    fontFamily: body,
    color: faint,
    fontSize: 13,
    height: 1.4,
  );

  /// A quiet button: tonal fill, paper label, no outline. The style every
  /// secondary action shares, so they cannot drift apart again.
  static ButtonStyle quietButton({bool accent = false}) =>
      FilledButton.styleFrom(
        backgroundColor: tonal,
        foregroundColor: accent ? green : paper,
        disabledBackgroundColor: raised,
        disabledForegroundColor: faint,
        shape: const RoundedRectangleBorder(),
        elevation: 0,
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
  ///
  /// A filled field with an underline rather than a box: one edge, at a
  /// contrast that reads as an edge, instead of four at one that does not.
  static InputDecoration input(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontFamily: body, color: muted, fontSize: 14),
    floatingLabelStyle: const TextStyle(fontFamily: body, color: green),
    hintStyle: const TextStyle(fontFamily: body, color: faint),
    isDense: true,
    filled: true,
    fillColor: raised,
    contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    enabledBorder: const UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: edge),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: green, width: 2),
    ),
    border: const UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: edge),
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
    title: Text(
      label.toUpperCase(),
      style: Nyfa.heading.copyWith(fontSize: 16),
    ),
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
      children: [
        for (final o in options)
          NyfaChip(
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
              disabledBackgroundColor: Nyfa.tonal,
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
        : FilledButton(
            key: key,
            onPressed: onPressed,
            style: Nyfa.quietButton(),
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

/// A selectable chip: a filter, an option, a tab. One widget for every chip
/// in the app -- there were five, each styled by hand.
///
/// Unselected is a tonal fill with no outline; selected is solid paper with
/// ground type (APCA Lc 94). Not green: a form has three or four chip groups,
/// and a green selection in each spent the accent four times on a screen
/// whose one green thing should be the action. 40 to see, 48 to hit.
class NyfaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const NyfaChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Nyfa.ground
        : (onTap == null ? Nyfa.faint : Nyfa.paper);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        // No `alignment` here, deliberately. A Container with alignment set
        // and no explicit width expands to fill its constraints -- inside a
        // Wrap that made every chip full width. Centring comes from padding.
        child: AnimatedContainer(
          duration: Durations.short3,
          curve: Easing.standard,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: selected ? Nyfa.paper : Nyfa.tonal,
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: Nyfa.display,
                    fontSize: 16,
                    letterSpacing: 0.8,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
