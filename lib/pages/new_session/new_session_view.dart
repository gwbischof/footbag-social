// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/new_session/new_session.dart';
import 'package:footbag_network/utils/date_time_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class NewSessionView extends StatelessWidget {
  final NewSessionController controller;

  const NewSessionView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      key: const Key('NewSessionScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.scheduleSession),
      body: MaxWidthBody(
        withScrolling: false,
        child: ListView(
          key: const Key('NewSessionList'),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            NyfaForm.section(l10n.scheduleWhen),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: _Picker(
                      key: const Key('PickDateButton'),
                      label: l10n.pickDate,
                      value: controller.date.localizedDate(context),
                      onTap: controller.pickDate,
                    ),
                  ),
                  Expanded(
                    child: _Picker(
                      key: const Key('PickTimeButton'),
                      label: l10n.pickTime,
                      value: controller.time.format(context),
                      onTap: controller.pickTime,
                    ),
                  ),
                ],
              ),
            ),
            if (!controller.isFuture)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  l10n.mustBeInFuture,
                  // Red would be the reflex, but the club palette has no error
                  // colour and the green already means "this is the live
                  // thing". Muted plus a disabled action says it clearly.
                  style: Nyfa.bodyMuted.copyWith(color: Nyfa.paper),
                ),
              ),

            NyfaForm.section(l10n.sessionTypeLabel),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(l10n.sessionTypeHelp, style: Nyfa.bodyMuted),
            ),
            NyfaForm.chips(
              keyPrefix: 'Type',
              options: [
                (value: 'casual', label: l10n.sessionTypeCasual),
                (value: 'kicking', label: l10n.sessionTypeKicking),
                (value: 'freestyle', label: l10n.sessionTypeFreestyle),
                (value: 'net', label: l10n.sessionTypeNet),
                (value: 'stitching', label: l10n.sessionTypeStitching),
              ],
              // A single value, so selecting is replacing rather than toggling.
              selected: {controller.type},
              onToggle: controller.setType,
            ),

            const SizedBox(height: 24),
            NyfaForm.field(
              key: const Key('SessionNameField'),
              controller: controller.nameController,
              label: l10n.sessionName,
              helper: l10n.sessionNameHelp,
              maxLength: 128,
              capitalization: TextCapitalization.words,
            ),

            NyfaForm.section(l10n.whoCanJoin),
            NyfaForm.chips(
              keyPrefix: 'Joining',
              options: [
                (value: 'open', label: l10n.joiningOpen),
                (value: 'invite_only', label: l10n.joiningInviteOnly),
              ],
              selected: {controller.joining},
              onToggle: controller.setJoining,
            ),
            const SizedBox(height: 10),
            NyfaForm.toggle(
              key: const Key('OnFeedSwitch'),
              label: l10n.showOnFeed,
              explain: l10n.showOnFeedExplain,
              value: controller.onFeed,
              onChanged: controller.setOnFeed,
            ),

            NyfaForm.section(l10n.whatToKnow),
            NyfaForm.field(
              key: const Key('SessionNoteField'),
              controller: controller.noteController,
              label: l10n.whatToKnow,
              helper: l10n.whatToKnowHelp,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
            ),

            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NyfaForm.action(
                key: const Key('CreateSessionButton'),
                label: controller.saving ? l10n.saving : l10n.createSession,
                onPressed: controller.saving || !controller.isFuture
                    ? null
                    : controller.createAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A date or time, shown as its value with the label above it.
///
/// A button rather than a text field: the value is always set, so there is
/// nothing to type and nothing to validate — only something to change.
class _Picker extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _Picker({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value',
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: Nyfa.rule)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: Nyfa.eyebrow.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Nyfa.heading.copyWith(fontSize: 19),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
