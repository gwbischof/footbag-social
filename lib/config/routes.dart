// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/config/themes.dart';
import 'package:footbag_network/pages/archive/archive.dart';
import 'package:footbag_network/pages/bootstrap/bootstrap_page.dart';
import 'package:footbag_network/pages/chat/chat.dart';
import 'package:footbag_network/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:footbag_network/pages/chat_details/chat_details.dart';
import 'package:footbag_network/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:footbag_network/pages/chat_list/chat_list.dart';
import 'package:footbag_network/pages/chat_members/chat_members.dart';
import 'package:footbag_network/pages/chat_permissions_settings/chat_permissions_settings.dart';
import 'package:footbag_network/pages/chat_search/chat_search_page.dart';
import 'package:footbag_network/pages/dash/dash.dart';
import 'package:footbag_network/pages/device_settings/device_settings.dart';
import 'package:footbag_network/pages/favourites/favourites.dart';
import 'package:footbag_network/pages/intro/intro_page_presenter.dart';
import 'package:footbag_network/pages/invitation_selection/invitation_selection.dart';
import 'package:footbag_network/pages/login/login.dart';
import 'package:footbag_network/pages/new_group/new_group.dart';
import 'package:footbag_network/pages/new_private_chat/new_private_chat.dart';
import 'package:footbag_network/pages/new_session/new_session.dart';
import 'package:footbag_network/pages/profile/profile.dart';
import 'package:footbag_network/pages/report/report.dart';
import 'package:footbag_network/pages/settings/settings.dart';
import 'package:footbag_network/pages/settings_3pid/settings_3pid.dart';
import 'package:footbag_network/pages/settings_chat/settings_chat.dart';
import 'package:footbag_network/pages/settings_emotes/settings_emotes.dart';
import 'package:footbag_network/pages/settings_homeserver/settings_homeserver.dart';
import 'package:footbag_network/pages/settings_ignore_list/settings_ignore_list.dart';
import 'package:footbag_network/pages/settings_notifications/settings_notifications.dart';
import 'package:footbag_network/pages/settings_password/settings_password.dart';
import 'package:footbag_network/pages/settings_security/settings_security.dart';
import 'package:footbag_network/pages/settings_style/settings_style.dart';
import 'package:footbag_network/pages/sign_in/sign_in_page.dart';
import 'package:footbag_network/pages/trick_picker/trick_picker.dart';
import 'package:footbag_network/widgets/config_viewer.dart';
import 'package:footbag_network/widgets/layouts/empty_page.dart';
import 'package:footbag_network/widgets/layouts/two_column_layout.dart';
import 'package:footbag_network/widgets/log_view.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:footbag_network/widgets/share_scaffold_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

