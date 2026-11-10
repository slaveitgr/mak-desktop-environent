# Native menu-bar branding

This patch adds an optional `MenuBar/BrandIcon` absolute image path to the
session's `~/.config/cutefish/shell.conf`. It affects only the leftmost native
menu-bar entry. The image keeps its aspect ratio and transparency, without the
avatar's circular mask or account-colour disc. The existing account avatar is
used when no path is configured, the file is missing, or decoding fails.
AccountsService and the user's actual account picture remain unchanged.

The setting is read at session creation. The entry keeps its existing 16-pixel
icon geometry and native menu actions. This does not implement a macOS system
menu or establish visual/animation parity.

The pinned ISO includes the `CutefishToolkit` and `CutefishClients` CMake
targets, headers and libraries. CI adds Debian development packages, downloads
the exact compositor commit recorded in `source.json`, verifies its archive
size and SHA256, applies the patch without fuzzy matching, and builds the
native compositor. Existing headless native-session tests then run against
that binary. A build provenance report is saved under `/etc/makos` and in the
CI validation artifact. The original ISO remains available as the baseline.

This development image overrides `/usr/bin/cutefish-compositor`; the upstream
dpkg package version is unchanged. Reinstalling or upgrading that package can
replace the patch. A separately versioned distribution package is future work.
No runtime interception, executable byte patching, host installation, or
account-picture replacement is performed.

The CI user's path refers to the temporary checkout. Image finalization seeds
new live/installed users with
`/opt/makos/installer/branding/makos-ck-symbol.svg`. The separate opaque boot
PNG is not used in the translucent native menu bar.

Upstream source and patch context are governed by the compositor's
[BSD-3-Clause license](https://github.com/cutefishos/cutefish-compositor/blob/0e709136bd7056136e74e981acffc4b88d659e0b/LICENSE).
Local syntax/patch application checks do not substitute for the Linux build,
native rendering inspection, or an actual laptop boot.
