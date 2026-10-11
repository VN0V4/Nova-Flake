{
  description = "N0V4's NixOS configuration with a modified version of ChromaShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ChromaShell dotfiles
    dotfiles = {
      url = "github:SecLBL/ChromaShell";
      flake = false;
    };

    caelestia-shell = {
      url = "github:SecLBL/CS-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-cli = {
      url = "github:SecLBL/CS-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    serpantinum = {
      url = "github:ilyamiro/serpantinum";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # novafetch: animated fastfetch (video → chafa frames beside the system
    # info), a fork of anifetch. Update with
    #   nix flake update novafetch
    novafetch = {
      url = "github:VN0V4/novafetch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ytmd: YouTube Music downloader (TUI + batch). No flake, packaged in
    # home-modules/packages.nix. Update with  nix flake update ytmd
    ytmd = {
      url = "github:VN0V4/ytmd";
      flake = false;
    };

    # paperoo: terminal wallpaper browser (wallhaven). Update with
    #   nix flake update paperoo
    paperoo = {
      url = "github:VN0V4/paperoo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, serpantinum, ... }:
  let
    # Same system everywhere; only the host module (hosts/<name>) differs per machine
    mkSystem = hostModule: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit serpantinum; };

      modules = [
        # Per-machine bits: hardware scan, GPU drivers, adapter quirks
        hostModule

        # Your normal NixOS configuration
        ./configuration.nix

        # ChromaShell system module
        (import ./nixos-module.nix inputs)

        # Serpantinum system prerequisites (enabled in configuration.nix)
        serpantinum.nixosModules.default

        # Home Manager
        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Rename conflicting existing files to <name>.backup instead of aborting
          home-manager.backupFileExtension = "backup";
          # Replace an old .backup on every rebuild instead of failing
          home-manager.overwriteBackup = true;

          home-manager.users.luca = { config, pkgs, ... }: {
            imports = [
              (import ./home-module.nix inputs)
              ./force-files.nix
            ];

            # gtk sets its own force flag on ~/.gtkrc-2.0
            gtk.gtk2.force = true;

            programs.chromashell = {
              enable = true;

              browser = {
                app = "librewolf";
                # The flake installs LibreWolf and owns its profile (~/.librewolf/default);
                # Firefox stays installed from configuration.nix
                manage = true;
              };

              comms = {
                app = "vencord";
                manage = true;
              };

              music = {
                app = "spicetify";
                manage = true;
              };

              editor = {
                app = "zed";
                manage = true;
              };

              # Colours generated from the wallpaper (vibrant = more saturated)
              scheme = {
                name    = "dynamic";
                variant = "tonalspot";
                mode    = "dark";
                # Every new wallpaper switches back to colours generated from it
                followWallpaper = true;
              };

              # Transparent bar/sidebar/launcher (opacity 0–1: base = panels, layers = cards on them)
              transparency = {
                enable = true;
                base   = 0.65;
                layers = 0.4;
              };

              # Images in ./Wallpapers (git add -f them, see its README) show up in
              # the shell's wallpaper picker, alongside anything dropped in
              # ~/Pictures/Wallpapers
              wallpaper = {
                images = builtins.filter
                  (f: builtins.match ".*\\.(jpe?g|png|webp|gif)" (nixpkgs.lib.toLower (toString f)) != null)
                  (nixpkgs.lib.optionals (builtins.pathExists ./Wallpapers)
                    (nixpkgs.lib.filesystem.listFilesRecursive ./Wallpapers));
                # New random wallpaper from the folder at every login
                randomOnLogin = true;
                # Applied on rebuild whenever this changes, e.g. ./Wallpapers/mountains.jpg
                default = null;
              };
            };

            # Keep cookies, logins and history between sessions (LibreWolf clears
            # them on shutdown by default) and offer to save passwords
            programs.librewolf.profiles.default.settings = {
              "privacy.sanitize.sanitizeOnShutdown"                    = false;
              "privacy.clearOnShutdown.cookies"                        = false;
              "privacy.clearOnShutdown.history"                        = false;
              "privacy.clearOnShutdown_v2.cookiesAndStorage"           = false;
              "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
              "signon.rememberSignons"                                 = true;

              # Websites follow the dark system theme. resistFingerprinting always
              # reports light mode, so use the equivalent fingerprintingProtection
              # with every protection on except the colour scheme
              "privacy.resistFingerprinting"               = false;
              "privacy.fingerprintingProtection"           = true;
              "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme";

              # Lower memory use (site isolation stays on): no cached copies of
              # pages for back/forward, a smaller in-memory cache (64 MB, the
              # disk cache is unchanged), no spare process kept warm, and unload
              # tabs when memory runs low
              "browser.sessionhistory.max_total_viewers" = 0;
              "browser.cache.memory.capacity"            = 65536;
              "dom.ipc.processPrelaunch.enabled"         = false;
              "browser.tabs.unloadOnLowMemory"           = true;
            };

            # Auto Tab Discard: unloads tabs you haven't looked at for 10 minutes
            # (they reload when clicked). Each open site costs ~150-250 MB.
            programs.librewolf.policies.ExtensionSettings."{c2c003ee-bd69-42a2-b0e9-6f34222cb046}" = {
              installation_mode = "normal_installed";
              install_url       = "https://addons.mozilla.org/firefox/downloads/latest/auto-tab-discard/latest.xpi";
            };

            # Start LibreWolf in its own systemd scope with a 1 GB soft limit.
            # Otherwise it runs inside caelestia.service (the shell launches it),
            # where it can't be limited on its own. MemoryHigh never kills
            # anything: past 1 GB the kernel pushes LibreWolf's memory into zram
            # (configuration.nix). This wrapper takes priority over the real
            # `librewolf`, so the keybind, launcher and links all go through it.
            home.packages = [
              (nixpkgs.lib.hiPrio (pkgs.writeShellScriptBin "librewolf" ''
                lw=${config.programs.librewolf.finalPackage}/bin/librewolf
                # Already running: this call just opens a window in that instance
                if systemctl --user --quiet is-active librewolf.scope; then
                  exec "$lw" "$@"
                fi
                exec systemd-run --user --scope --quiet --unit=librewolf --slice=app.slice \
                  -p MemoryHigh=1G "$lw" "$@"
              ''))
            ];

            # LibreWolf as the default handler for web links and HTML files
            xdg.mimeApps = {
              enable = true;
              defaultApplications = nixpkgs.lib.genAttrs [
                "text/html"
                "application/xhtml+xml"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
                "x-scheme-handler/about"
                "x-scheme-handler/unknown"
              ] (_: [ "librewolf.desktop" ]);
            };

            home.stateVersion = "26.05";
          };
        }
      ];
    };
  in {
    nixosConfigurations = {
      # This laptop: hardware scan + Nvidia/Bluetooth tweaks committed to the repo (pure)
      nixos = mkSystem ./hosts/nixos;

      # Any other machine: uses its own /etc/nixos scan, so it needs --impure:
      #   sudo nixos-rebuild switch --flake .#generic --impure
      generic = mkSystem ./hosts/generic;
    };
  };
}
