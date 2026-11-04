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
import 'package:footbag_network/pages/club/club_form.dart';
import 'package:footbag_network/pages/club/club_page.dart';
import 'package:footbag_network/pages/dash/dash.dart';
import 'package:footbag_network/pages/device_settings/device_settings.dart';
import 'package:footbag_network/pages/discover/discover.dart';
import 'package:footbag_network/pages/favourites/favourites.dart';
import 'package:footbag_network/pages/feed/compose.dart';
import 'package:footbag_network/pages/feed/feed.dart';
import 'package:footbag_network/pages/feed/mod_queue.dart';
import 'package:footbag_network/pages/feed/player_page.dart';
import 'package:footbag_network/pages/feed/post_page.dart';
import 'package:footbag_network/pages/goals/goals_page.dart';
import 'package:footbag_network/pages/inbox/inbox_page.dart';
import 'package:footbag_network/pages/intro/intro_page_presenter.dart';
import 'package:footbag_network/pages/invitation_selection/invitation_selection.dart';
import 'package:footbag_network/pages/login/login.dart';
import 'package:footbag_network/pages/moderators/moderators_page.dart';
import 'package:footbag_network/pages/new_group/new_group.dart';
import 'package:footbag_network/pages/new_private_chat/new_private_chat.dart';
import 'package:footbag_network/pages/new_session/new_session.dart';
import 'package:footbag_network/pages/places/pending_places_page.dart';
import 'package:footbag_network/pages/places/pending_tricks_page.dart';
import 'package:footbag_network/pages/profile/profile.dart';
import 'package:footbag_network/pages/rankings/rankings.dart';
import 'package:footbag_network/pages/report/report.dart';
import 'package:footbag_network/pages/session/session_page.dart';
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
import 'package:footbag_network/pages/suggest_trick/suggest_trick.dart';
import 'package:footbag_network/pages/trick_picker/trick_picker.dart';
import 'package:footbag_network/pages/welcome/welcome_page.dart';
import 'package:footbag_network/utils/footbag_api.dart';
import 'package:footbag_network/widgets/config_viewer.dart';
import 'package:footbag_network/widgets/footbag_nav_bar.dart';
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
      ? '/rooms/feed'
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
          // The Feed is home (decided Nov 2026, reversing "Dash first"):
          // the app opens on what people are playing and posting.
          ? '/rooms/feed'
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
                state.fullPath?.startsWith('/rooms/dash') == false &&
                state.fullPath?.startsWith('/rooms/discover') == false &&
                state.fullPath?.startsWith('/rooms/feed') == false &&
                state.fullPath?.startsWith('/rooms/session') == false &&
                state.fullPath?.startsWith('/rooms/club') == false &&
                state.fullPath?.startsWith('/rooms/welcome') == false
            ? TwoColumnLayout(
                bottomBar: const FootbagNavBar(current: FootbagTab.chat),
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
              path: 'welcome',
              redirect: (context, state) => state.extra is FootbagPlayer
                  ? loggedOutRedirect(context, state)
                  // Reached without a profile in hand (a reload, a typed
                  // URL): there is nothing to welcome, so go home.
                  : '/rooms/feed',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                WelcomePage(me: state.extra! as FootbagPlayer),
              ),
            ),
            GoRoute(
              path: 'club/new',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const ClubForm()),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'club/:clubid',
              redirect: (context, state) {
                final id = state.pathParameters['clubid'];
                if (id == null || int.tryParse(id) == null) {
                  return '/rooms/discover';
                }
                return loggedOutRedirect(context, state);
              },
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                ClubPage(
                  key: ValueKey(state.pathParameters['clubid']),
                  clubId: int.parse(state.pathParameters['clubid']!),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ClubForm(
                      club: state.extra is FootbagClub
                          ? state.extra as FootbagClub
                          : null,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            GoRoute(
              path: 'session/:sessionid',
              redirect: (context, state) {
                final id = state.pathParameters['sessionid'];
                if (id == null || int.tryParse(id) == null) {
                  return '/rooms/dash';
                }
                return loggedOutRedirect(context, state);
              },
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                SessionPage(
                  key: ValueKey(state.pathParameters['sessionid']),
                  sessionId: int.parse(state.pathParameters['sessionid']!),
                ),
              ),
            ),
            GoRoute(
              path: 'feed',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Feed()),
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    Compose(
                      sessionId: state.extra as int?,
                      // "I landed it" on a trick's page: ?landed=slug&name=Name
                      landed: switch (state.uri.queryParameters) {
                        {'landed': final slug, 'name': final name} && final q =>
                          (slug: slug, name: name, first: q['first'] == '1'),
                        _ => null,
                      },
                      // The welcome's "introduce yourself": ?caption=...
                      caption: state.uri.queryParameters['caption'],
                      // A challenge's Enter button: ?challenge=slug
                      challengeSlug: state.uri.queryParameters['challenge'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'tag',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        TrickPicker(
                          alreadyHave:
                              (state.extra as Set<String>?) ?? const {},
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                ),
                // A sibling of the picker, not its child: a child route would
                // rebuild the picker's page with this one's extra.
                GoRoute(
                  path: 'suggest-trick',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    SuggestTrick(
                      initialName: state.extra is String
                          ? state.extra as String
                          : '',
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'post/:postid',
                  // tryParse and redirect, as for reports: a malformed link
                  // should not match rather than throw during build.
                  redirect: (context, state) {
                    final id = state.pathParameters['postid'];
                    if (id == null || int.tryParse(id) == null) {
                      return '/rooms/feed';
                    }
                    return loggedOutRedirect(context, state);
                  },
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    PostPage(
                      postId: int.parse(state.pathParameters['postid']!),
                      initial: state.extra is FootbagPost
                          ? state.extra as FootbagPost
                          : null,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'player/:userid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    PlayerPage(
                      userId: state.pathParameters['userid']!,
                      name: state.extra is String
                          ? state.extra as String
                          : null,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'challenge/:slug',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    Feed(
                      key: ValueKey(
                        'challenge-${state.pathParameters['slug']}',
                      ),
                      challengeSlug: state.pathParameters['slug'],
                      challengeTitle: state.extra is String
                          ? state.extra as String
                          : null,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'trick/:slug',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    Feed(
                      key: ValueKey(state.pathParameters['slug']),
                      entrySlug: state.pathParameters['slug'],
                      entryName: state.extra is String
                          ? state.extra as String
                          : state.pathParameters['slug'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            GoRoute(
              path: 'discover',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Discover()),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'dash',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                Dash(
                  // A new key per request, or go_router reuses the State and
                  // a second [+] from another tab would start nothing.
                  key: state.extra == 'start' ? UniqueKey() : null,
                  startNow: state.extra == 'start',
                ),
              ),
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'inbox',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const InboxPage()),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'mod',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const ModQueue()),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'moderators',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const ModeratorsPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'tricks',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const PendingTricksPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'places',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const PendingPlacesPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                ),
                GoRoute(
                  path: 'rankings',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const Rankings()),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'profile',
                  pageBuilder: (context, state) =>
                      defaultPageBuilder(context, state, const ProfilePage()),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'schedule',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    NewSession(
                      clubId: state.extra is int ? state.extra as int : null,
                    ),
                  ),
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
                GoRoute(
                  path: ':sessionid/goals',
                  redirect: (context, state) {
                    final id = state.pathParameters['sessionid'];
                    if (id == null || int.tryParse(id) == null) {
                      return '/rooms/dash';
                    }
                    return loggedOutRedirect(context, state);
                  },
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    GoalsPage(
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
