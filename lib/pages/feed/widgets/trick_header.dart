// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The top of a trick's page: what it is, where it sits, and your record
/// with it -- above its clips, which are the rest of the page.
///
/// Where it sits runs both ways along the base chain: what it is built on
/// is what to learn first, what builds on it is where it leads. So the page
/// answers "what now?" as well as "what is this?".
class TrickHeader extends StatefulWidget {
  final String slug;

  /// Preview seam: a canned trick, with no server. Null in the app.
  static FootbagTrickDetail? preview;

  const TrickHeader({required this.slug, super.key});

  @override
  State<TrickHeader> createState() => _TrickHeaderState();
}

class _TrickHeaderState extends State<TrickHeader> {
  FootbagTrickDetail? detail;
  bool? favourite;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final canned = TrickHeader.preview;
    if (canned != null) {
      detail = canned;
      favourite = canned.favourite;
    } else {
      unawaited(_load());
    }
  }

  Client get _client => Matrix.of(context).client;

  Future<void> _load() async {
    try {
      final d = await _client.fetchTrickDetail(widget.slug);
      if (!mounted) return;
      setState(() {
        detail = d;
        favourite = d.favourite;
      });
    } catch (e) {
      // The clips below still work; a page without its header is better
      // than an error in place of both.
      Logs().w('Loading a trick page failed', e);
    }
  }

  Future<void> _toggleFavourite() async {
    final on = !(favourite ?? false);
    setState(() {
      favourite = on;
      saving = true;
    });
    try {
      if (TrickHeader.preview == null) {
        final slugs = [
          for (final f in await _client.fetchFavourites()) f.entrySlug,
        ];
        await _client.setFavourites(
          on
              ? [...slugs, widget.slug]
              : slugs.where((s) => s != widget.slug).toList(),
        );
      }
    } catch (e) {
      Logs().w('Changing a favourite failed', e);
      if (mounted) setState(() => favourite = !on);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _grade(L10n l10n, FootbagGrade g) => switch (g) {
    FootbagGrade.tried => l10n.gradeTried,
    FootbagGrade.footing => l10n.gradeFooting,
    FootbagGrade.hitting => l10n.gradeHitting,
    FootbagGrade.consistent => l10n.gradeConsistent,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final d = detail;
    if (d == null) return const SizedBox(height: 8);
    final e = d.entry;

    Widget links(String title, List<({String slug, String name})> refs) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NyfaForm.section(title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in refs)
                    InkWell(
                      key: Key('TrickLink_${r.slug}'),
                      onTap: () => context.push(
                        '/rooms/feed/trick/${r.slug}',
                        extra: r.name,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: Nyfa.tonal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(r.name, style: Nyfa.bodyText),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Nyfa.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

    final record = !d.reported
        ? l10n.notInYourReports
        : [
            if (d.bestGrade != null) _grade(l10n, d.bestGrade!),
            l10n.hitInSessions(d.hitSessions),
          ].join('  ·  ');

    return Column(
      key: const Key('TrickHeader'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.adds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final add in e.adds)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        color: Nyfa.raised,
                        child: Text(
                          add.toUpperCase(),
                          style: Nyfa.eyebrow.copyWith(color: Nyfa.paper),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        l10n.addsCount(e.adds.length),
                        style: Nyfa.bodyMuted.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              if (e.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(e.description, style: Nyfa.bodyText),
              ],
              if (e.aka.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(l10n.alsoCalled(e.aka.join(', ')), style: Nyfa.bodyMuted),
              ],
            ],
          ),
        ),
        NyfaForm.section(l10n.you),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: Text(record, style: Nyfa.bodyText)),
              SmallButton(
                key: const Key('TrickFavourite'),
                label: (favourite ?? false)
                    ? l10n.favourited
                    : l10n.addToFavourites,
                accent: !(favourite ?? false),
                onPressed: saving ? null : _toggleFavourite,
              ),
            ],
          ),
        ),
        if (d.steps.isNotEmpty) links(l10n.trickSteps, d.steps),
        if (d.builtOn.isNotEmpty) links(l10n.builtOn, d.builtOn),
        if (d.buildsInto.isNotEmpty) links(l10n.buildsInto, d.buildsInto),
        NyfaForm.section(l10n.clips),
      ],
    );
  }
}
