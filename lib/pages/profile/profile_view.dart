// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/profile/profile.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/utils/localized_exception_extension.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:material_ui/material_ui.dart';

class ProfileView extends StatelessWidget {
  final ProfileController controller;

  const ProfileView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      key: const Key('ProfileScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.editProfile),
      body: MaxWidthBody(withScrolling: false, child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, L10n l10n) {
    if (controller.error != null) {
      return _Problem(
        message: controller.error!.toLocalizedString(context),
        retryLabel: l10n.retry,
        onRetry: controller.load,
        title: l10n.oopsSomethingWentWrong,
      );
    }
    if (controller.player == null) {
      return const Center(
        child: CircularProgressIndicator(color: Nyfa.green, strokeWidth: 2),
      );
    }

    return ListView(
      key: const Key('ProfileList'),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 12),
        NyfaForm.field(
          key: const Key('ProfileNameField'),
          controller: controller.nameController,
          label: l10n.displayName,
          helper: l10n.displayNameHelp,
          maxLength: 128,
          capitalization: TextCapitalization.words,
          onChanged: (_) => controller.onNameChanged(),
        ),
        const SizedBox(height: 14),
        NyfaForm.field(
          key: const Key('ProfileBioField'),
          controller: controller.bioController,
          label: l10n.bio,
          helper: l10n.bioHelp,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
        ),
        const SizedBox(height: 14),
        NyfaForm.field(
          key: const Key('ProfileCityField'),
          controller: controller.cityController,
          label: l10n.city,
          helper: l10n.cityHelp,
          maxLength: 128,
          capitalization: TextCapitalization.words,
        ),

        NyfaForm.section(l10n.playStyles),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(l10n.playStylesHelp, style: Nyfa.bodyMuted),
        ),
        NyfaForm.chips(
          keyPrefix: 'Style',
          options: [
            (value: FootbagDiscipline.kicking.wire, label: l10n.sessionTypeKicking),
            (value: FootbagDiscipline.freestyle.wire, label: l10n.sessionTypeFreestyle),
            (value: FootbagDiscipline.net.wire, label: l10n.sessionTypeNet),
            (value: FootbagDiscipline.stitching.wire, label: l10n.sessionTypeStitching),
          ],
          selected: controller.styles,
          onToggle: controller.toggleStyle,
        ),

        NyfaForm.section(l10n.privacy),
        NyfaForm.toggle(
          key: const Key('DiscoverableSwitch'),
          label: l10n.discoverable,
          explain: l10n.discoverableExplain,
          value: controller.discoverable,
          onChanged: controller.setDiscoverable,
        ),
        NyfaForm.toggle(
          key: const Key('ShowSessionsSwitch'),
          label: l10n.showMySessions,
          explain: l10n.showMySessionsExplain,
          value: controller.showSessions,
          onChanged: controller.setShowSessions,
        ),

        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: NyfaForm.action(
            key: const Key('SaveProfileButton'),
            label: controller.saving ? l10n.saving : l10n.saveProfile,
            onPressed: controller.canSave ? controller.saveAction : null,
          ),
        ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  const _Problem({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    children: [
      const SizedBox(height: 80),
      const Icon(Icons.cloud_off_rounded, size: 44, color: Nyfa.muted),
      const SizedBox(height: 18),
      Text(title.toUpperCase(), textAlign: TextAlign.center, style: Nyfa.heading),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: Nyfa.bodyMuted),
      const SizedBox(height: 20),
      Center(
        child: NyfaForm.action(
          label: retryLabel,
          filled: false,
          onPressed: onRetry,
        ),
      ),
    ],
  );
}
