// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The first run: who you are, before the feed.
///
/// The doc expected this to be needed -- Apple sign-in can withhold a name,
/// so a new player may arrive as nothing better than their handle. Four
/// questions, all optional but the name, and Skip is always there: a welcome
/// that blocks the app is a form, not a welcome. Finishing or skipping both
/// mark it done, on the server, so it is shown once per account.
class WelcomePage extends StatefulWidget {
  final FootbagPlayer me;

  const WelcomePage({required this.me, super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final name = TextEditingController(text: widget.me.displayName);
  late final city = TextEditingController(text: widget.me.city ?? '');
  late final Set<String> styles = {...widget.me.playStyles};
  late bool discoverable = widget.me.discoverable;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool save}) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    setState(() => saving = true);
    try {
      final client = Matrix.of(context).client;
      await (save
          ? client.updateMe(
              displayName: name.text.trim(),
              city: city.text.trim(),
              playStyles: styles.toList(),
              discoverable: discoverable,
              onboarded: true,
            )
          : client.updateMe(onboarded: true));
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/rooms/feed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FootbagApiException ? e.detail : l10n.oopsSomethingWentWrong,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      key: const Key('WelcomeScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: AppBar(
        backgroundColor: Nyfa.ground,
        surfaceTintColor: Nyfa.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('WelcomeSkip'),
            onPressed: saving ? null : () => _finish(save: false),
            child: Text(
              l10n.skip.toUpperCase(),
              style: const TextStyle(
                fontFamily: Nyfa.display,
                fontSize: 17,
                letterSpacing: 1,
                color: Nyfa.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: NyfaForm.action(
            key: const Key('WelcomeContinue'),
            label: l10n.welcomeContinue,
            onPressed: name.text.trim().isEmpty || saving
                ? null
                : () => _finish(save: true),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Text(
                  l10n.welcomeTitle.toUpperCase(),
                  style: Nyfa.clock.copyWith(color: Nyfa.paper, fontSize: 56),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(l10n.welcomeBody, style: Nyfa.bodyMuted),
              ),
              NyfaForm.field(
                key: const Key('WelcomeName'),
                controller: name,
                label: l10n.displayName,
                helper: l10n.displayNameHelp,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              NyfaForm.section(l10n.playStyles),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(l10n.playStylesHelp, style: Nyfa.bodyMuted),
              ),
              NyfaForm.chips(
                keyPrefix: 'WelcomeStyle',
                options: [
                  (value: 'kicking', label: l10n.sessionTypeKicking),
                  (value: 'freestyle', label: l10n.sessionTypeFreestyle),
                  (value: 'net', label: l10n.sessionTypeNet),
                  (value: 'stitching', label: l10n.sessionTypeStitching),
                ],
                selected: styles,
                onToggle: (v) => setState(
                  () => styles.contains(v) ? styles.remove(v) : styles.add(v),
                ),
              ),
              const SizedBox(height: 20),
              NyfaForm.field(
                key: const Key('WelcomeCity'),
                controller: city,
                label: l10n.city,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              NyfaForm.toggle(
                key: const Key('WelcomeDiscoverable'),
                label: l10n.discoverable,
                explain: l10n.discoverableExplain,
                value: discoverable,
                onChanged: (v) => setState(() => discoverable = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
