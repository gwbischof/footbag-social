// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/app_config.dart';
import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/config/themes.dart';
import 'package:footbag_network/pages/chat_list/chat_list.dart';
import 'package:footbag_network/pages/chat_list/navigation_rail.dart';
import 'package:footbag_network/pages/chat_list/start_chat_fab.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_list_body.dart';

class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final oneColumnSpacesMode =
        !AppThemes.isColumnMode(context) &&
        AppSettings.displayNavigationRail.value;
    return PopScope(
      canPop: !controller.isSearchMode && controller.activeSpaceId == null,
      onPopInvokedWithResult: (pop, _) {
        if (pop) return;
        if (controller.activeSpaceId != null) {
          controller.clearActiveSpace();
          return;
        }
        if (controller.isSearchMode) {
          controller.cancelSearch();
          return;
        }
      },
      child: Row(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: AnimatedSize(
              duration: AppThemes.animationDuration,
              curve: AppThemes.animationCurve,
              child:
                  (AppThemes.isColumnMode(context) ||
                      AppSettings.displayNavigationRail.value)
                  ? SpacesNavigationRail(
                      activeSpaceId: controller.activeSpaceId,
                      onGoToChats: controller.clearActiveSpace,
                      onGoToSpaceId: controller.setActiveSpace,
                    )
                  : SizedBox(
                      width: 0,
                      height: MediaQuery.sizeOf(context).height,
                    ),
            ),
          ),
          if (AppThemes.isColumnMode(context) ||
              AppSettings.displayNavigationRail.value)
            if (AppThemes.isColumnMode(context))
              Container(width: 1, color: Theme.of(context).dividerColor),

          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                backgroundColor: oneColumnSpacesMode
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : null,
                // Chat is one destination of the app, not the app. The bar is
                // how you get back to Dash -- without it this screen is a
                // dead end, which is exactly how the app came across before.
                bottomNavigationBar: const FootbagNavBar(
                  current: FootbagTab.chat,
                ),
                body: SafeArea(
                  top: oneColumnSpacesMode,
                  bottom: false,
                  left: false,
                  right: false,
                  child: Material(
                    clipBehavior: oneColumnSpacesMode
                        ? Clip.hardEdge
                        : Clip.none,
                    borderRadius: oneColumnSpacesMode
                        ? BorderRadius.only(
                            topLeft: Radius.circular(AppConfig.borderRadius),
                          )
                        : null,
                    color: oneColumnSpacesMode
                        ? Theme.of(context).colorScheme.surface
                        : null,
                    child: ChatListViewBody(controller),
                  ),
                ),
                floatingActionButton:
                    !controller.isSearchMode &&
                        controller.activeSpaceId == null &&
                        !AppThemes.isColumnMode(context)
                    ? ValueListenableBuilder(
                        valueListenable: controller.scrolledToTop,
                        builder: (context, scrolledToTop, _) => StartChatFab(
                          extended:
                              scrolledToTop &&
                              !AppSettings.displayNavigationRail.value,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
