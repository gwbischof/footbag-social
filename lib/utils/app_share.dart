// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/platform_infos.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/matrix.dart';

abstract class AppShare {
  static Future<void> share(
    String text,
    BuildContext context, {
    bool copyOnly = false,
  }) async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (PlatformInfos.isMobile && !copyOnly) {
      final box = context.findRenderObject() as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!PlatformInfos.isMobile) {
      scaffoldMessenger.showSnackBar(
        SnackBar(showCloseIcon: true, content: Text(l10n.copiedToClipboard)),
      );
    }
    return;
  }

  static Future<void> shareInviteLink(BuildContext context) async {
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    final ownProfile = await client.fetchOwnProfile();
    if (!context.mounted) return;
    // The app's own address, not a matrix.to link: nobody joining should
    // meet the word Matrix, and the site is where signing up starts anyway.
    await AppShare.share(
      l10n.inviteToFootbagSocial(
        ownProfile.displayName ?? client.userID!.localpart ?? '',
        'https://footbagsocial.com',
      ),
      context,
    );
  }
}
