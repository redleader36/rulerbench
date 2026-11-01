# Rulerbench

A self-hosted container of **[ScanRuler](https://github.com/CNCKitchen/scanruler)** — CNC
Kitchen's browser tool for measuring 3D scans (sphere/cylinder/plane fits, deviation from
CAD, wall thickness, reverse engineering).

This repository is **packaging, not a fork of the code**. The image contains an
*unmodified* build of a published upstream release; upstream's own `npm ci && npm run
build` produces the bytes inside it. Each release here is cut by CI the day upstream
tags one, and each image records the upstream version and commit in its labels.

> **Unofficial.** ScanRuler, CNC Kitchen and their logo are trademarks and are not
> licensed under the AGPL; upstream asks forks to use a different name, hence
> *Rulerbench*. Not affiliated with or supported by CNC Kitchen. If you want the
> official hosted app, it is at <https://scanruler.com>.

## Run it

```bash
docker run -d \
  --name rulerbench \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/redleader36/rulerbench:latest
```

Then open <http://your-host:8080>. Everything is client-side: your scans never leave the
browser, and the container serves static files and nothing else. It needs no database, no
volume, no outbound network access at runtime, and holds no state — a scan session lives
in the browser (checkpointed to IndexedDB) and in the `.scanruler` project files you save.

`docker compose`:

```yaml
services:
  rulerbench:
    image: ghcr.io/redleader36/rulerbench:latest
    container_name: rulerbench
    restart: unless-stopped
    ports:
      - "8080:8080"
```

Pin a version rather than `latest` if you care what you get on a restart —
`ghcr.io/redleader36/rulerbench:0.9.4`.

### Unraid

Point a container at the image above, network *bridge*, port `8080` → whatever host port
you prefer. No paths, no variables needed. Put it behind the reverse proxy if it should be
reachable by name; nothing about it requires TLS, but the browser's clipboard and
file-picker APIs behave better in a secure context, so `https://` via the proxy is the
nicer way to live.

### Reverse proxy

The app is a single-page app, so the proxy must pass unknown paths through to it rather
than answer them itself — this container already rewrites any unknown path to
`index.html` (upstream's Worker does the same). If the proxy buffers, raise its response
buffer for the multi-megabyte WASM files, or simply let static files stream.

## Tags

| Tag | Meaning |
| --- | --- |
| `latest` | newest upstream release at the time of the last sync |
| `0.9.4` | that upstream release, immutable |

Architectures: `linux/amd64`, `linux/arm64`.

## How it stays current

`.github/workflows/publish.yml` runs **daily at 06:17 UTC** and on demand (Actions →
Publish → Run workflow). It:

1. asks GitHub for upstream's newest release tag and compares it with [`VERSION`](VERSION);
2. if it moved, downloads that tag's source, runs upstream's `npm ci` / `npm run build`,
   and packages the output;
3. builds and pushes a multi-arch image to GHCR, **smoke-tests it** (`/`, `/healthz`, SPA
   fallback, `application/wasm` content type) before it is announced;
4. commits the new `VERSION`, tags `v<version>`, and writes a release whose notes are the
   upstream release notes plus the image digest and the source archive.

Nothing is built from `main` of upstream — only from an upstream **release tag**, so what
you run is a version its author chose to publish. If upstream moves a tag (it should
not), the recorded commit in the image label is the authority.

To force a rebuild of the current version: Actions → *Publish* → *Run workflow*, tick
`force`. To build a specific tag: put e.g. `v0.9.4` in `version`.

## Build it yourself

```bash
./build.sh              # newest upstream release
./build.sh v0.9.4       # a specific tag
TAG=rulerbench:dev ./build.sh v0.9.4
```

`build.sh` fetches the upstream tag, drops this repo's `Dockerfile` beside it and builds —
the same from-source path documented below, no CI required. Building needs Docker and a
network connection (npm and the upstream tarball); the run does not.

Manual equivalent, from an upstream checkout at the tag you want:

```bash
git clone https://github.com/CNCKitchen/scanruler.git src && cd src
git checkout v0.9.4
cp ../rulerbench/{Dockerfile,nginx.conf,NOTICE,LICENSE} .
docker build -t rulerbench:0.9.4 .
```

## Knobs

| Build arg | Default | What it does |
| --- | --- | --- |
| `VITE_FILES_URL` | `https://files.scanruler.com/` | the file store that `/s/<name>` short links resolve against. Point it at a host you control, or leave it — the app itself does not depend on it |

Set it in CI as a repository **variable** of the same name (Settings → Secrets and
variables → Actions → Variables), or pass `--build-arg` to a local build.

## What is inside

- `Dockerfile` — from-source build (Node 22 → `tsc` + `vite`), output served by
  `nginxinc/nginx-unprivileged` on port 8080 as a non-root user.
- `Dockerfile.release` — CI-only: packages a `dist/` built once on a native runner. Vite's
  output is static and architecture-independent, which is why the arm64 image needs no
  emulated compile.
- `nginx.conf` — SPA fallback, immutable caching for hashed assets, no-cache for
  `index.html`, gzip including `application/wasm`.
- `build.sh` — local build against any upstream tag.
- `NOTICE` — attribution and third-party licences, shipped inside the image at
  `/usr/share/doc/rulerbench`.

Health endpoint: `GET /healthz` → `200 ok`.

## Licence

**AGPL-3.0-only**, as upstream. The packaging here and the images published from it are
covered by the same licence, and running one to serve other people makes its source due to
them: that is this repository plus the upstream release named in the image label, and every
release here attaches that combined source as `rulerbench-<version>-source.tar.gz`. See
[`NOTICE`](NOTICE) for attribution, the trademark position, and the third-party components
(Open CASCADE Technology under LGPL-2.1 with the Open CASCADE exception, the OFL fonts).

Modifying the app is fine under the AGPL — publish your source if you serve it. If you need
to embed it in closed-source software, that is a **commercial licence from CNC Kitchen**
(`stefan@cnckitchen.com`), not from this repository.
