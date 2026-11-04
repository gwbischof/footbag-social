// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Footbag Social's look.
///
/// Its own, not the NYFA club theme it started as (decided Nov 2026; see the
/// design doc's "Visual style"). From NYFA it keeps the near-black ground,
/// the lime and Bebas Neue -- the lime for the one primary action and
/// anything live, Bebas for the wordmark and big numbers only. Everything
/// else is quiet: one sans in sentence case, emphasis by weight, neutral
/// greys, small radii, chrome that steps back so photos lead.
///
/// The class keeps its old name: forty files call it, and a rename would be
/// churn with no change a person could see.
class Nyfa {
  const Nyfa._();

  /// The page.
  static const ground = Color(0xFF0A0A0A);

  /// Sheets, inputs, cards and tiles: a lift off the ground. #1C1C1C, up
  /// from #181818, so a card reads as a card -- a design review found the
  /// old step barely visible next to the ground.
  static const raised = Color(0xFF1C1C1C);

  /// The fill of a secondary control -- a chip, a quiet button, an input.
  ///
  /// Fill, not outline: a screen of outlined rectangles is the busiest thing
  /// a dark UI can be, and visual complexity is what most lowers how good a
  /// screen looks at a glance (see best-practices/beautiful-mobile-app-ui).
  /// The control's label carries its contrast; the fill only says "tap me".
  static const tonal = Color(0xFF2A2A2A);

  /// The one outline that must read as an edge: an input's underline, a
  /// focus ring. 3.3:1 on [ground], clearing WCAG 1.4.11's 3:1 for controls.
  static const edge = Color(0xFF5E5E5E);

  /// Primary text. ~18:1 on [ground].
  static const paper = Color(0xFFF5F5F5);

  /// Secondary text people actually read: captions, metadata, explanations.
  ///
  /// APCA Lc ~58 on [ground] -- reading text, not placeholder grey. WCAG 2
  /// overstates light-on-dark contrast, so a grey that merely passes it can
  /// still be too dim to read.
  static const muted = Color(0xFFABABAB);

  /// Text nobody needs to read closely: timestamps, placeholders, disabled
  /// labels. Lc 40 -- above APCA's floor of 30 for any text, and no more.
  static const faint = Color(0xFF8C8C8C);

  /// The lime, kept from the club. The primary action, the clock, the
  /// active rung, live state -- and nothing decorative.
  static const green = Color(0xFFB0F42F);

  /// A rung already attained, below the current one.
  ///
  /// A solid colour, not green at low alpha. The first attempt used 18% green,
  /// which gives perfectly readable text but only **1.68:1** against the
  /// ground — so the fill that was supposed to show how far up the ladder you
  /// got was invisible. This is 3.11:1 against [ground] (clears the 3:1 for a
  /// non-text UI state) and 5.34:1 under [paper].
  static const greenDim = Color(0xFF4C6819);

  /// Hairlines between rows.
  static const rule = Color(0xFF232323);

