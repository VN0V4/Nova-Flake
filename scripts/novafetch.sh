#!/usr/bin/env bash
# novafetch: run fastfetch with coloured ASCII art. By default it shows
# nova-art.txt shaded like a golden supernova.
#
# The fastfetch config is a read-only store symlink, so nothing here touches it.
# Your own art and colours live in ~/.config/novafetch/ and get passed to
# fastfetch as --logo flags.

set -euo pipefail

# The Nix package sets NOVA_ART; when run from the repo, use the file next to us.
nova_art="${NOVA_ART:-$(dirname "$(readlink -f "$0")")/nova-art.txt}"
dir="${XDG_CONFIG_HOME:-$HOME/.config}/novafetch"
user_logo="$dir/logo.txt"
conf="$dir/settings"
raw="${XDG_CACHE_HOME:-$HOME/.cache}/novafetch.raw"

usage() {
  cat <<'EOF'
Usage: novafetch [command] [args]

  (no command) [-- ARGS]      logo top-left, info box bottom-right of the terminal
                              (ARGS go to fastfetch; falls back to `side` if
                              the terminal is too small)
  side [ARGS]                 plain fastfetch layout, info box next to the logo
  -a, --animated [VIDEO ARGS] animated fetch (anifetch); plays the gold
                              supernova unless given a video and anifetch args
  set [FILE | -]              use your own art from FILE, stdin (-), or $EDITOR
  edit                        open your art in $EDITOR
  nova                        golden supernova shading (the default)
  colors C1 [C2 ... C9]       solid colours for $1..$9 in the art
  gradient FROM TO [DIR]      gradient over the art; DIR = vertical (default),
                              horizontal or diagonal
  preview                     print only the coloured art
  reset                       back to nova-art.txt in golden supernova style

Colours: names (red, bright_magenta), hex (#ff5fd7) or ANSI codes (38;5;200).
Gradients need hex colours.

In the art, write $1, $2 ... $9 where a colour should start; $$ is a literal $.
Without placeholders the whole art uses colour 1.

Examples:
  novafetch set ~/cat.txt
  novafetch colors '#f5c2e7' '#cba6f7'
  novafetch gradient '#f38ba8' '#89b4fa' diagonal
EOF
}

die() { echo "novafetch: $*" >&2; exit 1; }

# Your own art if you set one, otherwise nova-art.txt.
logo_file() {
  if [[ -f $user_logo ]]; then
    echo "$user_logo"
  else
    [[ -f $nova_art ]] || die "can't find nova-art.txt at $nova_art"
    echo "$nova_art"
  fi
}

# settings file: "nova", "colors C1 C2 ..." or "gradient FROM TO DIR"
read_settings() {
  mode=nova; args=()
  if [[ -f $conf ]]; then
    read -r mode rest <"$conf" || true
    read -ra args <<<"${rest:-}"
  fi
}

hex_rgb() {
  local h=${1#\#}
  [[ $h =~ ^[0-9a-fA-F]{6}$ ]] || die "gradient colours must be hex like #ff5fd7, got '$1'"
  printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# The renderers below write raw ANSI art to $raw and print "width height".

# Golden supernova: finds the densest spot as the core, then colours each
# character by its distance from it (white-hot core -> gold -> amber -> ember).
# Braille characters with more dots are brighter, so the art's own texture
# gives the shading.
render_nova() {
  LC_ALL=C.UTF-8 awk '
    function mix(a, b, t) { return int(a + (b - a) * t + 0.5) }
    function colour(t,   i, f) {
      if (t < 0) t = 0
      if (t > 1) t = 1
      t *= nstops - 1
      i = int(t); if (i >= nstops - 1) i = nstops - 2
      f = t - i
      return sprintf("\033[38;2;%d;%d;%dm", mix(R[i], R[i+1], f), mix(G[i], G[i+1], f), mix(B[i], B[i+1], f))
    }
    BEGIN {
      # white-hot core, pale gold, gold, amber, orange, deep ember
      split("255 255 255 255 245 217 157", R, " ")
      split("255 246 222 184 154 106  52", G, " ")
      split("244 212 112  48  31  20  12", B, " ")
      nstops = 7
      for (i = 1; i <= nstops; i++) { R[i-1] = R[i]; G[i-1] = G[i]; B[i-1] = B[i] }
      # dots in each braille character U+2800..U+28FF
      for (c = 0; c < 256; c++) {
        n = 0; for (v = c; v; v = int(v / 2)) n += v % 2
        dots[sprintf("%c", 0x2800 + c)] = n
      }
    }
    {
      gsub(/\$\$/, "\001"); gsub(/\$[1-9]/, ""); gsub(/\001/, "$")
      line[NR] = $0
      if (length($0) > width) width = length($0)
      for (x = 1; x <= length($0); x++) {
        ch = substr($0, x, 1)
        d[NR, x] = (ch in dots) ? dots[ch] : (ch == " " ? 0 : 5)
      }
    }
    END {
      height = NR
      # core = centre of the densest 7x3 window
      best = -1
      for (y = 1; y <= height; y++) for (x = 1; x <= width; x++) {
        s = 0
        for (dy = -1; dy <= 1; dy++) for (dx = -3; dx <= 3; dx++) s += d[y+dy, x+dx]
        if (s > best) { best = s; cy = y; cx = x }
      }
      # terminal cells are about twice as tall as wide
      maxr = 1
      for (y = 1; y <= height; y++) for (x = 1; x <= width; x++)
        if (d[y, x]) { r = sqrt((x-cx)^2 + (2*(y-cy))^2); if (r > maxr) maxr = r }

      for (y = 1; y <= height; y++) {
        out = ""
        for (x = 1; x <= length(line[y]); x++) {
          ch = substr(line[y], x, 1)
          if (!d[y, x]) { out = out ch; continue }
          r = sqrt((x-cx)^2 + (2*(y-cy))^2) / maxr
          # ease out so the gold glow reaches past the core, then let dense
          # characters shine brighter and sparse ones fade
          t = r ^ 0.8 + (4 - d[y, x]) * 0.06
          out = out colour(t) ch
        }
        print "\033[1m" out "\033[0m" > raw
      }
      print width, height
    }
  ' raw="$raw" "$1"
}

render_gradient() {
  local from to direction r1 g1 b1 r2 g2 b2
  from=${args[0]:-} to=${args[1]:-} direction=${args[2]:-vertical}
  read -r r1 g1 b1 <<<"$(hex_rgb "$from")"
  read -r r2 g2 b2 <<<"$(hex_rgb "$to")"

  local LC_ALL=C.UTF-8
  local lines=() line width=0 height d
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line//\$\$/$'\x01'}
    for d in 1 2 3 4 5 6 7 8 9; do line=${line//\$$d/}; done
    line=${line//$'\x01'/\$}
    lines+=("$line")
    (( ${#line} > width )) && width=${#line}
  done <"$1"
  height=${#lines[@]}

  local y x n steps out ch esc
  {
    for (( y = 0; y < height; y++ )); do
      line=${lines[y]} out=""
      if [[ $direction == vertical ]]; then
        steps=$(( height > 1 ? height - 1 : 1 ))
        printf -v esc '\e[38;2;%d;%d;%dm' \
          $(( r1 + (r2 - r1) * y / steps )) \
          $(( g1 + (g2 - g1) * y / steps )) \
          $(( b1 + (b2 - b1) * y / steps ))
        out+=$esc$line
      else
        if [[ $direction == horizontal ]]; then
          steps=$(( width > 1 ? width - 1 : 1 ))
        else
          steps=$(( width + height > 2 ? width + height - 2 : 1 ))
        fi
        for (( x = 0; x < ${#line}; x++ )); do
          ch=${line:x:1}
          if [[ $ch == " " ]]; then out+=" "; continue; fi
          n=$x; [[ $direction == diagonal ]] && n=$(( x + y ))
          printf -v esc '\e[38;2;%d;%d;%dm' \
            $(( r1 + (r2 - r1) * n / steps )) \
            $(( g1 + (g2 - g1) * n / steps )) \
            $(( b1 + (b2 - b1) * n / steps ))
          out+=$esc$ch
        done
      fi
      printf '\e[1m%s\e[0m\n' "$out"
    done
  } >"$raw"
  echo "$width $height"
}

# Fills the global array ff_args with the --logo flags for fastfetch.
logo_args() {
  local logo size w h i
  logo=$(logo_file)
  read_settings
  ff_args=()
  case $mode in
    nova|gradient)
      mkdir -p "$(dirname "$raw")"
      if [[ $mode == nova ]]; then size=$(render_nova "$logo"); else size=$(render_gradient "$logo"); fi
      read -r w h <<<"$size"
      ff_args=(--logo-type file-raw --logo "$raw" --logo-width "$w" --logo-height "$h")
      ;;
    colors)
      ff_args=(--logo-type file --logo "$logo")
      for i in "${!args[@]}"; do
        ff_args+=("--logo-color-$(( i + 1 ))" "${args[i]}")
      done
      ;;
    *) die "unknown mode '$mode' in $conf (try: novafetch reset)" ;;
  esac
}

# Logo in the top-left corner, info box pinned to the bottom-right, filling the
# terminal down to the prompt. Returns 1 (printing nothing) if it doesn't fit.
corner() {
  local rows cols size info="$raw.info"
  size=$(stty size </dev/tty 2>/dev/null) || return 1
  read -r rows cols <<<"$size"
  logo_args
  # fastfetch reports its parent process as the shell. Run it directly from this
  # script (no subshell, so the parent is us) and have it skip us, so it finds
  # your real shell.
  FFTS_IGNORE_PARENT=1 fastfetch --pipe false --logo none "$@" >"$info"
  LC_ALL=C.UTF-8 awk '
    function visible(s) { gsub(/\033\[[0-9;?]*[A-Za-z]/, "", s); return s }
    # drop blank lines at the start and end
    function trim(a, n,   i, j, k) {
      i = 1; while (i <= n && visible(a[i]) ~ /^[ \t⠀]*$/) i++
      j = n; while (j >= i && visible(a[j]) ~ /^[ \t⠀]*$/) j--
      for (k = i; k <= j; k++) a[k - i + 1] = a[k]
      return j - i + 1
    }
    FNR == 1 { file++ }
    file == 1 { logo[++nl] = $0 }
    file == 2 {
      # strip trailing padding so the box sits flush against the right edge
      sub(/( |\033\[[0-9;]*m)+$/, "")
      box[++nb] = $0 "\033[0m"
    }
    END {
      nl = trim(logo, nl); nb = trim(box, nb)
      for (i = 1; i <= nl; i++) if (length(visible(logo[i])) > lw) lw = length(visible(logo[i]))
      for (i = 1; i <= nb; i++) if (length(visible(box[i])) > bw) bw = length(visible(box[i]))
      height = rows - reserve
      if (lw + 2 + bw > cols || nl > height || nb > height) exit 1
      col = cols - bw + 1
      for (y = 1; y <= height; y++) {
        b = y - (height - nb)
        line = (y <= nl) ? logo[y] "\033[0m" : ""
        if (b >= 1) line = line "\033[" col "G" box[b]
        print line
      }
    }
  ' rows="$rows" cols="$cols" reserve="${NOVAFETCH_PROMPT_LINES:-2}" \
    <(fastfetch "${ff_args[@]}" --pipe false --structure none --logo-padding-top 0) \
    "$info"
}

cmd=${1:-}
[[ $# -gt 0 ]] && shift

case $cmd in
  ""|--)
    if ! { [[ -t 1 ]] && corner "$@"; }; then
      logo_args
      exec fastfetch "${ff_args[@]}" "$@"
    fi
    ;;
  side)
    logo_args
    exec fastfetch "${ff_args[@]}" "$@"
    ;;
  -a|--animated)
    # anifetch copies its video into its assets folder on every run, keeping
    # the read-only mode of store files, so the second copy would fail. Put a
    # writable copy there first; given that path, anifetch skips the copy.
    if [[ $# -eq 0 ]]; then
      [[ -n ${NOVA_VIDEO:-} ]] || die "no default video; try: novafetch -a VIDEO"
      video="${XDG_DATA_HOME:-$HOME/.local/share}/anifetch/assets/$(basename "$NOVA_VIDEO")"
      [[ -f $video ]] || install -D -m 644 "$NOVA_VIDEO" "$video"
      chmod u+w "$video"
      set -- "$video"
    fi
    exec anifetch "$@"
    ;;
  set)
    mkdir -p "$dir"
    src=${1:-}
    if [[ -z $src ]]; then
      [[ -f $user_logo ]] || cp -- "$(logo_file)" "$user_logo"
      exec "${EDITOR:-nano}" "$user_logo"
    elif [[ $src == - ]]; then
      cat >"$user_logo"
    else
      [[ -f $src ]] || die "no such file: $src"
      cp -- "$src" "$user_logo"
    fi
    echo "Saved art to $user_logo"
    ;;
  edit)
    mkdir -p "$dir"
    [[ -f $user_logo ]] || cp -- "$(logo_file)" "$user_logo"
    chmod u+w "$user_logo"
    exec "${EDITOR:-nano}" "$user_logo"
    ;;
  nova)
    rm -f -- "$conf"
    echo "Golden supernova style set."
    ;;
  colors|colours)
    [[ $# -ge 1 && $# -le 9 ]] || die "give 1 to 9 colours"
    mkdir -p "$dir"
    echo "colors $*" >"$conf"
    echo "Colours set: $*"
    ;;
  gradient)
    [[ $# -ge 2 ]] || die "usage: novafetch gradient FROM TO [vertical|horizontal|diagonal]"
    hex_rgb "$1" >/dev/null; hex_rgb "$2" >/dev/null
    case ${3:-vertical} in vertical|horizontal|diagonal) ;; *) die "direction must be vertical, horizontal or diagonal" ;; esac
    mkdir -p "$dir"
    echo "gradient $1 $2 ${3:-vertical}" >"$conf"
    echo "Gradient set: $1 -> $2 (${3:-vertical})"
    ;;
  preview)
    logo_args
    exec fastfetch "${ff_args[@]}" --structure none --logo-padding-top 0 "$@"
    ;;
  reset)
    rm -f -- "$user_logo" "$conf" "$raw"
    echo "Reset to nova-art.txt in golden supernova style."
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
