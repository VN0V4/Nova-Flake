inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkDefault;
  cfg = config.programs.chromashell;
in
{
  config = mkIf cfg.enable {
    # shell.json belongs to the shell (its settings UI writes it), so merge into
    # it instead of linking it, and only when the flake's values change
    # The scheme is runtime state (the shell's picker changes it), so apply it
    # once per change instead of on every rebuild. After the wallpaper, since
    # the dynamic scheme is generated from it.
    home.activation.chromashellScheme = mkIf (cfg.scheme.name != null) (
      let
        s    = cfg.scheme;
        args = [ "-n" s.name ]
          ++ lib.optionals (s.flavour != null) [ "-f" s.flavour ]
          ++ lib.optionals (s.variant != null) [ "-v" s.variant ]
          ++ lib.optionals (s.mode    != null) [ "-m" s.mode ];
        want = lib.concatStringsSep " " args;
      in
      lib.hm.dag.entryAfter [ "linkGeneration" "chromashellWallpaper" ] ''
        marker="${config.xdg.stateHome}/chromashell/scheme"
        want=${lib.escapeShellArg want}
        if [[ "$(cat "$marker" 2>/dev/null)" != "$want" ]]; then
          echo "chromashell: setting colour scheme ($want)"
          if $DRY_RUN_CMD timeout 60 ${inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/caelestia \
               scheme set ${lib.escapeShellArgs args}; then
            $DRY_RUN_CMD mkdir -p "$(dirname "$marker")"
            [[ -n "''${DRY_RUN:-}" ]] || printf '%s' "$want" > "$marker"
          else
            echo "chromashell: could not set the colour scheme, will retry on the next rebuild"
          fi
        fi
      ''
    );

    home.activation.chromashellTransparency = mkIf (cfg.transparency.enable != null) (
      let
        want = builtins.toJSON {
          enabled = cfg.transparency.enable;
          inherit (cfg.transparency) base layers;
        };
      in
      lib.hm.dag.entryAfter [ "chromashellSeedShellApps" ] ''
        shell_cfg="$HOME/.config/caelestia/shell.json"
        marker="${config.xdg.stateHome}/chromashell/transparency"
        want=${lib.escapeShellArg want}
        if [[ "$(cat "$marker" 2>/dev/null)" != "$want" ]]; then
          echo "chromashell: setting shell transparency to $want"
          tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq --argjson t "$want" '.appearance.transparency = $t' "$shell_cfg" > "$tmp" \
            && $DRY_RUN_CMD mv "$tmp" "$shell_cfg" \
            && $DRY_RUN_CMD mkdir -p "$(dirname "$marker")" \
            && { [[ -n "''${DRY_RUN:-}" ]] || printf '%s' "$want" > "$marker"; }
        fi
      ''
    );

    gtk = {
      enable = true;
      theme  = {
        name    = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name    = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      gtk4.theme = null;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    };

    # hypr/config/variables.lua sets XCURSOR_THEME=Bibata-Modern-Classic (size 18)
    # and runs `hyprctl setcursor` with it. Without the theme installed Hyprland
    # falls back to a 1px cursor, so ship it and point everything at it.
    home.pointerCursor = {
      name    = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size    = 18;
      gtk.enable        = true;
      x11.enable        = true;
      hyprcursor.enable = true;
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme    = "adw-gtk3-dark";
      };
    };
  };
}
