# Memory

Notes on why things in this repo are the way they are: context, gotchas and
pending steps that the code and git log don't show. Updated with every commit.
Newest first. Edit an existing entry when a later commit changes the same topic.

---

## 2026-10-09: novafetch runs on terminal open, info box bottom-right (739b709)

`home-modules/dotfiles.nix` adds `fish/conf.d/novafetch.fish`, which defines
`fish_greeting` to run `novafetch`. `fish/functions` is a read-only store
symlink from the upstream dots, so its `fish_greeting.fish` (ChromaShell banner +
plain fastfetch) can't be edited. A function defined in conf.d wins over
functions/ autoload. The banner is gone on purpose.

The default `novafetch` layout (`corner()`) reads `stty size`. It puts the logo
top-left and the info box flush bottom-right, and fills the screen down to the
last 2 rows. Those rows are for the 2-line Starship prompt; change
`NOVAFETCH_PROMPT_LINES` if the prompt changes. It uses `\e[<col>G` to place the
box, not padding spaces. Trailing separator spaces are stripped from the box,
otherwise it wraps. If logo + 2 + box is wider than the terminal (about 98
columns) or too tall, it falls back to `novafetch side` (plain fastfetch layout).

Gotcha: fastfetch reports its *parent process* as the shell. Run from awk
process substitution it said `awk`; from a `$(...)` subshell it said `bash`.
Fix: run the info fastfetch directly from the script (no subshell, output to
`~/.cache/novafetch.raw.info`) with `FFTS_IGNORE_PARENT=1`, which makes it start
at the grandparent (fish). `corner` must not be called inside `$(...)` either.
It prints nothing when it fails, so it can print straight to the terminal. A
`.sh` script name doesn't help: fastfetch only skips parents named exactly `sh`.

Tested in fake ttys (`script -c "stty rows R cols C; fish -N -c novafetch"`) at
120x40, 80x40 and 120x20. All showed `shell fish`; small sizes used the side
layout. Not yet tested in a real kitty window. Pending: if Hyprland resizes the
new kitty window after fish starts, the box may miss the corner. The fix would be
a short wait or a SIGWINCH redraw.

## 2026-10-09: novafetch command, golden supernova logo (e88b463)

`scripts/novafetch.sh` is packaged in `home-modules/packages.nix` via
`writeShellApplication` (shellcheck runs at build, so keep it clean). It was first
called fastfetch-logo and was renamed. `NOVA_ART=${../scripts/nova-art.txt}` is
prepended to the script text, so the installed command finds the art. Run from
the repo, it uses the file next to the script. runtimeInputs: fastfetch, gawk,
coreutils.

The fastfetch `config.jsonc` is a read-only store symlink from the upstream dots,
so novafetch never edits it. It passes `--logo*` flags instead. User state:
`~/.config/novafetch/logo.txt` (own art, optional) and `settings` (one line:
`nova`, `colors C1..`, or `gradient FROM TO DIR`). No settings means nova mode
with `nova-art.txt`. `reset` deletes both.

Nova mode (awk): the core is the densest 7x3 window of braille dots. Colour is
set by distance from the core (y doubled for cell aspect, `r^0.8`), plus a
penalty for sparse characters (dot count of U+2800+n). Stops: white-hot, pale
gold, gold, amber, orange, ember. Blank U+2800 is left uncoloured. Gradient and
nova modes write raw ANSI to `~/.cache/novafetch.raw` and use `--logo-type
file-raw` with an explicit `--logo-width/height`.

Renderers force `LC_ALL=C.UTF-8`. Under the minimal env of a Nix wrapper, bash
and awk would otherwise count bytes, not characters, and break the braille
alignment. Verified with `env -i`. Checked visually by converting the ANSI
output to SVG -> PNG with ImageMagick (DejaVu Sans Mono draws empty braille
dots as rings; that's the font, not the colours).

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
