// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Which destination a screen is showing.
enum FootbagTab { dash, feed, discover, chat }

/// The app's bottom navigation: Dash · Feed · [+] · Discover · Chat.
///
/// The doc's five items, in the doc's order. Feed sits next to Dash rather
/// than first: the app opens on "is anyone playing?", not on what people
/// posted.
///
/// The centre [+] is raised and green because the doc is explicit that it
/// creates a *session*, not a post: "a tool for getting to a session, with a
/// feed attached — not a content app with meetups bolted on". Making it the
/// loudest thing on the bar is that sentence, expressed as a control. Posting
/// lives in the Feed's own header.
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

    return Container(
      decoration: const BoxDecoration(
        color: Nyfa.ground,
        border: Border(top: BorderSide(color: Nyfa.rule)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _Tab(
                  key: const Key('NavDash'),
                  icon: Icons.sports_handball_outlined,
                  label: l10n.dash,
                  selected: current == FootbagTab.dash,
                  onTap: () => context.go('/rooms/dash'),
                ),
              ),
              Expanded(
                child: _Tab(
                  key: const Key('NavFeed'),
                  icon: Icons.dynamic_feed_outlined,
                  label: l10n.feed,
                  selected: current == FootbagTab.feed,
                  onTap: current == FootbagTab.feed && onReselect != null
                      ? onReselect!
                      : () => context.go('/rooms/feed'),
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
                  label: l10n.discover,
                  selected: current == FootbagTab.discover,
                  onTap: () => context.go('/rooms/discover'),
                ),
              ),
              Expanded(
                child: _Tab(
                  key: const Key('NavChat'),
                  icon: Icons.forum_outlined,
                  label: l10n.chats,
                  selected: current == FootbagTab.chat,
                  onTap: () => context.go('/rooms'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Solid colours, not alpha: muted already clears 4.5:1 on the ground, and
    // dimming paper with opacity does not.
    final colour = selected ? Nyfa.green : Nyfa.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: colour),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 13,
                letterSpacing: 0.9,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The centre action: start a session.
class _StartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _StartButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 58,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? Nyfa.green : Nyfa.rule,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(
              Icons.add,
              size: 26,
              color: enabled ? Nyfa.ground : Nyfa.muted,
            ),
          ),
        ),
      ),
    );
  }
}
