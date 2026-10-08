{
  description = "Luca's NixOS configuration with ChromaShell";

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

          home-manager.users.luca = {
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

              # Everything in ./Wallpapers (git add it!) shows up in the shell's
              # wallpaper picker, alongside anything dropped in ~/Pictures/Wallpapers
              wallpaper = {
                images = nixpkgs.lib.optionals (builtins.pathExists ./Wallpapers)
                  (nixpkgs.lib.filesystem.listFilesRecursive ./Wallpapers);
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
            };

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
