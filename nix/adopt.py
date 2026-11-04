"""Archive only legacy links owned by this checkout before Home Manager adoption."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply', action='store_true', help='move verified legacy links into a timestamped backup')
parser.add_argument('--source', type=Path, default=Path.home() / '.dotfiles')
args = parser.parse_args()
source = args.source.expanduser().resolve()
home = Path.home()
config = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
state = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
if not (source / 'quickshell/shell.qml').is_file():
    sys.exit('Source must be a dotfiles checkout containing quickshell/shell.qml')

targets = {
    **{config / 'hypr' / p.name: p for p in (source / 'hypr').iterdir()
       if p.suffix == '.lua' or p.name == 'hypridle.conf'},
    **{config / 'quickshell' / p.name: p for p in (source / 'quickshell').iterdir()
       if p.suffix in ['.qml', '.json'] or p.name in ['components', 'lock', 'polkit', 'greeter']},
    config / 'kitty/kitty.conf': source / 'kitty/kitty.conf',
    config / 'kitty/shaders': source / 'kitty/shaders',
    config / 'tmux/tmux.conf': source / 'tmux/tmux.conf',
    home / '.local/bin/qs-lock': source / 'quickshell/qs-lock',
    **{config / 'systemd/user' / (name + '.service'): source / 'quickshell' / (name + '.service')
       for name in ['quickshell', 'quickshell-lock', 'quickshell-polkit']},
}
plan = []
errors = []
for target, expected in targets.items():
    if target.is_symlink():
        if os.readlink(target).startswith('/nix/store/'):
            print('Already store-managed:', target)
        elif target.resolve() == expected.resolve():
            plan.append(target)
        else:
            errors.append(f'Foreign link: {target}')
    elif target.exists():
        errors.append(f'Existing real file/directory: {target}')
if errors:
    sys.exit('\n'.join(errors) + '\nNo files changed. Resolve these ownership conflicts first.')
for target in plan:
    print(('Archive: ' if args.apply else 'Would archive: ') + str(target))
if not args.apply:
    print('Dry run only. Re-run with --apply immediately before Home Manager switch.')
    sys.exit(0)
if not plan:
    sys.exit(0)
backup = state / 'dotfiles/adoption' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
backup.mkdir(parents=True)
# Preserve absolute target paths beneath the backup so external XDG homes work.
for target in plan:
    destination = backup / str(target).lstrip('/')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(target), str(destination))
print('Backup:', backup)
print('Apply Home Manager next. No services were stopped or restarted.')
