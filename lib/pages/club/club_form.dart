// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Start a club, or edit one you organise.
///
/// A name is the only thing asked for. "A club is two people who play" --
/// if starting one feels like paperwork, nobody does, and the local network
/// the app depends on never forms.
class ClubForm extends StatefulWidget {
  /// The club being edited; null to start a new one.
  final FootbagClub? club;

  const ClubForm({this.club, super.key});

  @override
  State<ClubForm> createState() => _ClubFormState();
}

class _ClubFormState extends State<ClubForm> {
  late final name = TextEditingController(text: widget.club?.name ?? '');
  late final location = TextEditingController(
    text: widget.club?.location ?? '',
  );
  late final description = TextEditingController(
    text: widget.club?.description ?? '',
  );
  bool saving = false;

  bool get editing => widget.club != null;

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final router = GoRouter.of(context);
    final client = Matrix.of(context).client;
    setState(() => saving = true);
    try {
      if (editing) {
        await client.editClub(
          widget.club!.id,
          name: name.text.trim(),
          location: location.text.trim(),
          description: description.text.trim(),
        );
        router.pop();
      } else {
        final club = await client.createClub(
          name: name.text.trim(),
          location: location.text.trim(),
          description: description.text.trim(),
        );
        // Straight to the new club, in place of this form: Back from the
        // club should not land on a form that has already done its job.
        router.pushReplacement('/rooms/club/${club.id}');
      }
    } on FootbagApiException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.statusCode == 409 ? l10n.clubNameTaken : e.detail),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.oopsSomethingWentWrong)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final ready = name.text.trim().isNotEmpty && !saving;
    return Scaffold(
      key: const Key('ClubFormScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: editing ? l10n.editClub : l10n.startAClub),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Nyfa.rule)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: NyfaForm.action(
              key: const Key('ClubFormSave'),
              label: editing ? l10n.saveChanges : l10n.startAClub,
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
              if (!editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(l10n.startAClubExplain, style: Nyfa.bodyMuted),
                ),
              NyfaForm.field(
                key: const Key('ClubName'),
                controller: name,
                label: l10n.clubName,
                maxLength: 80,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              NyfaForm.field(
                key: const Key('ClubLocation'),
                controller: location,
                label: l10n.clubLocation,
                maxLength: 128,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              NyfaForm.field(
                key: const Key('ClubDescription'),
                controller: description,
                label: l10n.clubDescription,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
