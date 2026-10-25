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
