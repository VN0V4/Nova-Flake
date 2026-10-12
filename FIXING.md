# Fixing

How to get this config running on a machine that isn't my laptop, how to swap
drivers (GPU, CPU, Wi-Fi, audio, …), and how to look things up when it breaks.

## Where things live

| File | What it's for | Touch it on a new machine? |
| --- | --- | --- |
| `flake.nix` | Inputs, the list of machines (`nixosConfigurations`), Home Manager + ChromaShell settings | Add a host, change the username |
| `configuration.nix` | Shared by **every** machine: boot loader, locale, users, packages, firewall | Username, timezone, boot loader |
| `hosts/<name>/default.nix` | **Per-machine** stuff: GPU drivers, Bluetooth quirks, kernel tweaks | Yes, this is where hardware fixes go |
| `hosts/<name>/hardware-configuration.nix` | Auto-generated disk/filesystem/kernel module scan | Generate it, don't hand-edit |
| `nixos-module.nix` | ChromaShell system bits (Hyprland, PipeWire, keyring, power-profiles-daemon) | Rarely |
| `home-module.nix`, `home-modules/` | The desktop itself (shell, theming, audio routing) | Rarely |

Rule of thumb: **if a fix only makes sense on one machine, put it in
`hosts/<name>/default.nix`, not `configuration.nix`.** `hosts/nixos` is my
laptop (GTX 1060 + Intel, Qualcomm Bluetooth); none of its tweaks belong on
other hardware.

## 1. Setting up a new machine

### Quick way (`generic`)

Install NixOS normally, then:

```sh
git clone https://github.com/VN0V4/Nova-Flake ~/dotfiles && cd ~/dotfiles
sudo nixos-rebuild switch --flake .#generic --impure
```

`generic` reads `/etc/nixos/hardware-configuration.nix` from the installer,
which is why it needs `--impure`. Good for a first boot; add hardware fixes to
`hosts/generic/default.nix`.

### Proper way (own host, recommended once it works)

```sh
mkdir hosts/desktop
cp /etc/nixos/hardware-configuration.nix hosts/desktop/
cp hosts/generic/default.nix hosts/desktop/default.nix
# in hosts/desktop/default.nix change the import to:
#   imports = [ ./hardware-configuration.nix ];
git add hosts/desktop   # flakes ignore files git doesn't know about!
```

Then add it to `flake.nix`:

```nix
nixosConfigurations = {
  nixos   = mkSystem ./hosts/nixos;
  generic = mkSystem ./hosts/generic;
  desktop = mkSystem ./hosts/desktop;   # new
};
```

and build with `sudo nixos-rebuild switch --flake .#desktop` (no `--impure`).

> **Gotcha:** "path ... does not exist" or a file that "isn't there" in a flake
> almost always means it isn't `git add`ed. It doesn't have to be committed,
> just staged.

### Things that are hardcoded to me

Change these or you'll get a user called `luca`:

- `configuration.nix` → `users.users."luca"`
- `flake.nix` → `home-manager.users.luca`
- `configuration.nix` → `time.timeZone`, `i18n.extraLocaleSettings` (Romanian formats)
- `configuration.nix` → `networking.hostName` (cosmetic; the flake picks the host from `.#name`)
- `configuration.nix` → `networking.firewall.allowedTCPPorts` (2234 is for Nicotine+)

### Boot loader

`configuration.nix` uses **systemd-boot**, which needs UEFI. Check with:

```sh
[ -d /sys/firmware/efi ] && echo UEFI || echo "legacy BIOS"
```

On legacy BIOS, put this in the host file and use `lib.mkForce` to turn off
systemd-boot:

```nix
{ lib, ... }: {
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub = { enable = true; device = "/dev/sda"; };  # the disk, not a partition
}
```

## 2. Find out what hardware you have

None of these are installed by default; `nix shell` pulls them in temporarily.

```sh
nix shell nixpkgs#pciutils nixpkgs#usbutils nixpkgs#inxi

inxi -Fxz                 # everything at a glance (safe to paste online, -z hides serials)
lspci -k                  # PCI devices + which kernel driver is in use ("Kernel driver in use:")
lspci -nn | grep -Ei 'vga|3d|display'   # GPUs with vendor:device IDs like [10de:1c8d]
lscpu | grep -E 'Model name|Vendor'     # CPU
lsusb                     # USB devices (many Bluetooth adapters / webcams are USB)
uname -r                  # running kernel version
```

The **`[vendor:device]` ID** from `lspci -nn` is the single most useful thing
to search for. `10de` = NVIDIA, `1002` = AMD, `8086` = Intel.

## 3. GPU drivers

