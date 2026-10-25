// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:footbag_network/utils/platform_infos.dart';
import 'package:http/http.dart' as http;
import 'package:managed_configurations/managed_configurations.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppSettings<T> {
  textMessageMaxLength<int>('textMessageMaxLength', 16384),

  /// Max lines for unselected HTML/text bubbles; 0 = unlimited (no fade).
  messagePreviewMaxLines<int>(
    'com.footbagnetwork.message_preview_max_lines',
    50,
  ),
  audioRecordingNumChannels<int>('audioRecordingNumChannels', 1),
  audioRecordingAutoGain<bool>('audioRecordingAutoGain', true),
  audioRecordingEchoCancel<bool>('audioRecordingEchoCancel', false),
  audioRecordingNoiseSuppress<bool>('audioRecordingNoiseSuppress', true),
  audioRecordingBitRate<int>('audioRecordingBitRate', 64000),
  audioRecordingSamplingRate<int>('audioRecordingSamplingRate', 48000),
  showNoGoogle<bool>('com.footbagnetwork.show_no_google', false),
  unifiedPushRegistered<bool>(
    'com.footbagnetwork.unifiedpush.registered',
    false,
  ),
  unifiedPushEndpoint<String>('com.footbagnetwork.unifiedpush.endpoint', ''),
  // No push gateway yet. FluffyChat's gateway is theirs, not ours; mobile push
  // needs our own (or UnifiedPush) before this does anything.
  pushNotificationsGatewayUrl<String>('pushNotificationsGatewayUrl', ''),
  pushNotificationsPusherFormat<String>(
    'pushNotificationsPusherFormat',
    'event_id_only',
  ),
  renderHtml<bool>('com.footbagnetwork.renderHtml', true),
  fontSizeFactor<double>('com.footbagnetwork.font_size_factor', 1.0),
  hideRedactedEvents<bool>('com.footbagnetwork.hideRedactedEvents', false),
  hideUnknownEvents<bool>('com.footbagnetwork.hideUnknownEvents', true),
  autoplayImages<bool>('com.footbagnetwork.autoplay_images', true),
  sendTypingNotifications<bool>(
    'com.footbagnetwork.send_typing_notifications',
    true,
  ),
  sendPublicReadReceipts<bool>(
    'com.footbagnetwork.send_public_read_receipts',
    true,
  ),
  swipeRightToLeftToReply<bool>(
    'com.footbagnetwork.swipeRightToLeftToReply',
    true,
  ),
  sendOnEnter<bool>('com.footbagnetwork.send_on_enter', false),
  displayNavigationRail<bool>(
    'com.footbagnetwork.display_navigation_rail',
    false,
  ),
  shareKeysWith<String>('com.footbagnetwork.share_keys_with_2', 'all'),
  noEncryptionWarningShown<bool>(
    'com.footbagnetwork.no_encryption_warning_shown',
    false,
  ),
  displayChatDetailsColumn(
    'com.footbagnetwork.display_chat_details_column',
    false,
  ),
  // AppConfig-mirrored settings
  applicationName<String>(
    'com.footbagnetwork.application_name',
    'Footbag Social',
  ),
  // The apex, not chat.footbagsocial.com. The homeserver's server_name is the
  // apex and Synapse runs on the chat subdomain, so the client is given the
  // apex and finds the real host through /.well-known/matrix/client. Pointing
  // this straight at the chat host would work but would bypass the delegation,
  // leaving it untested until something else depended on it.
  defaultHomeserver<String>(
    'com.footbagnetwork.default_homeserver',
    'footbagsocial.com',
  ),
  // colorSchemeSeed stored as ARGB int
  colorSchemeSeedInt<int>('com.footbagnetwork.color_scheme_seed', 0xFF2E8B2E),
  emojiSuggestionLocale<String>('emoji_suggestion_locale', ''),
  enableSoftLogout<bool>('com.footbagnetwork.enable_soft_logout', true),
  enableMatrixNativeOIDC<bool>(
    'com.footbagnetwork.enable_matrix_native_oidc',
    true,
  ),
  // Non-empty pins the app to one homeserver: the intro screen connects
  // straight to it and the server picker is never shown.
  presetHomeserver<String>(
    'com.footbagnetwork.preset_homeserver',
    'footbagsocial.com',
  ),
  welcomeText<String>('com.footbagnetwork.welcome_text', ''),
  website<String>(
    'com.footbagnetwork.website_url',
    'https://newyorkfootbag.com',
  ),
  logoUrl<String>(
    'com.footbagnetwork.logo_url',
    'https://newyorkfootbag.com/footbag_logo2.png',
  ),
  privacyPolicy<String>(
    'com.footbagnetwork.privacy_policy_url',
    'https://newyorkfootbag.com/privacy',
  ),
  tos<String>('com.footbagnetwork.tos_url', 'https://newyorkfootbag.com/terms'),
  sendTimelineEventTimeout<int>(
    'com.footbagnetwork.send_timeline_event_timeout',
    15,
  ),
  webNotificationSound<bool>('com.footbagnetwork.web_notification_sound', true),
  chatFilter<String>('com.footbagnetwork.chat_filter', 'allChats'),
  hideRoomsInSpaces<bool>('com.footbagnetwork.hideRoomsInSpaces', false),
  showThumbnailsInTimeline<bool>(
    'com.footbagnetwork.showThumbnailsInTimeline',
    true,
  ),
  doubleTapToReact<bool>('com.footbagnetwork.double_tap_to_react', false),
  doubleTapReaction<String>('com.footbagnetwork.double_tap_reaction', '❤️'),
  benchmarksInLogs<bool>('com.footbagnetwork.benchmarks_in_logs', false),
  autoSendErrorReports<bool?>(
    'com.footbagnetwork.auto_send_eror_reports',
    null,
  ),
  knownErrorHashes<List<String>>('com.footbagnetwork.known_crash_hashes', []),
  checkForUpdates<bool>('com.footbagnetwork.check_for_updates', true),
  lastUpdateCheckDate<String>('com.footbagnetwork.last_update_check_date', '');

  final String key;
  final T _defaultValue;

  const AppSettings(this.key, this._defaultValue);

  static SharedPreferences get store => _store!;
  static SharedPreferences? _store;

  static Map<String, Object?>? _platformConfiguration;

  T get defaultValue {
    final platformConfig = _platformConfiguration?[name];
    if (platformConfig is T) return platformConfig;
    return _defaultValue;
  }

  static Future<void> reset({bool loadWebConfigFile = true}) async {
    await AppSettings._store!.clear();
    await init(loadWebConfigFile: loadWebConfigFile);
  }

  static Future<SharedPreferences> init({bool loadWebConfigFile = true}) async {
    if (AppSettings._store != null) return AppSettings.store;

    final store = AppSettings._store = await SharedPreferences.getInstance();

    // Migrate wrong datatype for fontSizeFactor
    final fontSizeFactorString = Result(
      () => store.getString(AppSettings.fontSizeFactor.key),
    ).asValue?.value;
    if (fontSizeFactorString != null) {
      Logs().i('Migrate wrong datatype for fontSizeFactor!');
      await store.remove(AppSettings.fontSizeFactor.key);
      final fontSizeFactor = double.tryParse(fontSizeFactorString);
      if (fontSizeFactor != null) {
        await store.setDouble(AppSettings.fontSizeFactor.key, fontSizeFactor);
      }
    }

    if (store.getBool(AppSettings.sendOnEnter.key) == null) {
      await store.setBool(AppSettings.sendOnEnter.key, !PlatformInfos.isMobile);
    }
    if (store.getBool(AppSettings.doubleTapToReact.key) == null) {
      await store.setBool(
        AppSettings.doubleTapToReact.key,
        PlatformInfos.isMobile,
      );
    }

    // Load configuration from config.json file or MDM:
    if (PlatformInfos.isMobile) {
      _platformConfiguration =
          await ManagedConfigurations().getManagedConfigurations;
    } else if (kIsWeb && loadWebConfigFile) {
      try {
        final configJsonString = utf8.decode(
          (await http.get(Uri.parse('config.json'))).bodyBytes,
        );
        _platformConfiguration =
            json.decode(configJsonString) as Map<String, Object?>;
      } on FormatException catch (_) {
        Logs().v('[ConfigLoader] config.json not found');
      } catch (e) {
        Logs().v('[ConfigLoader] config.json not found', e);
      }
    }

    return store;
  }
}

