# Memory

Notes on why things in this repo are the way they are: context, gotchas and
pending steps that the code and git log don't show. Updated with every commit.
Newest first. Edit an existing entry when a later commit changes the same topic.

---

## 2026-10-09: Dark websites in LibreWolf (de58511)

LibreWolf ships `privacy.resistFingerprinting = true`, which always tells websites
the system is in light mode. `privacy.fingerprintingProtection.overrides` does
nothing while that is on. So `flake.nix` turns resistFingerprinting off and
enables `privacy.fingerprintingProtection` with
`"+AllTargets,-CSSPrefersColorScheme"`.

This was tested on throwaway profiles with `librewolf --headless --screenshot`.
It matches resistFingerprinting on timezone, CPU count, screen size, timer
precision, languages, user agent and media queries. Only the colour scheme
differs. Disabling resistFingerprinting outright was rejected, because it drops
those protections too.

## 2026-10-09: LibreWolf as the daily browser (7c520c1)

`browser = { app = "librewolf"; manage = true; }` in `flake.nix`. Links and HTML
open in `librewolf.desktop`. Firefox stays installed (`programs.firefox.enable` in
`configuration.nix`), so don't remove it.

- The Firefox profile was copied into `~/.librewolf/default`. `compatibility.ini`
  was left out, because Firefox 151.0.4 is newer than LibreWolf 151.0.2 and that
  file would trigger downgrade protection. Add-on paths in `extensions.json` were
  rewritten to the new location. The earlier trial LibreWolf profile is kept at
  `~/.librewolf/default.pre-firefox-import`.
- LibreWolf clears data on shutdown by default. The LibreWolf profile settings in
  `flake.nix` turn that off and re-enable password saving, so the imported data
  survives.
- A closed Firefox can leave a stale `lock` symlink in its profile, pointing at a
  dead PID. Check the PID, not just whether the symlink exists.

**Pending at commit time:** `sudo nixos-rebuild switch --flake .#nixos`

## 2026-10-09: ChromaFox (unsigned extension) install (7c520c1)

ChromaFox never loaded in release Firefox, which left its toolbar grey:

- Release Firefox has signing compiled in and ignores
  `xpinstall.signatures.required`. LibreWolf, Developer Edition and ESR honour it.
- An XPI dropped into `<profile>/extensions/` is never picked up, because Firefox
  doesn't scan that folder at startup (`extensions.startupScanScopes` = 0).
  `chromafox.nix` installs ChromaFox through the `ExtensionSettings` policy
  instead (`force_installed`, `file://` URL). Policy installs are re-checked every
  startup and upgrade when the version changes.
- `/etc/firefox/policies/policies.json` overrides a wrapper's own policies file.

`chromafox.nix` is shared by `home-module.nix` and `nixos-module.nix`, which now
takes `inputs`. It also contains an autoconfig that removes `"extension"` from
`XPIDatabase.SIGNED_TYPES`, which turns off signing for **all** extensions in
release Firefox. That bypass is only used for `browser.app = "firefox"` with
`manage = false`, so it is inactive now. It hasn't been approved, and removing it
is still an open question.

A userChrome CSS fallback for the toolbar colours was tried and reverted. Its
`!important` rules block ChromaFox's live colour updates.
