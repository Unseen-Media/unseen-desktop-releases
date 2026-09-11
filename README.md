# Unseen Media — Desktop Downloads

Installers for the Unseen Media desktop app (Windows and Linux).

## Windows

- **[Download the installer](https://github.com/Unseen-Media/unseen-desktop-releases/releases/latest/download/UnseenMedia-Setup.exe)** — recommended. Installs, and updates itself on the next launch.
- **[Portable build](https://github.com/Unseen-Media/unseen-desktop-releases/releases/latest/download/UnseenMedia-win64.zip)** — no install; unzip and run.

You only install once — Windows updates itself from then on.

## Linux (Ubuntu, Linux Mint, Pop!_OS, Debian 12+)

- **[Download the .deb](https://github.com/Unseen-Media/unseen-desktop-releases/releases/latest/download/UnseenMedia-linux-amd64.deb)** and open it, or from a terminal:

  ```bash
  sudo apt install ./UnseenMedia-linux-amd64.deb
  ```

You only install once here too. The package registers the Unseen Media APT
repository on your machine, so new versions arrive through your normal
software updater (Software Updater on Ubuntu, Update Manager on Mint, the
Pop!_OS updater) alongside everything else. If you installed a version older
than **2.6.8**, install the current .deb by hand one more time to pick this up.

To opt out, set `manage_apt_repo="false"` in `/etc/default/unseen-media`.

<details>
<summary>Add the repository by hand instead</summary>

```bash
sudo curl -fsSL -o /usr/share/keyrings/unseen-media-archive-keyring.gpg \
  https://github.com/Unseen-Media/unseen-desktop-releases/releases/download/apt/unseen-media-archive-keyring.gpg
sudo curl -fsSL -o /etc/apt/sources.list.d/unseen-media.sources \
  https://github.com/Unseen-Media/unseen-desktop-releases/releases/download/apt/unseen-media.sources
sudo apt update && sudo apt install unseen-media
```

The repository is a flat one: its index and the newest few `.deb` files are
the assets of the release tagged **`apt`**, rebuilt by the *APT repository*
workflow every time a desktop release is published. That release is not a
version of the app — don't delete it.
</details>

## On Android?

The Android app has its own downloads page: **[Unseen-Media/unseen-android-releases](https://github.com/Unseen-Media/unseen-android-releases/releases)**. Or open the desktop app's **Settings → Android app** and scan the QR code.

---

Desktop releases are tagged **`v…`**. Every version — installer, portable zip
and .deb — is on the [Releases page](https://github.com/Unseen-Media/unseen-desktop-releases/releases).
The one tagged `apt` is the Linux package repository (see above).
