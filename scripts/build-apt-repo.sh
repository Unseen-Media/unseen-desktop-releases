#!/usr/bin/env bash
# Build the signed index of the flat APT repository.
#
#   scripts/build-apt-repo.sh <repo-dir> <gpg-key-id>
#
# <repo-dir> is a local mirror of the release tagged `apt`: it must hold an
# `apt/` subdirectory containing the pooled .deb files. Into that same `apt/`
# directory this writes Packages, Packages.gz, Release, Release.gpg, InRelease
# and the public key (unseen-media-archive-keyring.gpg / .asc). The workflow
# then uploads all of it as assets of the `apt` release.
#
# Why this layout. Clients use the flat-repository form of sources.list(5):
#     URIs:   https://github.com/Unseen-Media/unseen-desktop-releases/releases/download
#     Suites: apt/
# apt fetches <URI>/apt/InRelease, and resolves each package's `Filename:`
# (apt/<name>.deb) against <URI> — which is exactly the download URL of a
# GitHub release asset named <name>.deb on the release tagged `apt`. So the
# directory name, the release tag, and the Suite/Codename below must all be
# the same word: apt checks the requested suite against the Release file.
#
# Needs: dpkg-scanpackages (dpkg-dev), gpg, gpgv. Runs on a dev box too — the
# key id can be any key in your keyring, e.g. a throwaway one for testing.
set -euo pipefail

REPO_DIR="${1:?usage: build-apt-repo.sh <repo-dir> <gpg-key-id>}"
KEY_ID="${2:?usage: build-apt-repo.sh <repo-dir> <gpg-key-id>}"
SUITE=apt
KEYRING=unseen-media-archive-keyring

for tool in dpkg-scanpackages gpg gpgv; do
    command -v "$tool" >/dev/null || { echo "$tool missing"; exit 1; }
done

cd "$REPO_DIR"
[ -d "$SUITE" ] || { echo "missing $REPO_DIR/$SUITE/"; exit 1; }
ls "$SUITE"/*.deb >/dev/null 2>&1 || { echo "no .deb files in $REPO_DIR/$SUITE/"; exit 1; }

# Packages — run from the repo root so Filename: comes out as apt/<name>.deb.
# --multiversion keeps every pooled version, so a downgrade stays possible.
dpkg-scanpackages --multiversion "$SUITE" /dev/null > "$SUITE/Packages"
gzip -9 -n -c "$SUITE/Packages" > "$SUITE/Packages.gz"

# Release — written by hand; apt-ftparchive is not installed everywhere.
checksums() {   # $1 = md5sum | sha1sum | sha256sum
    local f
    for f in Packages Packages.gz; do
        printf ' %s %s %s\n' \
            "$("$1" "$SUITE/$f" | cut -d' ' -f1)" "$(stat -c %s "$SUITE/$f")" "$f"
    done
}
{
    echo "Origin: Unseen Media"
    echo "Label: Unseen Media"
    echo "Suite: $SUITE"
    echo "Codename: $SUITE"
    echo "Architectures: amd64"
    echo "Description: Unseen Media desktop client for Debian and Ubuntu"
    echo "Date: $(date -Ru)"
    echo "MD5Sum:";  checksums md5sum
    echo "SHA1:";    checksums sha1sum
    echo "SHA256:";  checksums sha256sum
} > "$SUITE/Release"

# Sign. InRelease (inline signature) is what apt fetches first; Release.gpg
# (detached) is the fallback for older clients.
gpg --batch --yes --local-user "$KEY_ID" --clearsign \
    -o "$SUITE/InRelease" "$SUITE/Release"
gpg --batch --yes --local-user "$KEY_ID" --armor --detach-sign \
    -o "$SUITE/Release.gpg" "$SUITE/Release"

# The public key: binary for Signed-By:, armored for humans.
gpg --batch --yes --export "$KEY_ID" > "$SUITE/$KEYRING.gpg"
gpg --batch --yes --armor --export "$KEY_ID" > "$SUITE/$KEYRING.asc"

# Self-check: the index verifies against nothing but the exported keyring,
# which is all a client machine will have.
if ! gpgv --keyring "$PWD/$SUITE/$KEYRING.gpg" "$SUITE/InRelease" 2>/dev/null; then
    echo "InRelease does not verify against $SUITE/$KEYRING.gpg"; exit 1
fi
if ! gpgv --keyring "$PWD/$SUITE/$KEYRING.gpg" "$SUITE/Release.gpg" "$SUITE/Release" 2>/dev/null; then
    echo "Release.gpg does not verify against $SUITE/$KEYRING.gpg"; exit 1
fi

echo "index built in $REPO_DIR/$SUITE/:"
grep -E '^(Package|Version|Filename):' "$SUITE/Packages" | paste - - - | sed 's/^/  /'
