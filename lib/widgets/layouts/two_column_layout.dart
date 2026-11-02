// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/themes.dart';
import 'package:material_ui/material_ui.dart';

class TwoColumnLayout extends StatelessWidget {
  final Widget mainView;
  final Widget sideView;
  final bool hasNavigationRail;

  /// Spans both columns. The app's nav bar goes here on wide screens, so it
  /// sits along the bottom of the window as it does on every other page,
  /// rather than under the chat list's column alone.
  final Widget? bottomBar;

  const TwoColumnLayout({
    super.key,
    required this.mainView,
    required this.sideView,
    this.hasNavigationRail = true,
    this.bottomBar,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaffoldMessenger(
      child: Scaffold(
        bottomNavigationBar: bottomBar,
        body: Row(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              width:
                  AppThemes.columnWidth +
                  (hasNavigationRail ? AppThemes.navRailWidth : 0),
              child: mainView,
            ),
            Container(width: 1.0, color: theme.dividerColor),
            Expanded(child: ClipRRect(child: sideView)),
          ],
        ),
      ),
    );
  }
}
