// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A throwaway harness for LOOKING at the new screens.
//
// Not shipped and not imported by the app: `flutter run -t lib/preview/...`
// only. It exists because twice in this feature a screen was declared working
// on the strength of "it compiles", and both times it was wrong -- once a
// widget was mounted at zero width, once it was never on screen at all.

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: const _PreviewScaffold(),
  );
}

/// Dash's chrome with stubbed content: the parts that are pure layout.
class _PreviewScaffold extends StatelessWidget {
  const _PreviewScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      backgroundColor: Nyfa.ground,
      appBar: AppBar(
        backgroundColor: Nyfa.ground,
        surfaceTintColor: Nyfa.ground,
        elevation: 0,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FOOTBAG SOCIAL',
              style: TextStyle(
                fontFamily: Nyfa.display,
                color: Nyfa.paper,
                fontSize: 24,
                letterSpacing: 1.6,
                height: 1.05,
              ),
            ),
            Text(l10n.dashGreeting, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Nyfa.raised,
              child: const Text(
                'G',
                style: TextStyle(
                  fontFamily: Nyfa.display,
                  color: Nyfa.green,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Nyfa.rule),
        ),
      ),
      bottomNavigationBar: const FootbagNavBar(current: FootbagTab.dash),
      body: ListView(
        children: [
          // The running scoreboard.
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            decoration: const BoxDecoration(
              color: Nyfa.raised,
              border: Border(left: BorderSide(color: Nyfa.green, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(17, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Nyfa.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.sessionRunning.toUpperCase(), style: Nyfa.eyebrow),
                  ],
                ),
                const SizedBox(height: 10),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('00:47:12', style: Nyfa.clock),
                ),
                const SizedBox(height: 6),
                Text('Freestyle · Sat 25 Oct', style: Nyfa.bodyMuted),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: Nyfa.green,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          l10n.checkInDueIn(6).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Nyfa.display,
                            fontSize: 17,
                            letterSpacing: 1.1,
                            color: Nyfa.ground,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Nyfa.rule),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          l10n.stopSession.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Nyfa.display,
                            fontSize: 17,
                            letterSpacing: 1.1,
                            color: Nyfa.paper,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(l10n.checkInExplainer, style: Nyfa.bodyMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
            child: Text(l10n.yourSessions.toUpperCase(), style: Nyfa.eyebrow),
          ),
          for (final row in [
            ('Freestyle · Fri 24 Oct', 'Freestyle  ·  18:30', '47 MIN'),
            ('Kicking · Wed 22 Oct', 'Kicking  ·  12:05', '1H 12M'),
          ])
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Nyfa.rule)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1.toUpperCase(),
                            style: Nyfa.heading.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 3),
                          Text(row.$2, style: Nyfa.bodyMuted.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      row.$3,
                      style: const TextStyle(
                        fontFamily: Nyfa.display,
                        color: Nyfa.paper,
                        fontSize: 19,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Nyfa.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