  /// Corner radii: controls, then sheets and media in a card. Small, so the
  /// shapes read as soft rather than as bubbles.
  static const radius = 8.0;
  static const radiusLarge = 12.0;
  static const rounded = BorderRadius.all(Radius.circular(radius));
  static const roundedLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );

  /// A bottom sheet: rounded where it meets the screen, square at the edge.
  static const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
  );

  static const dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
  );

  /// Avatar tones for people without a photo: olive, rust, slate, plum, teal
  /// and ochre. Muted, so none competes with [green];
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

  /// Bebas Neue: the wordmark and big numbers. Never a label.
  static const display = 'BebasNeue';
  static const body = 'DMSans';

  /// A screen's own title, where it has one in the page rather than the bar.
  static const title = TextStyle(
    fontFamily: body,
    color: paper,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Headings: a section, a row's name, a sheet's title.
  static const heading = TextStyle(
    fontFamily: body,
    color: paper,
    fontSize: 17,
    // w600, not w700: with every name and label in bold the app read as
    // large print. Bold is kept for titles.
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
  );

  /// The name on a list row: a person, a session, a trick. 15 semibold, the
  /// size dense social apps use, so a list reads as a list and not a stack
  /// of headings.
  static const rowTitle = TextStyle(
    fontFamily: body,
    color: paper,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Small labels: a count, a state, a tag. Sentence case and weight, not
  /// tracked capitals -- caps on every label is what made the old look shout.
  static const eyebrow = TextStyle(
    fontFamily: body,
    color: muted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// A control's label: buttons, chips, tabs.
  static const label = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
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

  /// The second line of a list row: who, where, how many. 13, not the 12
  /// these rows were each setting by hand -- below 13 the muted grey stops
  /// being readable at arm's length.
  static const meta = TextStyle(
    fontFamily: body,
    color: muted,
    fontSize: 13,
    height: 1.35,
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
        shape: controlShape,
        textStyle: label,
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

  /// A filled, rounded field with no outline at rest and a grey ring while
  /// typing -- the field is findable by its fill, and the lime stays for
  /// the action the field leads to.
  static InputDecoration input(String text) => InputDecoration(
    labelText: text,
    labelStyle: const TextStyle(fontFamily: body, color: muted, fontSize: 14),
    // Green only while typing, with the underline -- a filled field at
    // rest keeps its label muted, or every answered field looks focused.
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) => TextStyle(
        fontFamily: body,
        color: states.contains(WidgetState.focused) ? paper : muted,
      ),
    ),
    hintStyle: const TextStyle(fontFamily: body, color: faint),
    filled: true,
    fillColor: raised,
    contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    // Underline borders, not outline: an outline floats the label up onto
    // the border's line, and with no visible border that left the label
    // straddling the edge of the fill like a rendering fault. Underline
    // floats it inside the field, where it reads as a caption.
    enabledBorder: const UnderlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      borderSide: BorderSide.none,
    ),
    focusedBorder: const UnderlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      borderSide: BorderSide(color: edge, width: 1.5),
    ),
    border: const UnderlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      borderSide: BorderSide.none,
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
        Text(title, style: heading.copyWith(fontSize: 18)),
        // The subtitle exists because you arrive at a report from a list of
        // near-identical rows and need to know which session you are filling in.
        if (subtitle != null) Text(subtitle, style: meta),
      ],
    ),
    actions: actions,
  );
}

/// Form furniture shared by every club-themed screen.
///
/// Extracted the moment a second screen needed a switch: four screens each
/// styling their own switch is how the set stops looking like one system.
class NyfaForm {
  const NyfaForm._();

  /// A section heading.
  static Widget section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
    child: Text(label, style: Nyfa.heading.copyWith(fontSize: 16)),
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
            child: Text(helper, style: Nyfa.meta),
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
    String? explain,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    key: key,
    value: value,
    onChanged: onChanged,
    activeThumbColor: Nyfa.ground,
    activeTrackColor: Nyfa.green,
    inactiveThumbColor: Nyfa.muted,
    inactiveTrackColor: Nyfa.tonal,
    // No outline on the off track: one switch look across the app.
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    title: Text(
      label,
      style: Nyfa.bodyText.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: explain == null ? null : Text(explain, style: Nyfa.meta),
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
    child: FilledButton(
      key: key,
      onPressed: onPressed,
      style: filled
          ? FilledButton.styleFrom(
              backgroundColor: Nyfa.green,
              foregroundColor: Nyfa.ground,
              disabledBackgroundColor: Nyfa.tonal,
              disabledForegroundColor: Nyfa.muted,
              shape: Nyfa.controlShape,
              textStyle: Nyfa.label,
              elevation: 0,
            )
          : Nyfa.quietButton(),
      child: Text(label),
    ),
  );
}

/// A selectable chip: a filter, an option, a tab. One widget for every chip
/// in the app -- there were five, each styled by hand.
///
/// Unselected is a tonal fill with no outline; selected is solid paper with
/// ground type (APCA Lc 94). Not green: a form has three or four chip groups,
/// and a green selection in each spent the accent four times on a screen
/// whose one green thing should be the action. 36 to see, 48 to hit.
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
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? Nyfa.paper : Nyfa.tonal,
            borderRadius: const BorderRadius.all(Radius.circular(Nyfa.radius)),
          ),
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
                  label,
                  style: Nyfa.label.copyWith(fontSize: 14, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
