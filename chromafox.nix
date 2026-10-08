# ChromaFox (the ChromaShell browser extension) and what release Firefox needs
# to run it. Shared by home-module.nix and nixos-module.nix.
#
# Release Firefox ignores xpinstall.signatures.required, and ChromaFox is unsigned.
# The signing requirement is a build-time constant there, but the add-on manager
# only enforces it for types in XPIDatabase.SIGNED_TYPES, so a privileged
# autoconfig (mozilla.cfg in the install dir, which the Nix wrapper uses) drops
# "extension" from that set. The enterprise policy then installs the XPI; Firefox
# doesn't scan the profile's extensions folder at startup, so dropping it there
# isn't enough.
#
# Note this turns signature checks off for all extensions, like
# xpinstall.signatures.required = false does on ESR/Developer Edition.
{ pkgs, dotfiles }:

rec {
  id = "chromafox@chromashell";

  xpi = pkgs.runCommand "chromafox" {
    nativeBuildInputs = [ pkgs.zip ];
  } ''
    mkdir -p $out
    cd ${dotfiles}/extra/chromafox
    zip -r $out/${id}.xpi manifest.json background.js content.js popup.html popup.css popup.js settings.html settings.css settings.js
  '';

  # Lines for mozilla.cfg (programs.firefox.autoConfig / wrapFirefox extraPrefs)
  autoConfig = ''
    // ChromaShell: allow the unsigned ChromaFox extension (see chromafox.nix)
    try {
      ChromeUtils.importESModule("resource://gre/modules/addons/XPIDatabase.sys.mjs")
        .XPIDatabase.SIGNED_TYPES.delete("extension");
    } catch (e) {
      Cu.reportError(e);
    }
  '';

  # ExtensionSettings policy entry. file:// installs are re-checked at every
  # startup, so a new build (version bump) is picked up automatically.
  extensionSettings.${id} = {
    installation_mode = "force_installed";
    install_url       = "file://${xpi}/${id}.xpi";
  };
}
