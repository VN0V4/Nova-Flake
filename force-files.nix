{ lib, ... }:

# Default `force = true` for every Home Manager managed file, so existing
# files/links in the way are always replaced. Existing regular files are
# still moved to <name>.backup first (see home-manager.backupFileExtension).
let
  forced = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.force = lib.mkDefault true;
    });
  };
in
{
  options = {
    home.file      = forced;
    xdg.configFile = forced;
    xdg.dataFile   = forced;
    xdg.cacheFile  = forced;
    xdg.stateFile  = forced;
  };
}
