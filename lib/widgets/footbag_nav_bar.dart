// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Which destination a screen is showing.
enum FootbagTab { dash, feed, discover, chat }

/// The app's bottom navigation: Feed · Dash · [+] · Discover · Chat.
///
/// Feed first, because it is home: decided Nov 2026, reversing the earlier
/// "Dash is what you land on". Dash -- your sessions, favourites, rankings --
/// is one tap away beside it.
///
/// Icons only, outline at rest and solid when open, the way Instagram's bar
/// reads: the frame steps back so the screen above it leads. Each tab's name
/// is still there for screen readers. The centre [+] creates a *session*,
/// not a post -- posting has its own control in the Feed header.
class FootbagNavBar extends StatelessWidget {
  final FootbagTab current;

  /// Starting a session is the centre action. On Dash, null disables it —
  /// while one is already running, there is nothing to start. Everywhere
  /// else it takes you to Dash and starts one there, where the running
  /// session is shown; a [+] that only worked on one tab was a [+] that
  /// looked broken on the other three.
  final VoidCallback? onStart;

  /// The current tab, tapped again. The feed scrolls to the top.
  final VoidCallback? onReselect;

  const FootbagNavBar({
    required this.current,
    this.onStart,
    this.onReselect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Its own Material, so the tabs' ink works wherever the bar is placed --
    // under a Scaffold on Dash, or at the bottom of the chat screen's column,
    // where nothing above it provides one.
    return Material(
      color: Nyfa.ground,
      child: Container(
        decoration: const BoxDecoration(
          color: Nyfa.ground,
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: _Tab(
                    key: const Key('NavFeed'),
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: l10n.feed,
                    selected: current == FootbagTab.feed,
                    onTap: current == FootbagTab.feed && onReselect != null
                        ? onReselect!
                        : () => context.go('/rooms/feed'),
                  ),
                ),
                Expanded(
                  child: _Tab(
                    key: const Key('NavDash'),
                    icon: Icons.sports_handball_outlined,
                    activeIcon: Icons.sports_handball,
                    label: l10n.dash,
                    selected: current == FootbagTab.dash,
                    onTap: () => context.go('/rooms/dash'),
                  ),
                ),
                _StartButton(
                  onPressed: current == FootbagTab.dash
                      ? onStart
                      : () => context.go('/rooms/dash', extra: 'start'),
                  label: l10n.startSession,
                ),
                Expanded(
                  child: _Tab(
                    key: const Key('NavDiscover'),
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    label: l10n.discover,
                    selected: current == FootbagTab.discover,
                    onTap: () => context.go('/rooms/discover'),
                  ),
                ),
                Expanded(
                  child: _Tab(
                    key: const Key('NavChat'),
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: l10n.chats,
                    selected: current == FootbagTab.chat,
                    onTap: () => context.go('/rooms'),
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

class _Tab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Center(
        child: Icon(
          selected ? activeIcon : icon,
          size: 27,
          color: selected ? Nyfa.paper : Nyfa.muted,
        ),
      ),
    ),
  );
}

/// The centre action: start a session.
class _StartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _StartButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onPressed,
      radius: 28,
      child: SizedBox(
        width: 64,
        // A play mark, not a +: the feed's + makes a post, and one icon
        // meaning two different things was a trap.
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 30,
          color: onPressed != null ? Nyfa.paper : Nyfa.faint,
        ),
      ),
    ),
  );
}
