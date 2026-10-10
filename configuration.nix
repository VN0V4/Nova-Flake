# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  # Shared by every machine. Hardware scan, GPU drivers and other per-machine
  # settings live in hosts/<name>/default.nix (picked in flake.nix)

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

  # Run AppImages: `appimage-run file.AppImage`, or directly (./file.AppImage
  # after chmod +x) thanks to binfmt. NixOS has no /lib, so a plain AppImage
  # can't find its libraries; appimage-run gives it an FHS environment.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Run plain Linux binaries built for other distros (e.g. Sunnify in
  # ~/.local/bin). They look for /lib64/ld-linux-x86-64.so.2, which NixOS
  # doesn't have; nix-ld provides it and serves the libraries below. This set
  # covers Qt/PyInstaller GUI apps; add more if an app says "lib….so not found".
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc zlib openssl krb5
      glib dbus fontconfig freetype
      libGL mesa libdrm libxkbcommon wayland
      libx11 libxcb libxcb-wm libxcb-image libxcb-keysyms libxcb-render-util libxcb-cursor
      libxext libxrender libxi libsm libice
      alsa-lib libpulseaudio
    ];
  };

  # Keyboard layouts for those binaries: their bundled libxkbcommon looks in
  # /usr/share/X11/xkb, which NixOS doesn't have ("failed to create xkb
  # context"). Nix-built apps already use this same data, so this is harmless.
  environment.sessionVariables.XKB_CONFIG_ROOT = "${pkgs.xkeyboard-config}/share/X11/xkb";

  # Put ~/.local/bin on PATH (installers like Sunnify's put programs there)
  environment.localBinInPath = true;

  # Customizations
  services.displayManager.defaultSession = "hyprland";
  programs.hyprland = {
  enable = true;
  xwayland.enable = true; # ensures XWayland support for Hyprland
  };

  programs.chromashell-system.enable = true;
  programs.serpantinum.enable = true; # system prerequisites for the Serpantinum shell (module comes from flake.nix)
#  programs.chromashell.enable = true;
  hardware.graphics.enable = true;
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Compressed swap in RAM (zram): there is no disk swap, so without it memory
  # limits like LibreWolf's MemoryHigh (flake.nix) have nowhere to push memory.
  # Pages compress roughly 3:1. Up to half of RAM can be used, and only while
  # something is swapped out.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

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
     gh
     fastfetch
     unzip
     opencode
     tauon
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
