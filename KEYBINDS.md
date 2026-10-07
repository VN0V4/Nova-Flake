# Hyprland Keybinds

All binds come from ChromaShell's `hypr/config/keybindings.lua`, with key names
from `hypr/config/variables.lua`. `Super` is the main modifier.

App names reflect this flake's settings (`programs.chromashell` in `flake.nix`).
Add your own binds in `~/.config/hypr/custom/keybindings.lua`, and rename keys
in `~/.config/hypr/custom/variables.lua`.

**Flags:** 🔒 = also works on the lock screen · 🔁 = repeats while held

## Launcher & shell

| Keys | Action |
| --- | --- |
| `Super` (tap) | Open the app launcher |
| `Super` + `N` | Toggle the sidebar |
| `Super` + `K` | Show all panels |
| `Super` + `L` | Lock the screen |
| `Super` + `Alt` + `L` | Restart the shell and lock (recovery if the lock screen crashes) 🔒 |
| `Ctrl` + `Alt` + `Delete` | Session menu (log out, reboot, shut down) |
| `Ctrl` + `Alt` + `C` | Clear notifications 🔒 |
| `Ctrl` + `Super` + `Shift` + `R` | Kill the Caelestia shell |
| `Ctrl` + `Super` + `Alt` + `R` | Restart the Caelestia shell |
| `Super` + `Shift` + `L` | Suspend, then hibernate 🔒 |

## Apps

| Keys | Action |
| --- | --- |
| `Super` + `T` | Terminal (kitty) |
| `Super` + `Return` | Terminal (kitty) |
| `Super` + `W` | Browser (Firefox) |
| `Super` + `C` | Editor (Zed) |
| `Super` + `E` | File manager (Thunar) |
| `Ctrl` + `Alt` + `Escape` | Process viewer (qps) |
| `Ctrl` + `Alt` + `V` | Volume mixer (pavucontrol) |

The terminal and file manager come from `general.apps` in
`~/.config/caelestia/shell.json`, read on each `hyprctl reload`.

## Special workspaces (scratchpads)

| Keys | Action |
| --- | --- |
| `Super` + `S` | Toggle the special workspace |
| `Super` + `M` | Toggle music (Spotify) |
| `Super` + `D` | Toggle communication (Vencord) |
| `Super` + `R` | Toggle todo |
| `Ctrl` + `Shift` + `Escape` | Toggle system monitor |

## Workspaces: navigate

| Keys | Action |
| --- | --- |
| `Super` + `1`…`9`, `0` | Go to workspace 1–10 |
| `Ctrl` + `Super` + `1`…`9`, `0` | Go to workspace group 1–10 |
| `Ctrl` + `Super` + `→` / `←` | Next / previous workspace 🔁 |
| `Super` + `Page Down` / `Page Up` | Next / previous workspace 🔁 |
| `Super` + scroll up / down | Next / previous workspace |
| `Ctrl` + `Super` + scroll up / down | Jump 10 workspaces forward / back |

## Workspaces: move the active window

| Keys | Action |
| --- | --- |
| `Super` + `Alt` + `1`…`9`, `0` | Move window to workspace 1–10 |
| `Ctrl` + `Super` + `Alt` + `1`…`9`, `0` | Move window to workspace group 1–10 |
| `Super` + `Alt` + `Page Down` / `Page Up` | Move window to next / previous workspace 🔁 |
| `Super` + `Alt` + scroll up / down | Move window to next / previous workspace |
| `Ctrl` + `Super` + `Shift` + `→` / `←` | Move window to next / previous workspace 🔁 |
| `Ctrl` + `Super` + `Shift` + `↑` | Move window to the special workspace |
| `Super` + `Alt` + `S` | Move window to the special workspace |
| `Ctrl` + `Super` + `Shift` + `↓` | Move window back from the special workspace |

## Windows: focus, move, resize

| Keys | Action |
| --- | --- |
| `Super` + arrows | Focus the window in that direction |
| `Super` + `Shift` + arrows | Move the window in that direction |
| `Super` + `Alt` + arrows | Resize by 100 px in that direction 🔁 |
| `Super` + `-` / `=` | Narrower / wider by 100 px 🔁 |
| `Super` + `Shift` + `-` / `=` | Shorter / taller by 100 px 🔁 |
| `Super` + left-drag | Move the window with the mouse |
| `Super` + `Z` + drag | Move the window with the mouse |
| `Super` + right-drag | Resize the window with the mouse |
| `Super` + `X` + drag | Resize the window with the mouse |

## Windows: actions

| Keys | Action |
| --- | --- |
| `Super` + `Q` | Close window |
| `Super` + `F` | Fullscreen |
| `Super` + `Alt` + `F` | Fullscreen, keeping gaps and borders |
| `Super` + `Alt` + `Space` | Toggle floating |
| `Super` + `P` | Pin (show on every workspace) |
| `Super` + `Alt` + `<` | Picture-in-picture |
| `Ctrl` + `Super` + `<` | Center the window |
| `Ctrl` + `Super` + `Alt` + `<` | Resize to 55 % × 70 % of the screen and center |

## Window groups (tabs)

| Keys | Action |
| --- | --- |
| `Super` + `,` | Turn the window into a group, or ungroup it |
| `Super` + `U` | Move the window out of its group |
| `Super` + `Shift` + `,` | Lock / unlock the active group |
| `Alt` + `Tab` | Cycle to the next window 🔁 |
| `Shift` + `Alt` + `Tab` | Cycle to the previous window 🔁 |
| `Ctrl` + `Alt` + `Tab` | Next tab in the group 🔁 |
| `Ctrl` + `Shift` + `Alt` + `Tab` | Previous tab in the group 🔁 |

## Screenshots, recording & color

| Keys | Action |
| --- | --- |
| `Print` | Screenshot 🔒 |
| `Super` + `Shift` + `S` | Screenshot a region (screen frozen) |
| `Super` + `Shift` + `Alt` + `S` | Screenshot a region |
| `Ctrl` + `Alt` + `R` | Start / stop screen recording |
| `Super` + `Alt` + `R` | Start / stop recording with sound |
| `Super` + `Shift` + `Alt` + `R` | Start / stop recording a selected region |
| `Super` + `Shift` + `C` | Color picker (copies to clipboard) |

## Clipboard & emoji

| Keys | Action |
| --- | --- |
| `Super` + `V` | Clipboard history |
| `Super` + `Alt` + `V` | Delete clipboard history entries |
| `Super` + `.` | Emoji picker |
| `Ctrl` + `Shift` + `Alt` + `V` | Type out the latest clipboard entry 🔒 |

## Media, volume & brightness

| Keys | Action |
| --- | --- |
| `Ctrl` + `Super` + `Space` | Play / pause 🔒 |
| `Ctrl` + `Super` + `=` | Next track 🔒 |
| `Ctrl` + `Super` + `-` | Previous track 🔒 |
| Media keys (Play, Pause, Next, Prev, Stop) | Media control 🔒 |
| Volume Up / Down keys | Volume ±10 % (also unmutes) 🔒 🔁 |
| Mute key | Mute speakers 🔒 |
| `Super` + `Shift` + `M` | Mute speakers 🔒 |
| Mic Mute key | Mute microphone 🔒 |
| Brightness Up / Down keys | Screen brightness 🔒 🔁 |
