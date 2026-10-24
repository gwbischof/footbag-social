# SPDX-FileCopyrightText: 2019-Present Christian Kußowski
# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Pinned by digest: this image compiles the E2EE crypto, so "whatever
# ubuntu:26.04 points at today" is not a good enough description of it.
FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7 AS builder
RUN apt-get update && apt-get install -y curl wget git unzip xz-utils jq build-essential pkg-config libssl-dev ca-certificates python3

ARG TARGETARCH
WORKDIR /tmp
RUN wget https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_${TARGETARCH}.tar.gz \
 && tar -xzf ./yq_linux_${TARGETARCH}.tar.gz \
 && mv yq_linux_${TARGETARCH} /usr/bin/yq

# Install the Flutter version defined in .tool_versions.yaml
WORKDIR /app
COPY .tool_versions.yaml /app/
RUN git clone --depth 1 --branch "$(yq '.environment.flutter' .tool_versions.yaml)" \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter precache --web

# Rust builds Vodozemac (the Olm/Megolm implementation) to WebAssembly. The
# wasm build needs -Z build-std, which is nightly-only -- but an undated
# "nightly" means the compiler for our crypto changes daily and silently.
ARG RUST_NIGHTLY=nightly-2026-10-01
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --default-toolchain "${RUST_NIGHTLY}"
ENV PATH="/root/.cargo/bin:${PATH}"
ENV RUST_NIGHTLY=${RUST_NIGHTLY}
RUN rustup component add rust-src --toolchain "${RUST_NIGHTLY}" \
 && rustup default "${RUST_NIGHTLY}"

COPY . /app
RUN ./scripts/prepare-web.sh
RUN flutter pub get --enforce-lockfile
# --no-web-resources-cdn is load-bearing, not an optimisation. Without it
# Flutter loads CanvasKit -- the rendering engine -- from gstatic.com at
# runtime, so Google sees every visitor and the app cannot start if that CDN
# is unreachable. The FLUTTER_WEB_CANVASKIT_URL dart-define that used to be
# here did not actually set canvasKitBaseUrl, so the CDN was being used
# regardless; this flag sets useLocalCanvasKit and serves the copy we already
# ship in build/web/canvaskit/.
RUN flutter build web --no-web-resources-cdn --release --source-maps
RUN python3 scripts/gen-csp.py build/web/index.html build/web/auth.html /csp.conf

# Unprivileged variant so the pod can run as non-root; it listens on 8080.
FROM docker.io/nginxinc/nginx-unprivileged:alpine@sha256:b9241c6e7b8e9a862f129d8d4199ab64b10390949a78bdd5603379b32c844083
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /csp.conf /etc/nginx/csp.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 8080
