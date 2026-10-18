# Yazi

General settings, keymaps and Lua initialization live here. Nix installs Yazi,
its runtime dependencies and the git, piper, toggle-pane and chmod plugins via
`~/nix-config/home/modules/yazi.nix`. Do not also manage these plugins with
`ya pkg`: their versions follow `flake.lock`.

After changing the Nix module, run `nh home switch path:.` from `~/nix-config`,
then run `./deploy/deploy yazi` from `~/.dotfiles` and restart Yazi.

Text opens in `$EDITOR`; images, PDFs and other documents use the desktop's
file associations. Archives retain Yazi's built-in extraction action. `O`
chooses an opener interactively, and `e` explicitly opens a selection in the
editor. Existing natural sorting, hidden files and pane proportions are kept.

Local Markdown is rendered with Glow. Git status appears alongside file sizes;
other file types retain the built-in previewers.

| Key | Action |
| --- | --- |
| `g o` | Open the current directory in the default GUI file manager |
| `T` | Maximize or restore the preview pane |
| `g p` | Hide or show the preview pane |
| `c m` | Edit permissions of selected files |
| `e` | Edit selected files in `$EDITOR` |

Useful defaults (unchanged):

| Key | Action |
| --- | --- |
| `z` / `Z` | Fzf file/directory picker / Zoxide directory history |
| `s` / `S` | Search names / file contents |
| `f` / `/` | Filter the listing / find within the listing |
| `Tab` | Inspect file details |
| `t t` / `t r` | New tab / rename tab |
| `g t` | Browse trash; `O` offers restoration |
| `d` / `D` | Move to trash / permanently delete (with confirmation) |
| `r` | Rename; multiple selections use the editor for bulk renaming |
| `~` | Open help and search commands |
