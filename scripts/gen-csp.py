#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026-Present New York Footbag Association
#
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate the Content-Security-Policy for the built web bundle.

Flutter emits its bootstrap as a large inline <script> in index.html, so a
script-src without 'unsafe-inline' blocks it and the app never starts. The
content of that script changes on every build (it embeds the service worker
version and build config), so a hash committed to the repo would silently
break the next rebuild.

This hashes whatever inline scripts the build actually produced and writes an
nginx snippet defining $csp. Run after `flutter build web`; the output is
included from nginx.conf.
"""

import base64
import hashlib
import pathlib
import re
import sys

HOMESERVER = "https://chat.footbagsocial.com"

# Derived, never written out again. The websocket origin used to be a second
# literal further down, and the two are only ever correct together -- one
# homeserver move leaves the app loading fine while every sync is blocked by
# CSP, which looks like a server fault rather than a policy one.
HOMESERVER_WS = HOMESERVER.replace("https://", "wss://", 1)

# Self-hosted Plausible. It needs script-src to load the script and
# connect-src to POST events; without both the analytics silently do nothing.
ANALYTICS = "https://stats.korroni.com"

# CanvasKit's font system fetches Roboto and the Noto fallback chain from
# Google at runtime, for glyphs outside the bundled font. --no-web-resources-cdn
# bundles CanvasKit and a local Roboto but does NOT stop this; the engine still
# reaches for fonts.gstatic.com. Blocking it leaves the app with no font data at
# all, so it renders its layout and images and draws no text whatsoever.
#
# This was shipped broken once. It passed review because the browser doing the
# checking had the fonts cached from earlier builds -- warm cache rendered fine,
# cold cache showed a textless page. Verify font changes in a cold context.
FONTS = "https://fonts.gstatic.com"

# Everything is same-origin except the homeserver: media and avatars are
# fetched from it, and it is the only host the app may talk to. connect-src is
# the directive that matters here -- the access token and E2EE keys live in
# IndexedDB, and the build pulls third-party JS (native_imaging) into this
# origin, so this is what stops either being posted elsewhere.
#
# About script-src, honestly: 'unsafe-eval' is here because dart2js output
# calls eval() and the app renders a blank page without it -- verified by
# toggling it on a built image. 'wasm-unsafe-eval' stays because CanvasKit
# compiles WebAssembly; it is narrower and not implied by 'unsafe-eval'.
#
# That makes script-src the weakest directive in this policy, which is
# tolerable here: CanvasKit paints to a canvas rather than the DOM, so a
# hostile Matrix message is not a DOM-XSS vector. The directives doing real
# work are connect-src, object-src, base-uri and form-action. Escaping
# 'unsafe-eval' would mean compiling to WASM instead of dart2js -- a separate
# piece of work, not a config tweak.
#
# blob: workers and inline styles are likewise Flutter requirements.
def policy(script_hashes: list[str]) -> str:
    sources = " ".join(
        ["'self'", "'wasm-unsafe-eval'", "'unsafe-eval'", ANALYTICS, *script_hashes]
    )
    return "; ".join(
        [
            "default-src 'self'",
            f"script-src {sources}",
            "worker-src 'self' blob:",
            "style-src 'self' 'unsafe-inline'",
            f"font-src 'self' data: {FONTS}",
            f"img-src 'self' data: blob: {HOMESERVER}",
            f"media-src 'self' data: blob: {HOMESERVER}",
            f"connect-src 'self' {HOMESERVER} {HOMESERVER_WS} {ANALYTICS} {FONTS}",
            "base-uri 'self'",
            "form-action 'self'",
            "object-src 'none'",
            "frame-ancestors 'self'",
        ]
    )


def main() -> int:
    # Every HTML page that nginx serves with this policy, not just index.html.
    # auth.html is the one that bites: it is the SSO callback, and its inline
    # script is the whole page -- it posts the login token back to the opener
    # and closes the window. Hash only index.html and the policy silently
    # blocks it, the popup sits there reading "Authentication is complete",
    # and the token is never exchanged, which looks like a broken homeserver.
    *inputs, target = sys.argv[1:]
    out = pathlib.Path(target)

    inline: list[str] = []
    for path in inputs:
        p = pathlib.Path(path)
        if not p.exists():
            print(f"gen-csp: {p} does not exist", file=sys.stderr)
            return 1
        found = [
            m.group(1)
            for m in re.finditer(
                r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>",
                p.read_text(encoding="utf-8"),
                re.S | re.I,
            )
        ]
        # Each input must contribute, or a page is being served under a policy
        # that was never checked against it.
        if not found:
            print(
                f"gen-csp: no inline <script> found in {p} — refusing to emit "
                "a CSP that has not been verified against the real bundle",
                file=sys.stderr,
            )
            return 1
        print(f"gen-csp: {p.name}: {len(found)} inline script(s)")
        inline.extend(found)

    hashes = [
        "'sha256-"
        + base64.b64encode(hashlib.sha256(s.encode("utf-8")).digest()).decode()
        + "'"
        for s in inline
    ]

    out.write_text(f'set $csp "{policy(hashes)}";\n', encoding="utf-8")
    print(f"gen-csp: hashed {len(hashes)} inline script(s) -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
