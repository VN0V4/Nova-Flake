# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
 
  hardware.bluetooth = {
   enable = true;
   powerOnBoot = true;
   settings = {
     General = {
       Experimental = "true"; # Improves device compatibility (and exposes headset battery level)
       # Sony WH-1000XM5 advertises over both LE and classic. BlueZ tends to
       # pair it over LE, which this Qualcomm adapter can't do LE Audio on, so
       # A2DP never comes up ("br-connection-profile-unavailable"). Force classic.
       # Note: this disables BLE entirely (BLE-only mice/trackers won't work).
       ControllerMode = "bredr";
       FastConnectable = "true";
       JustWorksRepairing = "always";
       Enable = "Source,Sink,Media,Socket";
     };
   };
 };
  # Bluetooth manager + tray applet, also acts as the pairing agent
  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Bucharest";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ro_RO.UTF-8";
    LC_IDENTIFICATION = "ro_RO.UTF-8";
    LC_MEASUREMENT = "ro_RO.UTF-8";
    LC_MONETARY = "ro_RO.UTF-8";
    LC_NAME = "ro_RO.UTF-8";
    LC_NUMERIC = "ro_RO.UTF-8";
    LC_PAPER = "ro_RO.UTF-8";
    LC_TELEPHONE = "ro_RO.UTF-8";
    LC_TIME = "ro_RO.UTF-8";
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."luca" = {
    isNormalUser = true;
    description = "Luca";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;
  
  # Customizations
  services.displayManager.defaultSession = "hyprland";
  programs.hyprland = {
  enable = true;
  xwayland.enable = true; # ensures XWayland support for Hyprland
  };

  programs.chromashell-system.enable = true;
#  programs.chromashell.enable = true;
  # NVIDIA
  # GTX 1060 Mobile (Pascal) + Intel HD 630 (Optimus laptop)
  hardware.graphics.enable = true;
  # VA-API driver for the Intel iGPU (hardware video encode/decode, needed by gpu-screen-recorder)
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
	modesetting.enable = true;
	open = false; # open kernel modules don't support Pascal
	# 580 is the last driver branch that supports Pascal (GTX 10xx)
	package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
	nvidiaSettings = true;
	powerManagement.enable = true;
	# PRIME offload: Intel drives the desktop, run games on the GTX with `nvidia-offload <cmd>`
	powerManagement.finegrained = true;
	prime = {
	  offload.enable = true;
	  offload.enableOffloadCmd = true;
	  intelBusId = "PCI:0:2:0";
	  nvidiaBusId = "PCI:1:0:0";
	};
  };
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "iHD"; # Intel VA-API (see hardware.graphics.extraPackages)
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
   environment.systemPackages = with pkgs; [
     vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
     wget
     nwg-look
     hyprland
     kitty
     waybar
     wofi
     git
     keepassxc
     element-desktop
     obs-studio
   ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
