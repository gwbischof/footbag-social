// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

typedef _Part = ({String slug, String name});

/// Suggest a trick, composite or string for the dictionary.
///
/// Yours to use the moment it is saved; everyone's once a moderator approves
/// it. No breakdown is asked for: adds are the vocabulary's owner's to
/// write, and a composite's cannot be summed from its parts. Pops with the
/// new entry, so whatever opened this can select it.
class SuggestTrick extends StatefulWidget {
  /// What was typed into the search that came up empty.
  final String initialName;

  const SuggestTrick({this.initialName = '', super.key});

  @override
  State<SuggestTrick> createState() => _SuggestTrickState();
}

class _SuggestTrickState extends State<SuggestTrick> {
  late final name = TextEditingController(text: widget.initialName);
  final description = TextEditingController();
  final aka = TextEditingController();
  String kind = 'trick';
  _Part? base;
  List<_Part> modifiers = [];
  List<_Part> steps = [];
  bool saving = false;

  /// The name this screen last filled in itself, so it can keep a
  /// composite's name in step with its parts until the player types one.
  String? _autoName;

  Client get _client => Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    aka.dispose();
    super.dispose();
  }

  bool get ready =>
      !saving &&
      name.text.trim().isNotEmpty &&
      switch (kind) {
        'composite' => base != null,
        'string' => steps.length >= 2,
        _ => true,
      };

  /// Pick from the dictionary, through the same picker as favourites.
  Future<List<_Part>> _pick(Set<String> already) async {
    final slugs = await context.push<List<String>>(
      '/rooms/dash/favourites/add',
      extra: already,
    );
    if (slugs == null || slugs.isEmpty) return const [];
    final entries = await Future.wait(slugs.map(_client.fetchEntry));
    return [for (final e in entries) (slug: e.slug, name: e.name)];
  }

  void _nameComposite() {
    final b = base;
    if (b == null) return;
    final suggested = [...modifiers.map((m) => m.name), b.name].join(' ');
    if (name.text.trim().isEmpty || name.text == _autoName) {
      name.text = suggested;
      _autoName = suggested;
    }
  }

  Future<void> pickBase() async {
    final picked = await _pick({?base?.slug});
    if (picked.isEmpty || !mounted) return;
    setState(() {
      base = picked.first;
      _nameComposite();
    });
  }

  Future<void> addModifiers() async {
    final picked = await _pick({...modifiers.map((m) => m.slug)});
    if (!mounted) return;
    setState(() {
      modifiers = [...modifiers, ...picked].take(4).toList();
      _nameComposite();
    });
  }

  Future<void> addSteps() async {
    // A string may repeat a trick, so nothing is greyed out as added.
    final picked = await _pick(const {});
    if (!mounted) return;
    setState(() => steps = [...steps, ...picked].take(20).toList());
  }

  Future<void> save() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => saving = true);
    try {
      final entry = await _client.suggestEntry(
        name: name.text.trim(),
        kind: kind,
        description: description.text.trim(),
        aka: [
          for (final a in aka.text.split(','))
            if (a.trim().isNotEmpty) a.trim(),
        ],
        base: kind == 'composite' ? base?.slug : null,
        modifiers: kind == 'composite'
            ? [for (final m in modifiers) m.slug]
            : const [],
        steps: kind == 'string' ? [for (final s in steps) s.slug] : const [],
      );
      router.pop(entry);
    } on FootbagApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Already there: hand back the existing one rather than a dead end.
        final existing = await _client.fetchEntry(e.detail);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.alreadyInDictionary(existing.name))),
        );
        router.pop(existing);
        return;
      }
      setState(() => saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.detail)));
    } catch (e) {
      Logs().w('Suggesting a trick failed', e);
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
    }
  }

  Widget _parts(
    List<_Part> parts, {
    required bool numbered,
    required ValueChanged<int> onRemove,
  }) => Column(
    children: [
      for (final (i, p) in parts.indexed)
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(left: 20, right: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Nyfa.rule)),
          ),
          child: Row(
            children: [
              if (numbered)
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}', style: Nyfa.eyebrow),
                ),
              Expanded(child: Text(p.name, style: Nyfa.bodyText)),
              IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => onRemove(i),
                icon: const Icon(Icons.close, size: 18, color: Nyfa.muted),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _addRow(Key key, String label, VoidCallback onTap) => InkWell(
    key: key,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Nyfa.rule),
          bottom: BorderSide(color: Nyfa.rule),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.add, size: 18, color: Nyfa.green),
          const SizedBox(width: 10),
          Text(label, style: Nyfa.bodyText.copyWith(color: Nyfa.green)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      key: const Key('SuggestTrickScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.suggestATrick),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: NyfaForm.action(
              key: const Key('SuggestTrickSave'),
              label: l10n.suggestTrickSave,
              onPressed: ready ? save : null,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(top: 20, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(l10n.suggestTrickExplain, style: Nyfa.bodyMuted),
              ),
              NyfaForm.field(
                key: const Key('SuggestTrickName'),
                controller: name,
                label: l10n.trickNameLabel,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              NyfaForm.section(l10n.whatKind),
              NyfaForm.chips(
                keyPrefix: 'Kind',
                options: [
                  (value: 'trick', label: l10n.kindTrick),
                  (value: 'composite', label: l10n.kindComposite),
                  (value: 'string', label: l10n.kindString),
                ],
                selected: {kind},
                onToggle: (v) => setState(() {
                  kind = v;
                  if (v == 'composite') _nameComposite();
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(switch (kind) {
                  'composite' => l10n.kindCompositeExplain,
                  'string' => l10n.kindStringExplain,
                  _ => l10n.kindTrickExplain,
                }, style: Nyfa.bodyMuted.copyWith(fontSize: 13)),
              ),
              if (kind == 'composite') ...[
                NyfaForm.section(l10n.baseLabel),
                if (base != null)
                  _parts(
                    [base!],
                    numbered: false,
                    onRemove: (_) => setState(() => base = null),
                  )
                else
                  _addRow(const Key('PickBase'), l10n.pickBase, pickBase),
                NyfaForm.section(l10n.modifiersLabel),
                _parts(
                  modifiers,
                  numbered: false,
                  onRemove: (i) => setState(() {
                    modifiers = [...modifiers]..removeAt(i);
                    _nameComposite();
                  }),
                ),
                if (modifiers.length < 4)
                  _addRow(
                    const Key('AddModifier'),
                    l10n.addModifier,
                    addModifiers,
                  ),
              ],
              if (kind == 'string') ...[
                NyfaForm.section(l10n.stepsInOrder),
                _parts(
                  steps,
                  numbered: true,
                  onRemove: (i) =>
                      setState(() => steps = [...steps]..removeAt(i)),
                ),
                if (steps.length < 20)
                  _addRow(const Key('AddStep'), l10n.addStep, addSteps),
              ],
              const SizedBox(height: 24),
              NyfaForm.field(
                key: const Key('SuggestTrickAbout'),
                controller: description,
                label: l10n.aboutTrick,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
              ),
              const SizedBox(height: 14),
              NyfaForm.field(
                key: const Key('SuggestTrickAka'),
                controller: aka,
                label: l10n.nicknamesLabel,
                capitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
