#!/usr/bin/env bash
# Create the key that signs the APT repository, and wire it up. Run once on
# the dev box (and again only to rotate the key — read the note at the end).
#
#   scripts/new-signing-key.sh [path/to/unseen-desktop checkout]
#
# What it does:
#   1. generates a 4096-bit RSA signing key with no expiry and no passphrase
#      (it lives in an Actions secret — that is its protection; an expiry
#      would only break every client's updates silently years from now)
#   2. backs it up to ~/.unseen/apt-signing-key.asc (+ .pub.asc, .fingerprint),
#      next to the Android keystore. Keep that directory safe: without the
#      key the index cannot be re-signed and every Linux install stops
#      updating until it gets a new public key by hand
#   3. stores the private key as the APT_SIGNING_KEY secret on this repo
#   4. if an unseen-desktop checkout is given, writes the public key to its
#      packaging/unseen-media-archive-keyring.asc, so the .deb ships it
#
# Rotating: move ~/.unseen/apt-signing-key.* away, run this again, re-run the
# "APT repository" workflow so the index is re-signed, then cut a desktop
# release so the .deb carries the new public key. Clients still holding the
# old key must install that .deb by hand once — plan for that.
set -euo pipefail

REPO=Unseen-Media/unseen-desktop-releases
DEST="$HOME/.unseen"
DESKTOP="${1:-}"

command -v gpg >/dev/null || { echo "gpg missing"; exit 1; }
command -v gh  >/dev/null || { echo "gh missing (https://cli.github.com)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in — run: gh auth login"; exit 1; }
if [ -n "$DESKTOP" ] && [ ! -d "$DESKTOP/packaging" ]; then
    echo "$DESKTOP does not look like an unseen-desktop checkout (no packaging/)"; exit 1
fi

mkdir -p "$DEST" && chmod 700 "$DEST"
if [ -e "$DEST/apt-signing-key.asc" ]; then
    echo "$DEST/apt-signing-key.asc already exists."
    echo "If you really mean to rotate the key, move it away first (see the header)."
    exit 1
fi

TMP=$(mktemp -d); chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT
export GNUPGHOME="$TMP"

gpg --batch --quiet --gen-key <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: Unseen Media APT Repository
Name-Email: apt@unseen-media.invalid
Expire-Date: 0
%commit
EOF
FPR=$(gpg --batch --with-colons --list-keys | awk -F: '/^fpr/ {print $10; exit}')
[ -n "$FPR" ] || { echo "key generation produced no key"; exit 1; }

gpg --batch --armor --export-secret-keys "$FPR" > "$DEST/apt-signing-key.asc"
gpg --batch --armor --export "$FPR"             > "$DEST/apt-signing-key.pub.asc"
echo "$FPR" > "$DEST/apt-signing-key.fingerprint"
chmod 600 "$DEST"/apt-signing-key.*
echo "key $FPR"
echo "  private: $DEST/apt-signing-key.asc      <- back this up (password manager)"
echo "  public:  $DEST/apt-signing-key.pub.asc"

gh secret set APT_SIGNING_KEY -R "$REPO" < "$DEST/apt-signing-key.asc"
echo "  secret:  APT_SIGNING_KEY set on $REPO"

if [ -n "$DESKTOP" ]; then
    cp "$DEST/apt-signing-key.pub.asc" "$DESKTOP/packaging/unseen-media-archive-keyring.asc"
    echo "  desktop: public key written to $DESKTOP/packaging/unseen-media-archive-keyring.asc — commit it"
fi

cat <<EOF

Next:
  1. Actions -> "APT repository" -> Run workflow (blank tag) on $REPO
     to publish the index signed with this key.
  2. Commit packaging/unseen-media-archive-keyring.asc in unseen-desktop and
     cut a release: that .deb registers the repository on install.
EOF