abstract class AppRoutes {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) => Matrix.of(context).widget.clients.any((client) => client.isLogged())
      ? '/rooms/dash'
      : null;

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) => Matrix.of(context).widget.clients.any((client) => client.isLogged())
      ? null
      : '/home';

  /// Blocks the homeserver picker whenever the app is pinned to one server.
  ///
  /// presetHomeserver only changes what the intro button does; the picker
  /// routes stay registered, so without this guard a link to /home/sign_in
  /// reaches a free-text homeserver field on our own origin. Anything typed
  /// there that looks like a domain becomes selectable, gets connected to, and
  /// is written back as the default — which is a credential phishing path
  /// wearing our branding and our TLS certificate.
  static FutureOr<String?> homeserverPickerRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    if (AppSettings.presetHomeserver.value.isNotEmpty) return '/home';
    return loggedInRedirect(context, state);
  }

  /// Same guard for the add-account picker, which is reachable while logged in
  /// and so is the more plausible-looking version of the same lure.
  static FutureOr<String?> addAccountPickerRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    if (AppSettings.presetHomeserver.value.isNotEmpty) {
      return '/rooms/settings/addaccount';
    }
    return loggedOutRedirect(context, state);
  }

  AppRoutes();

  static final List<RouteBase> routes = [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          Matrix.of(context).widget.clients.any((client) => client.isLogged())
          // Dash, not the chat list: the app opens on "is anyone playing?"
          // rather than on a conversation list.
          ? '/rooms/dash'
          : '/home',
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const IntroPagePresenter()),
      redirect: loggedInRedirect,
      routes: [
        GoRoute(
          path: 'sign_in',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: false)),
          redirect: homeserverPickerRedirect,
        ),
        GoRoute(
          path: 'sign_up',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: true)),
          redirect: homeserverPickerRedirect,
        ),
        GoRoute(
          path: 'login',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            Login(client: state.extra as Client),
          ),
          redirect: loggedInRedirect,
        ),
      ],
    ),
    GoRoute(
      path: '/logs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const LogViewer()),
    ),
    GoRoute(
      path: '/configs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const ConfigViewer()),
    ),
    GoRoute(
      path: '/backup',
      redirect: loggedOutRedirect,
      pageBuilder: (context, state) => defaultPageBuilder(
        context,
        state,
        BootstrapPage(reset: state.uri.queryParameters['reset'] == 'true'),
      ),
    ),
    ShellRoute(
      // Never use a transition on the shell route. Changing the PageBuilder
      // here based on a MediaQuery causes the child to briefly be rendered
      // twice with the same GlobalKey, blowing up the rendering.
      pageBuilder: (context, state, child) => noTransitionPageBuilder(
        context,
        state,
        // Dash and its children are full screens, not the side pane of a chat
        // shell. Without this exclusion the home screen renders beside the
        // chat list with two navigation bars on screen at once -- the chat
        // list's and its own. Settings is excluded for the same reason.
        AppThemes.isColumnMode(context) &&
                state.fullPath?.startsWith('/rooms/settings') == false &&
                state.fullPath?.startsWith('/rooms/dash') == false
            ? TwoColumnLayout(
                mainView: ChatList(
                  activeChat: state.pathParameters['roomid'],
                  activeSpace: state.uri.queryParameters['spaceId'],
                  displayNavigationRail:
                      state.path?.startsWith('/rooms/settings') != true,
                ),
                sideView: child,
              )
            : child,
      ),
      routes: [
        GoRoute(
          path: '/rooms',
          redirect: loggedOutRedirect,
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            AppThemes.isColumnMode(context)
                ? const EmptyPage()
                : ChatList(
                    activeChat: state.pathParameters['roomid'],
                    activeSpace: state.uri.queryParameters['spaceId'],
                  ),
          ),
          routes: [
            // Registered before the ':roomid' catch-all further down, matching
            // how 'archive' and 'newgroup' are ordered -- a literal that comes
            // after a parameter is a route that silently becomes a room id.
            //
            // Nested under /rooms so it inherits the logged-in guard, but
            // excluded from the two-column wrapper above: Dash is the home
            // screen, not a detail pane.
            GoRoute(
              path: 'dash',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Dash()),
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'profile',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const ProfilePage()),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'schedule',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const NewSession()),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'favourites',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const Favourites()),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'add',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        // The picker is told what the player already has, so an
                        // existing favourite reads as context rather than as an
                        // option that would silently do nothing.
                        TrickPicker(
                          alreadyHave:
                              (state.extra as Set<String>?) ?? const {},
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                ),
                GoRoute(
                  path: ':sessionid/report',
                  // tryParse, and redirect on null: int.parse inside the
                  // pageBuilder turns a malformed deep link into a
                  // FormatException thrown during build rather than a route
                  // that simply does not match.
                  redirect: (context, state) {
                    final id = state.pathParameters['sessionid'];
                    if (id == null || int.tryParse(id) == null) {
                      return '/rooms/sessions';
                    }
                    return loggedOutRedirect(context, state);
                  },
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    Report(
                      sessionId: int.parse(state.pathParameters['sessionid']!),
                    ),
                  ),
                ),
              ],
            ),
            // The sessions screen folded into Dash; keep the old path alive
            // rather than 404 anything that linked to it.
            GoRoute(
              path: 'sessions',
              redirect: (context, state) => '/rooms/dash',
            ),
            GoRoute(
              path: 'archive',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Archive()),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatPage(
                      key: ValueKey(state.uri),
                      roomId: state.pathParameters['roomid']!,
                      eventId: state.uri.queryParameters['event'],
                      timeline: state.extra as Timeline?,
                      action: state.uri.queryParameters['action'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
              ],
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newprivatechat',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewPrivateChat(
                  key: ValueKey('new_chat_${state.uri.fragment}'),
                  deeplink: state.uri.fragment,
                ),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newgroup',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewGroup(spaceId: state.uri.queryParameters['space_id']),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newspace',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewGroup(
                  createGroupType: CreateGroupType.space,
                  spaceId: state.uri.queryParameters['space_id'],
                ),
              ),
              redirect: loggedOutRedirect,
            ),
            ShellRoute(
              pageBuilder: (context, state, child) => defaultPageBuilder(
                context,
                state,
                AppThemes.isColumnMode(context)
                    ? TwoColumnLayout(
                        mainView: Settings(key: state.pageKey),
                        sideView: child,
                        hasNavigationRail: false,
                      )
                    : child,
              ),
              routes: [
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    AppThemes.isColumnMode(context)
                        ? const EmptyPage()
                        : const Settings(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsNotifications(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'style',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsStyle(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'devices',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const DevicesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'chat',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsChat(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'emotes',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            EmotesSettings(
                              roomId: state.pathParameters['roomid'],
                            ),
                          ),
                        ),
                      ],
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'addaccount',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const IntroPagePresenter(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'sign_in',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: false),
                          ),
                          redirect: addAccountPickerRedirect,
                        ),
                        GoRoute(
                          path: 'sign_up',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: true),
                          ),
                          redirect: addAccountPickerRedirect,
                        ),
                        GoRoute(
                          path: 'login',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            Login(client: state.extra as Client),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'homeserver',
                      pageBuilder: (context, state) {
                        return defaultPageBuilder(
                          context,
                          state,
                          const SettingsHomeserver(),
                        );
                      },
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'security',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsSecurity(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'password',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              const SettingsPassword(),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'ignorelist',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              SettingsIgnoreList(
                                initialUserId: state.extra?.toString(),
                              ),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: '3pid',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const Settings3Pid(),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            GoRoute(
              path: ':roomid',
              pageBuilder: (context, state) {
                final body = state.uri.queryParameters['body'];
                var shareItems = state.extra is List<ShareItem>
                    ? state.extra as List<ShareItem>
                    : null;
                if (body != null && body.isNotEmpty) {
                  shareItems ??= [];
                  shareItems.add(TextShareItem(body));
                }
                return defaultPageBuilder(
                  context,
                  state,
                  ChatPage(
                    key: ValueKey(state.uri),
                    roomId: state.pathParameters['roomid']!,
                    shareItems: shareItems,
                    eventId: state.uri.queryParameters['event'],
                    action: state.uri.queryParameters['action'],
                  ),
                );
              },
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatSearchPage(roomId: state.pathParameters['roomid']!),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'encryption',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    const ChatEncryptionSettings(),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'invite',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    InvitationSelection(
                      roomId: state.pathParameters['roomid']!,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'details',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatDetails(roomId: state.pathParameters['roomid']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'access',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatAccessSettings(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'members',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatMembersPage(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'permissions',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const ChatPermissionsSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'invite',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        InvitationSelection(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'emotes',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        EmotesSettings(roomId: state.pathParameters['roomid']),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static Page noTransitionPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => NoTransitionPage(
    key: state.pageKey,
    restorationId: state.pageKey.value,
    child: child,
  );

  static Page defaultPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    final clientName = state.uri.queryParameters['client'];
    if (clientName != null) {
      final matrix = Matrix.of(context);
      final client = matrix.getClientByName(clientName);
      if (client != null) matrix.setActiveClient(client);
    }
    return AppThemes.isColumnMode(context)
        ? noTransitionPageBuilder(context, state, child)
        : MaterialPage(
            key: state.pageKey,
            restorationId: state.pageKey.value,
            child: child,
          );
  }
}
