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
        ./nixos-module.nix

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
                app = "firefox";
                # Use the system-installed Firefox (configuration.nix) and leave
                # its profile alone; the flake only themes it
                manage = false;
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
            };

            # Firefox as the default handler for web links and HTML files
            xdg.mimeApps = {
              enable = true;
              defaultApplications = nixpkgs.lib.genAttrs [
                "text/html"
                "application/xhtml+xml"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
                "x-scheme-handler/about"
                "x-scheme-handler/unknown"
              ] (_: [ "firefox.desktop" ]);
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
