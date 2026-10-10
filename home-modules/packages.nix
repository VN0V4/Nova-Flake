inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.programs.chromashell;

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
    ffmpeg -v error -i ${inputs.novafetch}/src/anifetch/assets/vecteezy_explosion-of-a-new-supernova-in-outer-space_54201863.mp4 \
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
        runtimeInputs = [ inputs.novafetch.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        text = ''exec anifetch "''${@:-${supernovaGold}}"'';
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
