// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:footbag_network/config/nyfa_theme.dart';
import 'package:footbag_network/config/setting_keys.dart';
import 'package:footbag_network/l10n/l10n.dart';
import 'package:footbag_network/pages/intro/flows/restore_backup_flow.dart';
import 'package:footbag_network/utils/platform_infos.dart';
import 'package:footbag_network/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The first screen anyone sees, matching newyorkfootbag.com.
///
/// It does not use LoginScaffold: that centres a Material card on a gradient
/// behind an animated particle field, which is a different product's look.
/// This is the club's -- near-black ground, Bebas Neue set large in caps, and
/// the name lit from behind in the club green.
///
/// Tokens are the app's shared [Nyfa] set. They began as the site's own
/// (nyfa-business globals.css, .dark); secondary text has since been lifted
/// for legibility, so this page no longer keeps a private copy of the old
/// values.

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
      backgroundColor: Nyfa.ground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Nyfa.muted),
        title: addMultiAccount
            ? Text(
                L10n.of(context).addAccount,
                style: Nyfa.heading,
              )
            : null,
        actions: [_menu(context)],
      ),
      body: SafeArea(
        child: isLoading
            ? const _Loading()
            : _Content(welcomeText: welcomeText, login: login),
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
  const _Loading();

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
            valueColor: AlwaysStoppedAnimation(Nyfa.green),
          ),
        ),
        // Not "logging in to <host>": the host is ours, the person never chose
        // it, and naming it only raises a question they cannot act on.
        Text(
          L10n.of(context).signingIn,
          style: const TextStyle(color: Nyfa.muted, fontFamily: Nyfa.body),
        ),
      ],
    ),
  );
}

class _Content extends StatelessWidget {
  final String? welcomeText;
  final VoidCallback login;

  const _Content({required this.welcomeText, required this.login});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final name = AppSettings.applicationName.value.toUpperCase().split(' ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 640;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                  child: Column(
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .center,
                    children: [
                      _Wordmark(words: name, compact: short),
                      SizedBox(height: short ? 20 : 28),
                      Text(
                        welcomeText ?? l10n.appDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Nyfa.muted,
                          fontFamily: Nyfa.body,
                          fontSize: 15.5,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: short ? 28 : 40),
                      _GoogleButton(onPressed: login),
                      const SizedBox(height: 18),
                      // Said before the click. Finding out you are held for
                      // approval only after signing in reads as a fault
                      // rather than as how the club works.
                      Text(
                        l10n.newAccountsAreApproved,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Nyfa.muted,
                          fontFamily: Nyfa.body,
                          fontSize: 12.5,
                          height: 1.5,
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

/// The name, stacked and lit from behind.
///
/// newyorkfootbag.com sets its title in Bebas caps on stacked lines, each line
/// scaled to span the full width, with the club green on one of them, glowing.
/// Same here, with the last word carrying the colour.
///
/// Each line is a FittedBox rather than a chosen font size. A size computed
/// from the viewport is wrong the moment the text sits in a narrower column --
/// which is exactly what happened: 112pt picked from a 1512px screen inside a
/// 440px column broke FOOTBAG across two lines as "FOOTB / AG". Scaling a
/// single unwrappable line to the width it actually has cannot do that, and it
/// is also what makes the lines flush like the site's.
class _Wordmark extends StatelessWidget {
  final List<String> words;
  final bool compact;
  const _Wordmark({required this.words, required this.compact});

  @override
  Widget build(BuildContext context) {
    final last = words.length - 1;

    return Stack(
      alignment: Alignment.center,
      children: [
        // A wide, very soft radial rather than a shadow on the glyphs: on the
        // site the light comes off the letters and falls on the ground behind
        // them.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.85,
                  colors: [
                    Nyfa.green.withValues(alpha: 0.17),
                    Nyfa.green.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 0.75],
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            for (var i = 0; i < words.length; i++)
              FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  words[i],
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: Nyfa.display,
                    // Nominal only -- FittedBox rescales it to the real width.
                    fontSize: compact ? 72 : 96,
                    height: 0.92,
                    color: i == last ? Nyfa.green : Nyfa.paper,
                    shadows: i == last
                        ? [
                            Shadow(
                              color: Nyfa.green.withValues(alpha: 0.55),
                              blurRadius: 34,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Google's dark sign-in button.
///
/// Kept to Google's shape and proportions rather than restyled to the club's:
/// a sign-in button that does not look like the one people have seen a
/// thousand times reads as a phishing page, which is the one impression this
/// screen cannot afford. Google publishes a dark variant, so it sits on a
/// near-black ground without either side having to give way.
class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFF131314),
        foregroundColor: const Color(0xFFE3E3E3),
        side: const BorderSide(color: Color(0xFF8E918F)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          Image.asset('assets/google-g.png', width: 20, height: 20),
          const SizedBox(width: 12),
          Text(
            L10n.of(context).continueWithGoogle,
            style: const TextStyle(
              fontFamily: Nyfa.body,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}
