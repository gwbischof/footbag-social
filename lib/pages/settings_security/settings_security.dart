// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:footbag_network/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:footbag_network/widgets/app_lock.dart';
import 'package:footbag_network/widgets/future_loading_dialog.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'settings_security_view.dart';

class SettingsSecurity extends StatefulWidget {
  const SettingsSecurity({super.key});

  @override
  SettingsSecurityController createState() => SettingsSecurityController();
}

class SettingsSecurityController extends State<SettingsSecurity> {
  Future<void> toggleBiometrics() async {
    AppLock.of(context).showLockScreen();

    final oldState = AppLock.of(context).useBiometrics;
    final actionStr = oldState
        ? L10n.of(context).disableBiometrics
        : L10n.of(context).enableBiometrics;
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: actionStr,
      message: L10n.of(context).biometricsDescription,
      okLabel: actionStr,
      cancelLabel: L10n.of(context).cancel,
      isDestructive: true,
    );
    if (consent != OkCancelResult.ok) return;
    if (!mounted) return;

    if (!oldState) {
      final localAuth = LocalAuthentication();
      final unlocked = await localAuth.authenticate(
        localizedReason: actionStr,
        biometricOnly: true,
      );
      if (!unlocked) return;
      if (!mounted) return;
    }
    await AppLock.of(context).changeUseBiometrics(!oldState);
    setState(() {});
  }

  Future<void> disableAppLockAction() async {
    AppLock.of(context).showLockScreen();
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).disableAppLock,
      message: L10n.of(context).disableAppLockAreYouSure,
      okLabel: L10n.of(context).disableAppLock,
      cancelLabel: L10n.of(context).cancel,
      isDestructive: true,
    );
    if (consent != OkCancelResult.ok) return;
    if (!mounted) return;
    await AppLock.of(context).changePincode(null);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> setAppLockAction() async {
    await AppLock.of(context).changeUseBiometrics(false);
    if (!mounted) return;
    final l10n = L10n.of(context);
    if (AppLock.of(context).isActive) {
      AppLock.of(context).showLockScreen();
    }
    final newLock = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: l10n.pleaseChooseAPasscode,
      message: l10n.pleaseEnter6Digits,
      cancelLabel: l10n.cancel,
      validator: (text) {
        if (text.length == 6 && int.tryParse(text)! >= 0) {
          return null;
        }
        return l10n.pleaseEnter6Digits;
      },
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLines: 1,
      minLines: 1,
      maxLength: 6,
    );
    if (newLock != null) {
      if (!mounted) return;
      await AppLock.of(context).changePincode(newLock);
      setState(() {});
    }
  }

  /// Delete the account: footbag data first, then the chat account.
  ///
  /// In that order because deactivating the chat account kills the token the
  /// API checks -- done the other way round, the data could never be
  /// erased. One plain confirm, rather than FluffyChat's "type your Matrix
  /// ID", which asked people for an identifier this app never shows them.
  Future<void> deleteAccountAction() async {
    final l10n = L10n.of(context);
    final matrix = Matrix.of(context);
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: l10n.deleteAccountTitle,
          message: l10n.deleteAccountBody,
          okLabel: l10n.deleteAccount,
          cancelLabel: l10n.cancel,
          isDestructive: true,
        ) !=
        OkCancelResult.ok) {
      return;
    }
    if (!mounted) return;
    final data = await showFutureLoadingDialog(
      context: context,
      future: matrix.client.deleteFootbagAccount,
    );
    if (data.isError || !mounted) return;
    final resp = await showFutureLoadingDialog(
      context: context,
      delay: false,
      future: () => matrix.client.uiaRequestBackground<IdServerUnbindResult?>(
        (auth) => matrix.client.deactivateAccount(auth: auth, erase: true),
      ),
    );
    if (!resp.isError) {
      if (!mounted) return;
      await showFutureLoadingDialog(
        context: context,
        future: () => matrix.client.logout(),
      );
    }
  }

  Future<void> dehydrateAction() => Matrix.of(context).dehydrateAction(context);

  Future<void> changeShareKeysWith(ShareKeysWith? shareKeysWith) async {
    if (shareKeysWith == null) return;
    AppSettings.shareKeysWith.setItem(shareKeysWith.name);
    Matrix.of(context).client.shareKeysWith = shareKeysWith;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SettingsSecurityView(this);
}
