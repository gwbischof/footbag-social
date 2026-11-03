<!--
SPDX-FileCopyrightText: 2019-Present Christian Kußowski
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
SPDX-FileCopyrightText: 2026-Present New York Footbag Association

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Footbag Social

**The app for people who play footbag.** Find a circle near you, log what you
worked on, see what everyone else is landing, and talk about it, all in one
place instead of scattered across Instagram, a forum and a dozen group chats.

Footbag is a small, global, obsessive sport. The hardest part of it isn't the
tricks; it's finding someone to play with. Footbag Social is built around that.

## What it does

- **Sessions.** Start one in a tap and the clock runs. Check in while you play,
  stop when you're done, and the time counts to your last check-in, so a
  forgotten timer can't invent hours. Schedule one ahead and let people ask
  to join.
- **Progress, the way footbag works.** After a session, grade each trick on a
  four-rung ladder (tried, footing, hitting, consistent), add counts and mark
  firsts. Set goals for the next one, and get suggestions for what to try
  next, built from what you've already landed.
- **The trick dictionary.** Hundreds of tricks, composites and strings, with
  what each one adds. Anyone can suggest a missing one; moderators approve it.
- **Find players near you.** Discover sessions, players and clubs by discipline
  (kicking, freestyle, net, stitching) and by distance. Locations are shown
  as a circle, never a pin, until the host lets you in.
- **A feed for the sport.** Photos, video and session results from the people
  you play with, tagged by trick, with a page for every trick showing who's
  working on it.
- **Clubs.** A home for your local scene: members, organisers, and sessions.
- **Rankings.** Who has played the most, and your own recent activity at a glance.
- **Chat.** Direct messages and group chats, end-to-end encrypted.

## Status

In active development and live at [footbagsocial.com](https://footbagsocial.com)
on the web. iOS and Android builds come next.

The screens were designed first as [wireframes](docs/wireframes/README.md),
with the reasoning behind each one.

Part of the footbag ecosystem alongside [New York Footbag](https://newyorkfootbag.com)
and the [Modified forum](https://modified.in).

## Attribution

Footbag Social is a **fork of [FluffyChat](https://github.com/krille-chan/fluffychat)**
by Christian Kußowski and contributors — an excellent open-source Matrix client. We
forked it rather than reinventing a Matrix client from scratch. Please consider
[supporting FluffyChat's development](https://de.liberapay.com/KrilleChritzelius).

See [NOTICE](NOTICE) for full attribution and a summary of modifications.

## License

AGPL-3.0-or-later. See [LICENSE](LICENSE).

The source for this app, including all modifications, is at
https://github.com/gwbischof/footbag-social.

**Trademarks.** The names "Footbag Social" and "NYFA", and their logos, are
trademarks of the New York Footbag Association. The AGPL grants you rights to the
code, not to the branding — if you distribute a derivative, use your own name and
logo.

## How to build

Requires [Flutter](https://flutter.dev) **3.47.4 or newer** — the project needs
Dart >= 3.11.1 and fails to resolve dependencies on older SDKs. The exact version
is pinned in `.fvmrc`, so the simplest setup is [fvm](https://fvm.app):

```bash
git clone https://github.com/gwbischof/footbag-social.git
cd footbag-social
fvm use            # installs the pinned Flutter, leaves your global one alone
fvm flutter pub get
```

Prefix commands with `fvm` (`fvm flutter`, `fvm dart`) so they use the pinned SDK.
If your system Flutter is already new enough, drop the prefix.

### Web

The web build compiles the Vodozemac crypto library to WASM from Rust, so this
step needs [Rust](https://www.rust-lang.org/tools/install) and `yq`:

```bash
./scripts/prepare-web.sh   # builds Vodozemac WASM (required)
fvm flutter build web --release
```

Run locally with `fvm flutter run -d chrome`.

To skip the toolchain entirely, build the container instead — it installs
everything and is what CI runs:

```bash
docker build -t footbag-social .
docker run --rm -p 8080:8080 footbag-social
```

Optionally configure by serving a `config.json` alongside the app — see
`config.sample.json`. Only include the keys you actually want to override.

### Android

```bash
flutter build apk
```

### iOS / iPadOS

Requires a Mac with Xcode set up for app signing. See `scripts/build-ios.sh`.

### Desktop (Linux, Windows, macOS)

[Enable desktop support](https://flutter.dev/desktop) in Flutter, then:

```bash
flutter build linux --release    # or windows / macos
```

On Linux you'll also need:

```bash
sudo apt install libjsoncpp1 libsecret-1-dev libsecret-1-0 librhash0 libwebkit2gtk-4.0-dev lld
```

## Configuration and Mobile Device Management (MDM)

Configurable via MDM on Android and iOS, and via a `config.json` file on web. The
Android MDM schema is at `android/app/src/main/res/xml/app_restrictions.xml`.

## Integration tests

Requires Docker. Run the preparation script before each test run:

```bash
./scripts/prepare_integration_test.sh
flutter test integration_test/mobile_test.dart
```

## Special thanks

- **FluffyChat** and its contributors, for the client this is built on.
- [Fabiyamada](https://github.com/fabiyamada), who designed FluffyChat's original
  logo and banner.
- FluffyChat's translators and testers, whose work this fork inherits.
- The Matrix Foundation, for the
  [emoji translations](https://github.com/matrix-org/matrix-spec/blob/main/data-definitions/sas-emoji.json)
  used in emoji verification (Apache 2.0).
