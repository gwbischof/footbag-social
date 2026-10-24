// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

abstract class AppConfig {
  static const Color primaryColor = Color(0xFF2E8B2E);

  static const Color chatColor = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool enableRegistration = true;
  static const bool hideTypingUsernames = false;

  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'com.footbagnetwork://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'footbag_network_push';
  static const String pushNotificationsAppId = 'com.footbagnetwork.app';
  static const double borderRadius = 18.0;
  static const double spaceBorderRadius = 11.0;
  static const double columnWidth = 360.0;

  static const String enablePushTutorial =
      'https://unifiedpush.org/users/intro/';
  static const String encryptionTutorial = 'https://matrix.org/faq/#encryption';
  static const String howDoIGetStickersTutorial =
      'https://github.com/gwbischof/footbag-social/blob/main/README.md';
  static const String appId = 'com.footbagnetwork.app';
  static const String appOpenUrlScheme = 'com.footbagnetwork';
  static const String appSsoUrlScheme = 'com.footbagnetwork.auth';
  // Identifies the notification activation callback on Windows. Never change!
  static const String windowsNotificationGuid =
      'eebeef3a-be38-4f74-9449-fb68522071b5';

  static const String sourceCodeUrl =
      'https://github.com/gwbischof/footbag-social';
  static const String supportUrl =
      'https://github.com/gwbischof/footbag-social/issues';
  static const String changelogUrl =
      'https://github.com/gwbischof/footbag-social/releases';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/gwbischof/footbag-social/releases/latest';
  static const String helpUrl =
      'https://github.com/gwbischof/footbag-social/issues';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/gwbischof/footbag-social/issues/new',
  );

  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    path:
        'gwbischof/footbag-social/refs/heads/main/recommended_homeservers.json',
  );

  static const String mainIsolatePortName = 'main_isolate';
  static const String pushIsolatePortName = 'push_isolate';
  static const String pushHelperCrashReportKey = 'push_helper_crash_report';

  static const String vodozemacVersion = '0.8.1';
}
