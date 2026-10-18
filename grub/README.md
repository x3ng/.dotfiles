# GRUB appearance

Graphite is a plain black theme with bright white selected text and dim gray unselected text.
It has no heading or subtitle: a tall menu area, subdued keyboard
hints and a countdown provide the layout. Spacing and text colors supply the visual
hierarchy, without bitmap assets or an image-based selection bar.
Only appearance is managed here. NixOS owns the EFI executable, grub.cfg,
kernel paths, default entry, timeout, and generation submenus.

The theme contains no distribution-specific labels or boot entries. Menu
entry names come from the host bootloader configuration. The NixOS integration
below is one host adapter; other GRUB systems can source the same custom.cfg.

## NixOS integration

The NixOS configuration must contain this optional hook:

```nix
boot.loader.grub = {
  theme = null;
  splashImage = null;
  extraConfig = ''
    if [ -f "$prefix/custom.cfg" ]; then
      source "$prefix/custom.cfg"
    fi
  '';
};
```

For the first application, deploy the theme before activating the NixOS hook.
From the dotfiles root:

```sh
./deploy/deploy --dry-run grub
sudo ./deploy/deploy grub
```

Then, on this host, apply the NixOS configuration:

```sh
cd ~/nix-config
sudo nixos-rebuild switch --flake .#ocean
```

Review pending NixOS changes first: switch applies the whole host configuration,
not just the theme hook. Once switch succeeds, check that the generated menu
contains both the optional loader and the NixOS entries before rebooting:

```sh
sudo rg -n 'source.*custom[.]cfg|menuentry|submenu' /boot/grub/grub.cfg
```

Reboot to see the theme; switch does not change the currently running desktop.
Do not reboot into a new configuration after a failed switch until its error
has been resolved. Deploying resources first is harmless while the previous
GRUB configuration has no custom.cfg hook.

After the hook has been applied once, theme changes only require the dotfiles
deploy command, followed by a reboot to view them. No further NixOS rebuild is
needed for appearance alone. Disable the theme from the dotfiles root with:

```sh
sudo ./deploy/deploy --undo grub
```

Uninstall removes the optional loader first, then removes recognized
legacy dotfiles-graphite resource directories. Unknown files and symlinks are
retained with a warning. Cleanup works even if an earlier uninstall already
removed custom.cfg. No rebuild is needed to return to the ordinary menu.

The theme is intentionally absent from the TUI/GUI profiles. The default
destination is /boot/grub; /boot must be mounted. GRUB_DIR can select another
distribution's GRUB directory. That distribution must also source custom.cfg.
No EFI installation or grub-mkconfig command is run by this installer.

The installer refuses to replace an unmanaged custom.cfg. It copies resources
to a versioned directory under grub/themes before atomically publishing
custom.cfg. Existing versions remain for recovery. Repeat installs are
idempotent; replacing a managed loader saves a backup. If GRUB_SCRIPT_CHECK is
set, it must name a grub-script-check executable; otherwise the tool is used
when available on PATH.

Missing custom.cfg leaves the ordinary menu. Missing theme files or fonts leave
the ordinary menu too. The loader does not change boot entries, root, prefix,
default, timeout, or terminal output. A malformed external configuration is not
covered by the missing-file fallback, so inspect changes before deploying them.

## Countdown

The `__timeout__` label displays GRUB's existing countdown; it does not set
its duration. NixOS still owns `boot.loader.timeout` (5 seconds by default).
Pressing a key in the menu normally cancels automatic boot for that visit.
Generation submenus do not necessarily inherit the main menu countdown.

## Recovery

This theme is external state: selecting an older NixOS generation does not
restore an older dotfiles theme. Disable it by uninstalling or renaming
/boot/grub/custom.cfg. At an interactive GRUB console, `unset theme` followed
by Escape can return to an ordinary menu if the menu itself is still loaded.

If the bootloader cannot run, use a NixOS live USB. For this host's current
layout, mount the root partition and then the EFI partition:

```sh
sudo mount /dev/nvme0n1p2 /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mv /mnt/boot/grub/custom.cfg /mnt/boot/grub/custom.cfg.disabled
```

Verify device names and mount points with lsblk before using these commands.
Removing the optional loader addresses theme problems, not a damaged EFI
executable. For actual bootloader repair, use nixos-enter and reinstall the
bootloader from a known working configuration, following the NixOS recovery
documentation. Do not replace NixOS's generated grub.cfg with grub-mkconfig.

## Assets

theme.txt was created for this theme. Selection uses text colors; no PNG or
other bitmap assets are installed or loaded. The bundled PF2
fonts were generated from DejaVu Sans at sizes 16, 20 and 32 using grub-mkfont.
See graphite/LICENSE-DejaVu.txt for the font license. Theme code uses only
relative asset paths; it has no dependency on this dotfiles checkout at boot.