extension AppSettingsBoolNExtension on AppSettings<bool?> {
  bool? get value {
    final value = Result(() => AppSettings.store.getBool(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value;
  }

  Future<void> setItem(bool value) => AppSettings.store.setBool(key, value);
}

extension AppSettingsBoolExtension on AppSettings<bool> {
  bool get value {
    final value = Result(() => AppSettings.store.getBool(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value ?? defaultValue;
  }

  Future<void> setItem(bool value) => AppSettings.store.setBool(key, value);
}

extension AppSettingsStringExtension on AppSettings<String> {
  String get value {
    final value = Result(() => AppSettings.store.getString(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value ?? defaultValue;
  }

  Future<void> setItem(String value) => AppSettings.store.setString(key, value);
}

extension AppSettingsIntExtension on AppSettings<int> {
  int get value {
    final value = Result(() => AppSettings.store.getInt(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value ?? defaultValue;
  }

  Future<void> setItem(int value) => AppSettings.store.setInt(key, value);
}

extension AppSettingsDoubleExtension on AppSettings<double> {
  double get value {
    final value = Result(() => AppSettings.store.getDouble(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value ?? defaultValue;
  }

  Future<void> setItem(double value) => AppSettings.store.setDouble(key, value);
}

extension AppSettingsStringListExtension on AppSettings<List<String>> {
  List<String> get value {
    final value = Result(() => AppSettings.store.getStringList(key));
    final error = value.asError;
    if (error != null) {
      Logs().e(
        'Unable to fetch $key from storage. Removing entry...',
        error.error,
        error.stackTrace,
      );
    }
    return value.asValue?.value ?? defaultValue;
  }

  Future<void> setItem(List<String> value) =>
      AppSettings.store.setStringList(key, value);
}
