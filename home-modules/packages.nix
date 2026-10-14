inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.programs.chromashell;

  # The novafetch repo (github:VN0V4/novafetch), from the flake input.
  novafetchSrc = inputs.novafetch.outPath;
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

  # Pomatez: pomodoro timer that can minimize to the tray. Not in nixpkgs, so
  # the official AppImage is wrapped. To update, bump version and hash (the
  # release lists a sha256 per asset; convert with  nix hash convert --to sri).
  pomatez = let
    pname   = "pomatez";
    version = "1.11.0";
    src = pkgs.fetchurl {
      url  = "https://github.com/zidoro/pomatez/releases/download/v${version}/Pomatez-v${version}-linux-x86_64.AppImage";
      hash = "sha256-Pnt+7Fjj1kSqvHrfhJRp9CUdYNHzMHLbhJAuu4alg3o=";
    };
    contents = pkgs.appimageTools.extract { inherit pname version src; };
  in pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    extraInstallCommands = ''
      install -Dm444 ${contents}/pomatez.desktop $out/share/applications/pomatez.desktop
      substituteInPlace $out/share/applications/pomatez.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=pomatez'
      cp -r ${contents}/usr/share/icons $out/share/
    '';
  };
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
        name = "novafetch";   # fastfetch with custom coloured ASCII art; -a plays the gold supernova
        runtimeInputs = [ fastfetch gawk coreutils anifetch ];
        text = "NOVA_ART=${../scripts/nova-art.txt}\nNOVA_VIDEO=${supernovaGold}\n"
          + builtins.readFile ../scripts/novafetch.sh;
      })
      eza

      # ── Apps ─────────────────────────────────
      foliate         # EPUB reader (dark reading theme under View → Theme)
      pomatez         # pomodoro timer; enable Minimize to Tray in its settings

      # ── VN0V4 tools ──────────────────────────
      inputs.paperoo.packages.${pkgs.stdenv.hostPlatform.system}.default   # terminal wallpaper browser

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