All of this goes in `hosts/<name>/default.nix`. `configuration.nix` already sets
`hardware.graphics.enable = true`.

### Intel only

Usually works out of the box. For hardware video decode/encode (OBS,
gpu-screen-recorder, smoother YouTube):

```nix
{ pkgs, ... }: {
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver     # Broadwell (5th gen, 2014) and newer → "iHD"
    # intel-vaapi-driver   # older than Broadwell → "i965"
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";  # or "i965"
}
```

Check it with `nix shell nixpkgs#libva-utils -c vainfo`.

### AMD only

Works out of the box via Mesa (`amdgpu`), including VA-API. Optional:

```nix
{
  hardware.amdgpu.initrd.enable = true;   # load the driver early (fixes flicker/wrong resolution at boot)
  hardware.graphics.enable32Bit = true;   # Steam / Wine games
}
```

Very old Radeons (HD 7000 and older) may need the `radeon` driver instead;
search for your card + "amdgpu si cik support".

### NVIDIA only (desktop)

```nix
{ config, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];   # also needed on Wayland, despite the name
  hardware.nvidia = {
    modesetting.enable = true;    # required for Hyprland/Wayland
    open = true;                  # see the table below
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;
  };
}
```

Pick `open` and `package` by generation:

| Card | `open` | `package` |
| --- | --- | --- |
| RTX 50xx (Blackwell) | `true` (required) | `stable` or `beta` |
| RTX 20xx–40xx, GTX 16xx (Turing and newer) | `true` (recommended) | `stable` |
| GTX 10xx, GTX 9xx (Pascal, Maxwell) | `false` | `legacy_580` (what my laptop uses) |
| GTX 6xx/7xx (Kepler) | `false` | `legacy_470` (may not build on newest kernels) |
| Older | `false` | `legacy_390` or use Nouveau (just remove the NVIDIA block) |

The exact names change over time. List what your nixpkgs has with:

```sh
nix eval --impure --expr 'builtins.attrNames (import <nixpkgs> {}).linuxPackages.nvidiaPackages'
```

(or `nix repl`, `:lf .`, then
`outputs.nixosConfigurations.desktop.config.boot.kernelPackages.nvidiaPackages` + Tab).

Check it worked: `nvidia-smi`.

### Hybrid laptops (Intel/AMD iGPU + NVIDIA)

Copy the whole `hardware.nvidia` block from `hosts/nixos/default.nix`, then fix
the **bus IDs**, they're different on every laptop:

```sh
lspci | grep -Ei 'vga|3d'
# 00:02.0 VGA compatible controller: Intel ...
# 01:00.0 3D controller: NVIDIA ...
```

`lspci` prints **hex**, NixOS wants **decimal** in `PCI:bus:device:function`:

| lspci | NixOS |
| --- | --- |
| `00:02.0` | `"PCI:0:2:0"` |
| `01:00.0` | `"PCI:1:0:0"` |
| `0e:00.0` | `"PCI:14:0:0"` (0e hex = 14) |
| `c1:00.0` | `"PCI:193:0:0"` |

Convert with `printf '%d\n' 0xc1`. For an **AMD** iGPU, use `amdgpuBusId`
instead of `intelBusId`.

Modes:

- `prime.offload` (what I use): iGPU runs the desktop, battery lasts. Run games
  with `nvidia-offload <command>` (Steam: `nvidia-offload %command%`).
- `prime.sync`: NVIDIA renders everything. Better performance, worse battery,
  remove `powerManagement.finegrained`.

Also delete `LIBVA_DRIVER_NAME = "iHD"` if the iGPU isn't Intel.

### Virtual machine

Drop all GPU stuff. For QEMU/virt-manager:

```nix
{ services.qemuGuest.enable = true; services.spice-vdagentd.enable = true; }
```

Hyprland in a VM often needs a 3D-accelerated display (virtio-gpu with
`gl=on`); without it you'll get a black screen. Test GNOME (also enabled in
`configuration.nix`) from the login screen first.

## 4. CPU

`nixos-generate-config` usually detects this and writes it into
`hardware-configuration.nix`. Make sure one of these is there:

```nix
hardware.cpu.intel.updateMicrocode = true;   # or
hardware.cpu.amd.updateMicrocode   = true;
```

Extras for the host file:

```nix
services.thermald.enable = true;     # Intel laptops: stops thermal throttling weirdness
boot.kernelParams = [ "amd_pstate=active" ];   # AMD Zen 2+: better power/frequency scaling
```

> **Gotcha:** `nixos-module.nix` enables `power-profiles-daemon` (the shell's
> power mode button uses it). **TLP and auto-cpufreq conflict with it.** If a
> guide tells you to install TLP, either skip it or add
> `services.power-profiles-daemon.enable = lib.mkForce false;`, and the power
> profile toggle in the shell stops working.

