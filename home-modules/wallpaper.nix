inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg    = config.programs.chromashell;
  wp     = cfg.wallpaper;
  system = pkgs.stdenv.hostPlatform.system;
  dir    = "${config.home.homeDirectory}/${wp.directory}";

  # The default is linked into the folder as well, so the picker lists it
  images = lib.unique (wp.images ++ lib.optional (wp.default != null) wp.default);
  # Files from the repo land in the store as <hash>-name; link them under their real name
  linkName = img: "${wp.directory}/${baseNameOf (toString img)}";
in
{
  config = mkIf cfg.enable {

    # Shell (Paths.qml) and CLI (paths.py) both read this; environment.d also
    # reaches the caelestia user service and apps started by UWSM
    systemd.user.sessionVariables.CAELESTIA_WALLPAPERS_DIR = dir;
    home.sessionVariables.CAELESTIA_WALLPAPERS_DIR         = dir;

    # The shell only watches the folder if it exists when it starts, so restart
    # it when the folder is first set up or moved (the activation below creates it
    # before Home Manager restarts units)
    systemd.user.services.caelestia.Unit.X-Restart-Triggers = [ dir ];

    # Individual links, so the folder stays a real directory you can drop
    # your own images into
    home.file = lib.listToAttrs (map (img: {
      name  = linkName img;
      value.source = img;
    }) images);

    # Apply the default once per change, so a wallpaper picked in the shell
    # isn't reset on every rebuild
    home.activation.chromashellWallpaper = mkIf (wp.default != null) (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        marker="${config.xdg.stateHome}/chromashell/wallpaper-default"
        want="${wp.default}"
        if [[ "$(cat "$marker" 2>/dev/null)" != "$want" ]]; then
          echo "chromashell: setting wallpaper to ${baseNameOf (toString wp.default)}"
          if $DRY_RUN_CMD timeout 60 ${inputs.caelestia-cli.packages.${system}.default}/bin/caelestia \
               wallpaper -f "${config.home.homeDirectory}/${linkName wp.default}"; then
            $DRY_RUN_CMD mkdir -p "$(dirname "$marker")"
            [[ -n "''${DRY_RUN:-}" ]] || printf '%s' "$want" > "$marker"
          else
            echo "chromashell: could not set the wallpaper, will retry on the next rebuild"
          fi
        fi
      ''
    );

    # Runs once per graphical login (not on rebuilds). -n: don't skip images
    # smaller than the monitor, so every image in the folder can come up.
    systemd.user.services.chromashell-random-wallpaper = mkIf wp.randomOnLogin {
      Unit = {
        Description = "ChromaShell: random wallpaper at login";
        After       = [ "graphical-session.target" "caelestia.service" ];
        PartOf      = [ "graphical-session.target" ];
      };
      Service = {
        Type      = "oneshot";
        ExecStart = "${inputs.caelestia-cli.packages.${system}.default}/bin/caelestia wallpaper -r ${dir} -n";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.activation.chromashellWallpaperDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${dir}"
    '';
  };
}
