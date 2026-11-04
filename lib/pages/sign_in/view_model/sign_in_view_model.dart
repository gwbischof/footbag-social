// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:footbag_network/pages/sign_in/view_model/sign_in_state.dart';
import 'package:footbag_network/widgets/matrix.dart';

class SignInViewModel extends ValueNotifier<SignInState> {
  final MatrixState matrixService;
  final bool signUp;
  final TextEditingController filterTextController = TextEditingController();

  SignInViewModel(this.matrixService, {required this.signUp})
    : super(SignInState()) {
    refreshPublicHomeservers();
    filterTextController.addListener(_filterHomeservers);
  }

  @override
  void dispose() {
    filterTextController.removeListener(_filterHomeservers);
    filterTextController.dispose();
    super.dispose();
  }

  void _filterHomeservers() {
    final filterText = filterTextController.text.trim().toLowerCase();
    final filteredPublicHomeservers =
        value.publicHomeservers.data
            ?.where(
              (homeserver) =>
                  homeserver.name?.toLowerCase().contains(filterText) ?? false,
            )
            .toList() ??
        [];
    if (filterText.length >= 3 &&
        (filterText.contains('.') || filterText.endsWith('localhost')) &&
        Uri.tryParse(filterText) != null &&
        !filteredPublicHomeservers.any(
          (homeserver) => homeserver.name == filterText,
        )) {
      filteredPublicHomeservers.add(PublicHomeserverData(name: filterText));
    }
    value.filteredPublicHomeservers = filteredPublicHomeservers;
    notifyListeners();
  }

  /// Footbag Social has exactly one homeserver, so the list is just that.
  ///
  /// Upstream FluffyChat fetched a public server directory from GitHub here,
  /// which told GitHub the IP of everyone who opened the sign-in screen, for a
  /// list this app never shows.
  Future<void> refreshPublicHomeservers() async {
    final defaultHomeserverData = PublicHomeserverData(
      name: AppSettings.defaultHomeserver.value,
    );
    value.selectedHomeserver = value.selectedHomeserver ?? defaultHomeserverData;
    value.publicHomeservers = AsyncSnapshot.withData(ConnectionState.done, [
      defaultHomeserverData,
    ]);
    notifyListeners();
    _filterHomeservers();
  }

  void selectHomeserver(PublicHomeserverData? publicHomeserverData) {
    value.selectedHomeserver = publicHomeserverData;
    notifyListeners();
  }

  void setLoginLoading(AsyncSnapshot<bool> loginLoading) {
    value.loginLoading = loginLoading;
    notifyListeners();
  }
}