## 5. Kernel

Newer hardware (brand new laptops, Wi-Fi 7, recent AMD GPUs) may need a newer kernel:

```nix
{ pkgs, ... }: { boot.kernelPackages = pkgs.linuxPackages_latest; }
```

But legacy NVIDIA drivers (`legacy_470`, `legacy_390`) often **don't build** on
the latest kernel. If the build fails inside `nvidia-x11`, go back to the
default kernel or try `pkgs.linuxPackages_6_12` (an LTS).

Kernel module options and parameters, Nix-style:

```nix
boot.kernelParams = [ "foo=bar" ];                  # kernel command line
boot.kernelModules = [ "some_module" ];             # load at boot
boot.blacklistedKernelModules = [ "nouveau" ];      # never load
boot.extraModprobeConfig = "options iwlwifi power_save=0";   # /etc/modprobe.d
```

## 6. Wi-Fi, Bluetooth, audio, firmware

Most "device detected but doesn't work" problems are missing firmware:

```nix
hardware.enableRedistributableFirmware = true;   # usually already on; covers Intel/Realtek/Qualcomm/AMD
# hardware.enableAllFirmware = true;             # also non-redistributable blobs (needs allowUnfree, already set)
```

Specific cases:

- **Broadcom Wi-Fi** (`lspci` shows BCM43xx):
  ```nix
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [ "b43" "bcma" ];
  ```
  (It's marked insecure; the build error tells you the exact
  `nixpkgs.config.permittedInsecurePackages` line to add.)
- **No sound on a newer laptop** (Intel 10th gen+ / "dummy output"): needs
  Sound Open Firmware, `hardware.firmware = [ pkgs.sof-firmware ];`.
- **Bluetooth headphones won't do A2DP**: see the `ControllerMode = "bredr"`
  hack in `hosts/nixos/default.nix`. It's for *my* adapter + headphones and
  it disables BLE, so don't copy it blindly.
- **Audio routing is weird** (sound on the wrong device): that's ChromaShell's
  routing in `home-modules/audio.nix`, not a driver problem. Check
  `wpctl status` first.

## 7. Testing changes without bricking anything

```sh
sudo nixos-rebuild build  --flake .#desktop   # just compile, change nothing (catches typos)
sudo nixos-rebuild test   --flake .#desktop   # apply now, but NOT the boot default; reboot = old system
sudo nixos-rebuild boot   --flake .#desktop   # becomes default on next boot (use for kernel/driver changes)
sudo nixos-rebuild switch --flake .#desktop   # apply now + make default
```

For GPU/kernel changes, prefer `boot` and reboot; `switch` can't swap a loaded
GPU driver live.

