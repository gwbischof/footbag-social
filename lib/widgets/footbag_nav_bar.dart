// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Which destination a screen is showing.
enum FootbagTab { dash, discover, chat }

/// The app's bottom navigation.
///
/// **Four items, not the wireframe's five.** The doc's order is
/// Dash · Feed · [+] · Discover · Chat. Feed does not exist yet and is left
/// out rather than shown as a tab that leads nowhere — a dead tab reads as
/// broken, an absent one as unbuilt. Discover took its documented slot the
/// moment it became real, which is the pattern Feed will follow.
///
/// The centre [+] is raised and green because the doc is explicit that it
/// creates a *session*, not a post: "a tool for getting to a session, with a
/// feed attached — not a content app with meetups bolted on". Making it the
/// loudest thing on the bar is that sentence, expressed as a control.
class FootbagNavBar extends StatelessWidget {
  final FootbagTab current;

  /// Starting a session is the centre action. Null disables it — while one is
  /// already running, there is nothing to start.
  final VoidCallback? onStart;

  const FootbagNavBar({required this.current, this.onStart, super.key});

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
              _StartButton(onPressed: onStart, label: l10n.startSession),
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
