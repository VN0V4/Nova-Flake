inputs:

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.programs.chromashell;

  audioPath = lib.makeBinPath [
    pkgs.pipewire
    pkgs.jq
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gawk
    pkgs.bash
  ];

  # The chains are wired to one fixed device (runtime/routing.json), so plugging
  # in headphones or connecting a Bluetooth headset changes nothing. This follows
  # the device WirePlumber ranks highest (priority.session: Bluetooth > built-in)
  # and re-routes the general/chat buses and the mic chain whenever devices
  # appear or disappear.
  audioFollow = pkgs.writeShellApplication {
    name = "chromashell-audio-follow";
    runtimeInputs = with pkgs; [ pipewire pulseaudio jq coreutils gnugrep gawk bash ];
    text = ''
      audio_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/chromashell/audio"
      routing="$audio_dir/runtime/routing.json"

      # Highest-priority node whose name matches $1 (newest wins a tie)
      pick() {
        pw-dump | jq -r --arg re "$1" '
          [ .[] | select(.type == "PipeWire:Interface:Node")
            | { id, name: .info.props."node.name", prio: (.info.props."priority.session" // 0) }
            | select((.name // "") | test($re)) ]
          | sort_by([.prio, .id]) | last | .name // empty'
      }

      current() { jq -r --arg bus "$1" '.[$bus] // ""' "$routing" 2>/dev/null || true; }

      # Drop every device link on node $1 (direction $2: "->" out, "<-" in) except
      # those to $3. routing.json can't be trusted for this: start-audio.sh restores
      # the saved device concurrently with our first sync, one of the two writes is
      # lost, and the old device stayed linked too (sound on speakers AND headset).
      prune() {
        local node="$1" dir="$2" keep="$3" port peer
        pw-link -l | awk -v node="$node:" -v dir="|$dir" '
          /^[^ ]/ { cur = $0; next }
          index(cur, node) == 1 && $1 == dir { print cur "\t" $2 }' \
        | while IFS=$'\t' read -r port peer; do
            [[ "$peer" == "$keep:"* ]] && continue
            if [[ "$dir" == "->" ]]; then pw-link -d "$port" "$peer" 2>/dev/null || true
            else pw-link -d "$peer" "$port" 2>/dev/null || true; fi
          done
      }

      link_mic() {
        local dev="$1" old="$2"
        if [[ -n "$old" && "$old" != "$dev" ]]; then
          for p in MONO FL FR; do
            for c in FL FR; do pw-link -d "$old:capture_$p" "mic_chain_in:playback_$c" 2>/dev/null || true; done
          done
        fi
        # Headset mics are mono: feed the one channel into both chain inputs
        if pw-link -o | grep -q "^$dev:capture_MONO$"; then
          pw-link -P "$dev:capture_MONO" mic_chain_in:playback_FL 2>/dev/null || true
          pw-link -P "$dev:capture_MONO" mic_chain_in:playback_FR 2>/dev/null || true
        else
          pw-link -P "$dev:capture_FL" mic_chain_in:playback_FL 2>/dev/null || true
          pw-link -P "$dev:capture_FR" mic_chain_in:playback_FR 2>/dev/null || true
        fi
        mkdir -p "$(dirname "$routing")"
        { cat "$routing" 2>/dev/null || echo '{}'; } \
          | jq --arg dev "$dev" '.mic = $dev' > "$routing.tmp" && mv "$routing.tmp" "$routing"
      }

      sync() {
        local sink source bus old
        sink=$(pick '^(alsa_output|bluez_output)\.')
        source=$(pick '^(alsa_input|bluez_input)\.')

        if [[ -n "$sink" ]]; then
          for bus in general chat; do
            old=$(current "$bus")
            [[ "$old" != "$sink" ]] && echo "$bus: $old -> $sink"
            # Re-link even when unchanged: a reconnected device comes back without links
            bash "$audio_dir/audio-route.sh" "$bus" "$sink" ""
            # A headset in call mode (HFP) has a single playback_MONO port, which
            # audio-route.sh's FL/FR links miss: downmix both channels into it
            if pw-link -i | grep -q "^$sink:playback_MONO$"; then
              pw-link -P "''${bus}_chain_out:capture_FL" "$sink:playback_MONO" 2>/dev/null || true
              pw-link -P "''${bus}_chain_out:capture_FR" "$sink:playback_MONO" 2>/dev/null || true
            fi
            prune "''${bus}_chain_out" "->" "$sink"
          done
        fi
        if [[ -n "$source" ]]; then
          old=$(current mic)
          [[ "$old" != "$source" ]] && echo "mic: $old -> $source"
          link_mic "$source" "$old"
          prune mic_chain_in "<-" "$source"
        fi
      }

      # Wait for the chains (chromashell-audio.service) to be up
      until pw-link -o 2>/dev/null | grep -q '^general_chain_out:' \
         && pw-link -i 2>/dev/null | grep -q '^mic_chain_in:'; do
        sleep 0.5
      done
      sync
      # start-audio.sh may still be restoring the saved routing; sweep up after it
      sleep 5
      sync

      device_event="'(new|remove)' on (sink|source) "
      pactl subscribe | while read -r line; do
        [[ "$line" =~ $device_event ]] || continue
        # Debounce: a device connecting fires several events in a row
        while read -r -t 1 _; do :; done
        sync
      done
    '';
  };
in
{
  config = mkIf (cfg.enable && cfg.audio.enable) {

    # LV2 symlinks kept for manual debugging with jalv/lv2ls; the chains
    # themselves resolve plugins via LV2_PATH/LADSPA_PATH below.
    home.file = {
      ".lv2/lsp-plugins.lv2".source = "${pkgs.lsp-plugins}/lib/lv2/lsp-plugins.lv2";
      ".lv2/fil4.lv2".source        = "${pkgs.x42-plugins}/lib/lv2/fil4.lv2";
    };

    # Audio chains — own PipeWire client instance hosting the filter-chain
    # graphs (chains.conf). Starts with WirePlumber, restarts on crash.
    systemd.user.services.chromashell-audio = {
      Unit = {
        Description = "ChromaShell audio chains (PipeWire filter-chains)";
        After    = [ "wireplumber.service" "pipewire.service" ];
        PartOf   = [ "wireplumber.service" ];
        Requires = [ "wireplumber.service" "pipewire.service" ];
      };
      Service = {
        Type        = "simple";
        ExecStart   = "${config.xdg.configHome}/chromashell/audio/start-audio.sh";
        Restart     = "on-failure";
        RestartSec  = "3s";
        Environment = [
          "PATH=${audioPath}"
          "LADSPA_PATH=${pkgs.deepfilternet}/lib/ladspa"
          "LV2_PATH=${pkgs.lsp-plugins}/lib/lv2:${pkgs.x42-plugins}/lib/lv2"
        ];
        StandardOutput = "journal";
        StandardError  = "journal";
      };
      Install.WantedBy = [ "wireplumber.service" ];
    };

    systemd.user.services.chromashell-audio-follow = {
      Unit = {
        Description = "ChromaShell audio: follow the preferred output/input device";
        After    = [ "chromashell-audio.service" ];
        PartOf   = [ "chromashell-audio.service" ];
        Requires = [ "chromashell-audio.service" ];
      };
      Service = {
        Type       = "simple";
        ExecStart  = "${audioFollow}/bin/chromashell-audio-follow";
        Restart    = "on-failure";
        RestartSec = "3s";
      };
      # default.target too: Home Manager only starts new units wanted by a target,
      # so with chromashell-audio already running this one would otherwise stay
      # dead until the next login
      Install.WantedBy = [ "chromashell-audio.service" "default.target" ];
    };

  };
}
