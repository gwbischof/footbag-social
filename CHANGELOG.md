<!--
SPDX-FileCopyrightText: 2026-Present New York Footbag Association

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Changelog

Footbag Social is a fork of [FluffyChat](https://github.com/krille-chan/fluffychat),
taken at FluffyChat v2.10.0 (commit `bf9ecfa`) in October 2026. Versioning restarts
at 0.1.0 here; for the history of the client before the fork, see
[FluffyChat's changelog](https://github.com/krille-chan/fluffychat/blob/main/CHANGELOG.md).

## Unreleased

- Forked from FluffyChat v2.10.0 and rebranded as Footbag Network.
- Removed the voice/video calling subsystem (LiveKit, WebRTC, CallKit).
- Bound the app to the Footbag Network homeserver.
- Renamed to Footbag Social wherever the name is shown. Bundle ids, URL
  schemes and the iOS share-extension target keep their old internal names,
  since changing those would break installs and store listings.
