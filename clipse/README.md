# clipse

Personal configuration for clipse 1.2.1. Install the application separately
through the machine's Nix configuration, then deploy from the dotfiles root:

```sh
./deploy/deploy clipse
./deploy/deploy --undo clipse
```

Only `config.json` and `custom_theme.json` are linked. History, cached images,
logs and backups remain in `~/.config/clipse/`, outside this repository.
The theme file is retained with `useCustomTheme: false` (built-in appearance).

Hyprland owns the `clipse -listen` autostart, Super+V shortcut, dedicated Kitty
font/size and floating window rule. Other desktops must supply their own
startup and shortcut integration. Do not start multiple listeners.

Image previews use the Kitty graphics protocol: launch in Kitty, select an
image and press Space. The list shows filenames, not inline thumbnails.
For another terminal, choose a supported `imageDisplay.type` such as `basic`.

| Key | Action |
| --- | --- |
| j / k | Down / up |
| h / l | Previous / next page |
| g / G | First / last item |
| J / K | Select down / up |
| s / S | Select item / clear selection |
| / | Search |
| Space | Preview / return |
| Enter | Copy |
| q | Back / quit |
| x | Delete item |
| p / Tab | Pin item / show pinned |
| ? | Help |

Use the literal `space` in the config, not a whitespace-only string: clipse
1.2.1 trims key names before parsing them. Search mode accepts typed letters.
