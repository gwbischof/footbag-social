// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/feed/widgets/feed_states.dart';
import 'package:footbag_network/widgets/layouts/max_width_body.dart';
import 'package:footbag_network/widgets/people.dart';
import 'package:footbag_network/widgets/skeleton.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_ignore_list.dart';

class SettingsIgnoreListView extends StatelessWidget {
  final SettingsIgnoreListController controller;

  const SettingsIgnoreListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = controller.blocks;
    return Scaffold(
      key: const Key('BlockedScaffold'),
      backgroundColor: Nyfa.ground,
      appBar: Nyfa.appBar(title: l10n.blockedUsers),
      body: MaxWidthBody(
        withScrolling: false,
        child: controller.error != null && list == null
            ? FeedProblem(error: controller.error!, onRetry: controller.load)
            : list == null
            ? const SingleChildScrollView(child: RowsSkeleton(avatar: true))
            : list.isEmpty
            ? ListView(children: [FeedEmpty(title: l10n.noBlockedPlayers)])
            : ListView(
                children: [
                  for (final p in list)
                    PersonRow(
                      key: Key('Blocked_${p.userId}'),
                      userId: p.userId,
                      name: p.displayName,
                      trailing: [
                        SmallButton(
                          label: l10n.unblock,
                          onPressed: () => controller.unblock(p),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
