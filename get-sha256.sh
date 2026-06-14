#!/bin/bash
# Read the official SHA256 for the Decrediton Linux AppImage from the GPG-signed
# release manifest published in the decred-binaries release.
#
# The signature is verified against Decred's release signing key, so the hash you
# paste into the Flatpak manifest is proven to come from Decred — not just from
# whatever GitHub happened to serve. The Flatpak build then enforces that same
# hash forever via the `sha256` field.
#
# Usage:
#   ./get-sha256.sh [VERSION]        # e.g. ./get-sha256.sh v2.1.5  (default: latest)
#   ./get-sha256.sh v2.1.5 --download  # also download the AppImage and re-hash it
#   NO_GPG=1 ./get-sha256.sh ...      # skip signature check (NOT recommended)
set -euo pipefail

REPO="decred/decred-binaries"

# Decred release signing key — https://docs.decred.org/advanced/verifying-binaries/
DECRED_FPR="FD13B6835E248FAF4BD1838D6DF634AA7608AF04"
KEYSERVERS=("hkps://keys.openpgp.org" "hkps://keyserver.ubuntu.com")

# Resolve version: explicit arg, or the latest published release tag.
VERSION="${1:-}"
if [[ -z "$VERSION" || "$VERSION" == --* ]]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | cut -d'"' -f4)
  echo "Latest release: $VERSION"
fi

ASSET="decrediton-linux-amd64-${VERSION}.AppImage"
MANIFEST="decrediton-${VERSION}-manifest.txt"
BASE="https://github.com/${REPO}/releases/download/${VERSION}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Fetching $MANIFEST and signature ..."
curl -fsSL -o "$work/manifest.txt" "${BASE}/${MANIFEST}"
curl -fsSL -o "$work/manifest.asc" "${BASE}/${MANIFEST}.asc"

verify_signature() {
  command -v gpg >/dev/null 2>&1 || { echo "  ! gpg not installed"; return 1; }

  export GNUPGHOME="$work/gnupg"
  mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"

  local fetched=0
  for ks in "${KEYSERVERS[@]}"; do
    if gpg --batch --quiet --keyserver "$ks" --recv-keys "$DECRED_FPR" 2>/dev/null; then
      fetched=1; break
    fi
  done
  [[ "$fetched" == 1 ]] || { echo "  ! could not fetch key $DECRED_FPR from a keyserver"; return 1; }

  # Verify the detached signature and confirm it was made by the pinned key.
  if gpg --batch --status-fd=1 --verify "$work/manifest.asc" "$work/manifest.txt" 2>/dev/null \
       | grep -q "VALIDSIG.*${DECRED_FPR}"; then
    return 0
  fi
  echo "  ! signature does NOT match Decred key $DECRED_FPR"
  return 1
}

if [[ "${NO_GPG:-}" == "1" ]]; then
  echo "WARNING: skipping GPG verification (NO_GPG=1)."
elif verify_signature; then
  echo "  ✓ GPG signature verified (Decred Release, $DECRED_FPR)"
else
  echo ""
  echo "ERROR: could not verify the manifest signature." >&2
  echo "Import the key manually and re-run, or set NO_GPG=1 to override:" >&2
  echo "  https://docs.decred.org/advanced/verifying-binaries/" >&2
  exit 1
fi

# Extract the AppImage hash from the (now-verified) manifest.
SHA256=$(awk -v a="$ASSET" '$2 == "*"a || $2 == a {print $1}' "$work/manifest.txt")
[[ -n "$SHA256" ]] || { echo "ERROR: $ASSET not found in manifest." >&2; exit 1; }

if [[ "${1:-}" == "--download" || "${2:-}" == "--download" ]]; then
  echo ""
  echo "Downloading AppImage to re-hash (this is large)..."
  curl -fSL -o "$work/app" "${BASE}/${ASSET}"
  actual=$(sha256sum "$work/app" | awk '{print $1}')
  [[ "$actual" == "$SHA256" ]] && echo "  ✓ download matches manifest" \
    || { echo "  ! MISMATCH: got $actual" >&2; exit 1; }
fi

echo ""
echo "Asset : $ASSET"
echo ""
echo "Paste into org.decred.Decrediton.yaml:"
echo "        url: ${BASE}/${ASSET}"
echo "        sha256: $SHA256"
