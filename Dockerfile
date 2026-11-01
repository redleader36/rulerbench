# syntax=docker/dockerfile:1
# SPDX-License-Identifier: AGPL-3.0-only
#
# Rulerbench — a self-hosted container of ScanRuler (https://github.com/CNCKitchen/scanruler),
# an unmodified build of the upstream source, packaged by redleader36.
#
# ScanRuler is Copyright (c) Stefan Hermann / CNC Kitchen and licensed AGPL-3.0-only.
# This packaging adds no source changes; see NOTICE for the full attribution.
#
# Build from a checkout of the upstream source (build.sh does this for you):
#   docker build -t rulerbench:local .
#
# Node 22 is upstream's own floor (package.json "engines"), and the same major
# version upstream's CI builds with — a build on a different major is a build
# nobody has tested.

FROM node:22-alpine AS build
WORKDIR /src

# Dependency layer first: re-installing is only needed when the lockfile moves.
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

# Vite gives a variable already present in the environment priority over .env,
# so this overrides the upstream default (https://files.scanruler.com/) for the
# short-link file store. Empty means "no store": the app keeps working, the
# /s/<name> links simply have nothing to resolve against.
ARG VITE_FILES_URL=https://files.scanruler.com/
ENV VITE_FILES_URL=${VITE_FILES_URL}

# tsc --noEmit && vite build, exactly as upstream's CI runs it.
RUN npm run build

# The runtime is a static file server with no script of its own — upstream
# deploys the app the same way (a Cloudflare Worker serving ./dist). The
# unprivileged nginx image listens on 8080 as a non-root user, which is also
# what a container should do.
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

ARG VERSION=dev
ARG UPSTREAM_COMMIT=unknown
LABEL org.opencontainers.image.title="rulerbench" \
      org.opencontainers.image.description="Self-hosted ScanRuler build, packaged as a container (unmodified upstream source)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/redleader36/rulerbench" \
      org.opencontainers.image.url="https://github.com/CNCKitchen/scanruler" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.revision="${UPSTREAM_COMMIT}"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html

# The licences the shipped bytes are under travel with the bytes: upstream's
# AGPL text, the third-party notices, and the OCCT build that the Reverse
# engineer workspace loads as a separate, replaceable file.
COPY LICENSE NOTICE /usr/share/doc/rulerbench/
COPY --from=build /src/LICENSE /usr/share/doc/rulerbench/LICENSE-upstream

USER 101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1

STOPSIGNAL SIGQUIT
