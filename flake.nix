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
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # Your normal NixOS configuration
        ./configuration.nix

        # ChromaShell system module
        ./nixos-module.nix

        # Home Manager
        home-manager.nixosModules.home-manager

        {
          home-manager.users.luca = {
            imports = [
              (import ./home-module.nix inputs)
            ];

            programs.chromashell = {
              enable = true;

              browser = {
                app = "librewolf";
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
            };

            home.stateVersion = "26.05";
          };
        }
      ];
    };
  };
}
