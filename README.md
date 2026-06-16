# Decrediton Flatpak

Flatpak packaging for [Decrediton](https://github.com/decred/decrediton), the
official Decred (DCR) desktop wallet. It repackages the upstream AppImage — no
compilation of the app itself is required.

- **App:** Decrediton **v2.1.5**
- **Runtime:** `org.freedesktop.Platform` **25.08**
- **Electron sandbox:** [zypak](https://github.com/refi64/zypak) v2025.09
- **Arch:** x86_64 only (the only Linux build upstream ships)

## Repository layout

| File | Purpose |
|------|---------|
| `org.decred.Decrediton.yaml` | Flatpak manifest |
| `org.decred.Decrediton.metainfo.xml` | AppStream metadata (screenshots, releases) |
| `org.decred.Decrediton.desktop` | Desktop entry |
| `org.decred.Decrediton.svg` | Application icon (scalable) |
| `flathub.json` | Flathub build config — restricts to x86_64 |
| `get-sha256.sh` | Reads the AppImage SHA256 from the signed release manifest |

## Build & run

Install the runtime once, then build:

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08

flatpak-builder --user --install --force-clean build-dir org.decred.Decrediton.yaml
flatpak run org.decred.Decrediton
```

No local `flatpak-builder`? Use the packaged one: replace `flatpak-builder` with
`flatpak run org.flatpak.Builder`.

## Validate

```bash
flatpak run --command=appstreamcli org.flatpak.Builder validate org.decred.Decrediton.metainfo.xml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest org.decred.Decrediton.yaml
desktop-file-validate org.decred.Decrediton.desktop
```

## Update to a new version

```bash
./get-sha256.sh            # latest release, or pass a tag e.g. v2.1.6
```

`get-sha256.sh` downloads Decred's **GPG-signed** release manifest, verifies the
signature against the Decred release key
(`FD13 B683 5E24 8FAF 4BD1 838D 6DF6 34AA 7608 AF04`), and only then prints the
`url` + `sha256` to paste into `org.decred.Decrediton.yaml`. It fails closed: a
bad or missing signature prints no hash. Also add a `<release>` entry to the
metainfo.

The manifest carries `x-checker-data`, so once the app is on Flathub the
[flatpak-external-data-checker](https://github.com/flathub-infra/flatpak-external-data-checker)
bot can open update PRs automatically — but that bot hashes the file without
checking the signature, so run `./get-sha256.sh <version>` to validate such a PR
before merging.

## Submit to Flathub

Flathub takes new apps as a pull request to the
[`flathub/flathub`](https://github.com/flathub/flathub) repo's **`new-pr`** branch:

1. Fork `flathub/flathub` and branch off `new-pr`.
2. Add the manifest and its supporting files (`*.yaml`, `*.metainfo.xml`,
   `*.desktop`, `*.png`, `flathub.json`).
3. Open a PR against `new-pr`. The build bot validates it and maintainers review;
   on approval you get a dedicated `flathub/org.decred.Decrediton` repo to maintain.

See the official [submission guide](https://docs.flathub.org/docs/for-app-authors/submission)
for the authoritative, up-to-date steps.

## Packaging notes

- Electron runs through **zypak**, so the setuid `chrome-sandbox` helper is removed
  and the app uses the Flatpak sandbox instead.
- Launched with `--ozone-platform-hint=auto` for native Wayland (X11 fallback).
- Permissions are kept minimal: network (sync/SPV), Wayland + fallback X11, GPU
  (`dri`), PulseAudio, desktop notifications, screensaver inhibition, and the
  Downloads folder for transaction (CSV) exports. No broad session-bus, home, or
  dconf access is granted.
- **Integrity vs. authenticity:** the build's trust anchor is the `sha256` pin,
  which flatpak-builder enforces on the downloaded AppImage. GPG signature
  checking is deliberately *not* done inside the build — Flathub's builders are
  network-isolated and a repo-vendored key would be circular trust. Authenticity
  is instead established when a maintainer bumps the version, via the GPG check in
  `get-sha256.sh`.

## License

Decrediton is ISC-licensed; this packaging follows the same license.
