# This laptop: GTX 1060 Mobile (Pascal) + Intel HD 630 (Optimus), Qualcomm Bluetooth

{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  hardware.bluetooth.settings = {
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

  # NVIDIA
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
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD"; # Intel VA-API (see hardware.graphics.extraPackages)
}
