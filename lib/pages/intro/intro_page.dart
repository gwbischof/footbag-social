// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/intro/flows/restore_backup_flow.dart';
import 'package:footbag_network/utils/platform_infos.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The first screen anyone sees.
///
/// It does not use LoginScaffold. That one centres a Material card on a
/// gradient behind an animated particle field -- a generic tech motif with
/// nothing to do with footbag, and it would compete with the one image worth
/// looking at. Here the painted bag is the whole hero and everything else is
/// type.
///
/// The palette is deliberately local rather than taken from the seeded theme:
/// this screen is lit like the illustration it carries (ink ground, cream
/// type, gold accent) while the app proper stays green.
class _Ink {
  static const ground = Color(0xFF14181A); // cold near-black, from the hatching
  static const paper = Color(0xFFE8E4D2); // the panel wash
  static const muted = Color(0xFF93A3A1); // the teal, pulled down
  static const gold = Color(0xFFD4A843); // the single accent
  static const glow = Color(0xFF2E8B2E); // the brand green, only ever diffuse
  static const teal = Color(0xFF7FB3AC); // the cool panels, only in the glow
}

class IntroPage extends StatelessWidget {
  final bool isLoading, hasPresetHomeserver;
  final String? loggingInToHomeserver, welcomeText;
  final VoidCallback login;

  const IntroPage({
    required this.isLoading,
    required this.loggingInToHomeserver,
    super.key,
    required this.hasPresetHomeserver,
    required this.welcomeText,
    required this.login,
  });

  @override
  Widget build(BuildContext context) {
    final addMultiAccount = Matrix.of(
      context,
    ).widget.clients.any((client) => client.isLogged());

    return Scaffold(
      key: const Key('LoginScaffold'),
      backgroundColor: _Ink.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _Ink.muted),
        title: addMultiAccount
            ? Text(
                L10n.of(context).addAccount,
                style: const TextStyle(color: _Ink.paper, fontSize: 16),
              )
            : null,
        actions: [_menu(context)],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: isLoading
            ? _Loading(homeserver: loggingInToHomeserver)
            : _Content(
                welcomeText: welcomeText,
                hasPresetHomeserver: hasPresetHomeserver,
                login: login,
              ),
      ),
    );
  }

  Widget _menu(BuildContext context) => PopupMenuButton(
    useRootNavigator: true,
    itemBuilder: (_) => [
      PopupMenuItem(
        onTap: isLoading ? null : () => restoreBackupFlow(context),
        child: Row(
          mainAxisSize: .min,
          spacing: 12,
          children: [
            const Icon(Icons.import_export_outlined),
            Expanded(
              child: Text(
                L10n.of(context).hydrate,
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        onTap: () => launchUrlString(AppSettings.privacyPolicy.value),
        child: Row(
          mainAxisSize: .min,
          spacing: 12,
          children: [
            const Icon(Icons.privacy_tip_outlined),
            Text(L10n.of(context).privacy),
          ],
        ),
      ),
      PopupMenuItem(
        onTap: () => PlatformInfos.showDialog(context),
        child: Row(
          mainAxisSize: .min,
          spacing: 12,
          children: [
            const Icon(Icons.info_outlined),
            Text(L10n.of(context).about),
          ],
        ),
      ),
    ],
  );
}

class _Loading extends StatelessWidget {
  final String? homeserver;
  const _Loading({required this.homeserver});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: .center,
      spacing: 20,
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(_Ink.gold),
          ),
        ),
        // Deliberately not "logging in to <host>": the host is ours and the
        // person never chose it, so naming it only raises a question.
        Text(
          L10n.of(context).signingIn,
          style: const TextStyle(color: _Ink.muted),
        ),
      ],
    ),
  );
}

class _Content extends StatelessWidget {
  final String? welcomeText;
  final bool hasPresetHomeserver;
  final VoidCallback login;

  const _Content({
    required this.welcomeText,
    required this.hasPresetHomeserver,
    required this.login,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // One measurement drives the whole page: how much room the painting
        // can take without crowding the words underneath it.
        final short = constraints.maxHeight < 680;
        final art = short
            ? constraints.maxHeight * 0.26
            : constraints.maxHeight * 0.34;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                // ~60 characters of body text at this size.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: Column(
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .stretch,
                    children: [
                      SizedBox(height: short ? 16 : 36),
                      _Hero(size: art),
                      SizedBox(height: short ? 28 : 44),
                      Text(
                        AppSettings.applicationName.value,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: _Ink.paper,
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        welcomeText ?? l10n.appDescription,
                        style: const TextStyle(
                          color: _Ink.muted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _GoogleButton(onPressed: login),
                      const SizedBox(height: 16),
                      // Said before the click, not discovered after it. A first
                      // sign-in creates an account that waits for a moderator,
                      // and finding that out only once you are held up reads as
                      // a fault rather than as how the place works.
                      Text(
                        l10n.newAccountsAreApproved,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: _Ink.muted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The painting, lit from behind.
///
/// Three stacked radials at different radii, each blurred past its own edge,
/// so the illustration lifts off the ground with no perceptible boundary --
/// the same treatment the make-a-footbag page uses, so the two read as one
/// product.
class _Hero extends StatelessWidget {
  final double size;
  const _Hero({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            width: size * 1.9,
            height: size * 1.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _Ink.glow.withValues(alpha: 0.13),
                  _Ink.teal.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.75],
              ),
            ),
          ),
        ),
        Image.asset(
          'assets/footbag.webp',
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ],
    ),
  );
}

/// Google's sign-in button: white surface, the four-colour mark, Roboto Medium.
/// Kept to their shape rather than restyled to ours -- a sign-in button that
/// does not look like the one people have seen a thousand times reads as a
/// phishing page, which is the one impression this screen cannot afford.
class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          Image.asset('assets/google-g.png', width: 20, height: 20),
          const SizedBox(width: 14),
          Text(
            L10n.of(context).continueWithGoogle,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    ),
  );
}
