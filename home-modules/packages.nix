inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.programs.chromashell;

  # The ./novafetch input is a subfolder of this repo's store copy, so its path
  # changes on every dotfiles edit. A separate copy is addressed by the
  # submodule's contents alone, so anifetch and the video below only rebuild
  # (and re-render their cache) when novafetch itself changes.
  novafetchSrc = builtins.path { path = inputs.novafetch.outPath; name = "novafetch-source"; };
  anifetch = pkgs.callPackage "${novafetchSrc}/nix/package.nix" { };

  # novafetch's default video: the vecteezy supernova graded sunny gold.
  # From ~2.6 s (after the flash) gamma/contrast ramp up so the remnant and
  # debris stay visible; the curves keep space black and map brightness onto
  # amber → gold → pale yellow. anifetch caches by file name, and the store
  # path's hash is part of that name, so any change here renders afresh.
  supernovaGrade = lib.concatStringsSep "," [
    "hue=s=0"
    "eq=gamma='1+0.6*clip((t-2.6)/1.2,0,1)':contrast='1+0.35*clip((t-2.6)/1.2,0,1)':eval=frame"
    "curves=r='0/0 0.12/0.03 0.3/0.5 0.55/0.9 1/1':g='0/0 0.12/0.02 0.3/0.3 0.55/0.68 1/0.94':b='0/0 0.3/0.04 0.55/0.15 1/0.62'"
    "scale=960:-2"
  ];
  supernovaGold = pkgs.runCommand "supernova-gold.mp4" { nativeBuildInputs = [ pkgs.ffmpeg ]; } ''
    ffmpeg -v error -i ${novafetchSrc}/src/anifetch/assets/vecteezy_explosion-of-a-new-supernova-in-outer-space_54201863.mp4 \
      -vf ${lib.escapeShellArg supernovaGrade} -an -c:v libx264 -crf 18 -pix_fmt yuv420p "$out"
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # ── Shell runtime ────────────────────────
      kitty
      fish
      starship

      # ── Hyprland utilities ───────────────────
      hyprlock
      hypridle
      hyprpicker
      wl-clipboard
      cliphist
      ydotool
      grim
      swappy

      # ── Screen recording ─────────────────────
      gpu-screen-recorder

      # ── Audio ────────────────────────────────
      jalv
      pipewire.jack   # pw-jack wrapper — routes jalv through PipeWire JACK compat
      lsp-plugins
      rnnoise-plugin
      noise-repellent
      pamixer
      pulseaudio      # wpctl / pactl
      pavucontrol
      mpv             # shell.json general.apps.playback default (recording playback)

      # ── File manager ─────────────────────────
      thunar

      # ── Theming ──────────────────────────────
      adw-gtk3
      papirus-icon-theme
      pywal
      qtengine        # Qt platform theme for QT_QPA_PLATFORMTHEME=qtengine (caelestia default; provides Qt icon theme)

      # ── Caelestia spawn support ──────────────
      app2unit

      # ── System monitoring ────────────────────
      btop
      mission-center  # GUI system monitor — sysmon toggle target
      ddcutil
      fastfetch
      (writeShellApplication {
        name = "novafetch";   # animated fastfetch; no arguments plays the gold supernova
        runtimeInputs = [ anifetch ];
        # anifetch copies the video into its assets folder on every run, keeping
        # the read-only mode of store files, so the second copy fails. Put a
        # writable copy there first; given that path, anifetch skips the copy.
        text = ''
          if [ $# -eq 0 ]; then
            video="''${XDG_DATA_HOME:-$HOME/.local/share}/anifetch/assets/${baseNameOf supernovaGold}"
            [ -f "$video" ] || install -D -m 644 ${supernovaGold} "$video"
            chmod u+w "$video"
            set -- "$video"
          fi
          exec anifetch "$@"
        '';
      })
      eza

      # ── System / scripting ───────────────────
      inotify-tools
      jq
      socat
      bc
      imagemagick
      curl

      # ── Fonts ────────────────────────────────
      nerd-fonts.jetbrains-mono
      nerd-fonts.iosevka
      material-symbols
    ];
  };
}