**If it breaks:** every rebuild is a "generation". Reboot, pick the previous one
in the boot menu (hold Space if the menu doesn't show), then roll back for good:

```sh
sudo nixos-rebuild switch --rollback
```

If you only get a black screen but the system booted: `Ctrl+Alt+F3` for a TTY,
log in, fix the file, rebuild.

## 8. Reading logs and errors

```sh
journalctl -b -p err              # errors from this boot
journalctl -b -1 -p err           # errors from the previous boot (the one that broke)
journalctl -b | grep -i nvidia    # anything about one driver
sudo dmesg -w                     # kernel messages live (plug a device in and watch)
systemctl --failed                # system services that failed
systemctl --user --failed         # user services (caelestia, audio follow, …)
journalctl --user -u caelestia -b # the shell's log
```

Nix build errors:

- Add `--show-trace` to see where in the config an error came from.
- **"The option `x.y.z' does not exist"**: renamed or removed. Search for it on
  [search.nixos.org/options](https://search.nixos.org/options) (channel:
  unstable); the old name usually shows a rename warning.
- **"undefined variable 'foo'"**: package renamed or missing. Search
  [search.nixos.org/packages](https://search.nixos.org/packages).
- **"... is marked as broken / insecure / unfree"**: the error message gives
  you the exact line to add. Read the whole thing.
- **"conflicting definition values"**: two files set the same option. Use
  `lib.mkForce` in the one that should win.

See what an option currently evaluates to:

```sh
nix eval .#nixosConfigurations.desktop.config.hardware.nvidia.open
```

## 9. How to google this stuff

### Where to look (best first)

1. **[search.nixos.org](https://search.nixos.org)**: exact option and package
   names. Always check here before trusting a forum post; options get renamed.
2. **[wiki.nixos.org](https://wiki.nixos.org)**: the *official* wiki. Pages
   like "NVIDIA", "AMD GPU", "Intel Graphics", "Bluetooth", "Laptop". (The old
   `nixos.wiki` is unofficial and often outdated.)
3. **[discourse.nixos.org](https://discourse.nixos.org)**: forum, best for
   "this specific error on this specific hardware".
4. **GitHub nixpkgs**: [issues](https://github.com/NixOS/nixpkgs/issues) for
   bugs, and code search to see how others configure something.
5. **[NixOS/nixos-hardware](https://github.com/NixOS/nixos-hardware)**:
   ready-made modules for specific laptops (ThinkPads, Framework, Dell XPS,
   ASUS, …). If your model is there, use it instead of guessing.
6. **[Arch Wiki](https://wiki.archlinux.org)**: best general Linux hardware
   docs out there. The *what* is right, you just translate the *how* (below).
7. **[noogle.dev](https://noogle.dev)**: Nix language functions (`lib.mkForce`,
   `lib.optionals`, …).

### Search query recipes

| You want | Search |
| --- | --- |
| Driver for a device | `nixos <exact model>` e.g. `nixos GTX 1650 mobile`, or `nixos 10de:1f91` (the lspci ID) |
| Specific laptop | `nixos-hardware <laptop model>` then `nixos <laptop model> <problem>` |
| An error message | The error in quotes **with paths, hashes and version numbers removed**: `nixos "nvidia-x11" "error: implicit declaration of function"` |
| Forum only | `site:discourse.nixos.org <problem>` |
| Arch's take | `arch wiki <device or problem>` |
| How others configure it | GitHub code search: `"hardware.nvidia.prime" language:nix` |
| Hyprland on X | `hyprland <gpu> <problem>` + check [wiki.hyprland.org](https://wiki.hyprland.org) (Nvidia page especially) |
| Is it a known bug? | `nixpkgs issue <package> <symptom>` |

Tips:

- Strip `/nix/store/abc123...-` from error messages before searching; the hash
  is unique to you and matches nothing.
- Add the year (`2026`) if results look stale; NixOS moves fast and many old
  answers use removed options (`hardware.opengl` → `hardware.graphics`,
  `sound.enable`, `services.xserver.displayManager.gdm` → `services.displayManager.gdm`).
- When asking for help, paste `inxi -Fxz`, the relevant file from `hosts/`, and
  the full error. Mention it's a flake on nixos-unstable.

### Translating Arch / Ubuntu instructions to Nix

Generic Linux guides tell you to edit files by hand. On NixOS those files are
read-only and rebuilt from your config, so translate:

| Guide says | NixOS equivalent |
| --- | --- |
| `pacman -S foo` / `apt install foo` | `environment.systemPackages = [ pkgs.foo ];` |
| Add `foo=bar` to GRUB_CMDLINE / kernel params | `boot.kernelParams = [ "foo=bar" ];` |
| `/etc/modprobe.d/x.conf`: `options mod a=b` | `boot.extraModprobeConfig = "options mod a=b";` |
| `blacklist nouveau` | `boot.blacklistedKernelModules = [ "nouveau" ];` |
| `/etc/modules-load.d` | `boot.kernelModules = [ ... ];` |
| `/etc/udev/rules.d/*.rules` | `services.udev.extraRules = '' ... '';` |
| `systemctl enable foo` | Find `services.foo.enable` on search.nixos.org |
| Write a file in `/etc/...` | `environment.etc."path/name".text = '' ... '';` |
| `export VAR=...` in `/etc/environment` | `environment.sessionVariables.VAR = "...";` |
| `/etc/bluetooth/main.conf` `[General]` | `hardware.bluetooth.settings.General = { ... };` |
| Install firmware package | `hardware.firmware = [ pkgs.foo-firmware ];` |
| `mkinitcpio` MODULES=(...) | `boot.initrd.kernelModules = [ ... ];` |

## 10. New machine checklist

- [ ] `nix shell nixpkgs#inxi -c inxi -Fxz`, write down GPU, CPU, Wi-Fi, Bluetooth
- [ ] Check [nixos-hardware](https://github.com/NixOS/nixos-hardware) for the model
- [ ] Create `hosts/<name>/`, copy `hardware-configuration.nix`, `git add` it
- [ ] Add `<name> = mkSystem ./hosts/<name>;` to `flake.nix`
- [ ] Change username / timezone / locale if it's not me
- [ ] UEFI or BIOS? Fix the boot loader if BIOS
- [ ] GPU block in the host file (section 3); fix PRIME bus IDs on hybrid laptops
- [ ] `nixos-rebuild build` → `boot` → reboot
- [ ] `journalctl -b -p err`, `nvidia-smi` / `vainfo`, `wpctl status`, test Bluetooth
- [ ] Commit the host folder
