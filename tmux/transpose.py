#!/usr/bin/env python3
"""Transpose a leaf-only tmux 3.8 layout group; never rebuild nested groups."""
import argparse
import hashlib
import json
import shlex
import subprocess
import uuid

PREFIX = '@dotfiles_transpose_'


def layout_group(layout, pane):
    document = json.loads(layout)
    if document.get('V') != 2 or set(document) != {'V', 'L'}:
        raise ValueError('Only tmux V2 tiled layouts are supported')

    def visit(node):
        if node.get('t') == 'p':
            return None
        if node.get('t') not in ('h', 'v') or not node.get('c'):
            raise ValueError('Unsupported layout node')
        if any(child.get('I') == pane for child in node['c']):
            return node
        for child in node['c']:
            found = visit(child)
            if found is not None:
                return found
        return None

    parent = visit(document['L'])
    if parent is None:
        raise ValueError('No split group for this pane')
    if len(parent['c']) < 2 or any(c.get('t') != 'p' for c in parent['c']):
        raise ValueError('Parent contains nested groups; transpose a smaller group instead')
    return document, parent


def shape(group):
    """Focus changes do not change the geometry or membership of a group."""

    def geometry(node):
        result = {key: node[key] for key in ('t', 'x', 'y', 'w', 'h', 'I') if key in node}
        if 'c' in node:
            result['c'] = [geometry(child) for child in node['c']]
        return result
    return geometry(group)


def transpose(layout, pane, previous='', applied=''):
    """Toggle one group; retain its prior geometry to avoid rounding drift."""
    document, parent = layout_group(layout, pane)
    children = parent['c']
    labels = [str(c.get('i', c['I'])) for c in children]
    if previous and applied:
        try:
            _, prior_group = layout_group(previous, pane)
            _, applied_group = layout_group(applied, pane)
            if shape(parent) == shape(applied_group):
                current_children = {c['I']: c for c in children}
                parent['t'] = prior_group['t']
                for old_child in prior_group['c']:
                    child = current_children[old_child['I']]
                    for key in ('x', 'y', 'w', 'h'):
                        child[key] = old_child[key]
                return json.dumps(document, separators=(',', ':')), labels
        except (ValueError, KeyError, TypeError):
            pass  # A stale cache cannot override the current layout.
    direction = 'v' if parent['t'] == 'h' else 'h'
    old_axis = 'w' if parent['t'] == 'h' else 'h'
    axis = 'w' if direction == 'h' else 'h'
    position = 'x' if direction == 'h' else 'y'
    available = parent[axis] - len(children) + 1
    if available < 2 * len(children) or min(parent['w'], parent['h']) < 2:
        raise ValueError('Not enough space to transpose this group')
    # Preserve relative sizes, within terminal-cell rounding and a 2-cell minimum.
    weights = [c[old_axis] for c in children]
    total = sum(weights)
    numerators = [available * weight for weight in weights]
    sizes = [n // total for n in numerators]
    for i in sorted(range(len(children)), key=lambda i: numerators[i] % total,
                    reverse=True)[:available - sum(sizes)]:
        sizes[i] += 1
    if min(sizes) < 2:
        raise ValueError('Not enough space to preserve this group proportions')
    offset = parent[position]
    for child, size in zip(children, sizes):
        for key in ('x', 'y', 'w', 'h'):
            child[key] = parent[key]
        child[axis] = size
        child[position] = offset
        offset += size + 1
    parent['t'] = direction
    return json.dumps(document, separators=(',', ':')), labels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--socket', required=True)
    parser.add_argument('--pane', required=True)
    args = parser.parse_args()
    base = ['tmux', '-S', args.socket]

    def tmux(*words):
        return subprocess.check_output(base + list(words), text=True, stderr=subprocess.PIPE).strip()

    def message(text):
        # The target may have closed while the external helper was running.
        subprocess.run(base + ['display-message', '-t', args.pane, 'Transpose: ' + text],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

    try:
        window, zoomed, floating, layout = tmux(
            'display-message', '-p', '-t', args.pane,
            '#{window_id}\t#{window_zoomed_flag}\t#{pane_floating_flag}\t#{window_layout}'
        ).split('\t', 3)
        if zoomed == '1' or floating == '1':
            raise ValueError('Unzoom and focus a tiled pane first')
        _, group = layout_group(layout, args.pane)
        identity = ','.join(sorted(c['I'] for c in group['c']))
        cache = PREFIX + hashlib.sha256(identity.encode()).hexdigest()[:16] + '_'
        previous = tmux('show-options', '-wqv', '-t', window, cache + 'before')
        applied = tmux('show-options', '-wqv', '-t', window, cache + 'after')
        target, panes = transpose(layout, args.pane, previous, applied)
        notice = 'panes ' + ', '.join(panes) + ' transposed'
        # Test and apply in tmux's command queue, so layout changes after our read
        # cannot silently cause an old snapshot to overwrite a new arrangement.
        quote = shlex.quote
        expected = PREFIX + 'expected_' + uuid.uuid4().hex
        tmux('set-option', '-w', '-t', window, expected, layout)
        commands = [f'select-layout -t {quote(window)} {quote(target)}']
        commands += [
            f'set-option -w -t {quote(window)} {cache}before {quote(layout)}',
            f'set-option -wF -t {quote(window)} {cache}after {quote("#{window_layout}")}',
        ]
        commands.append(f'display-message -t {quote(args.pane)} {quote("Transpose: " + notice)}')
        guard = '#{&&:#{==:#{window_layout},#{' + expected + '}},#{==:#{window_zoomed_flag},0}}'
        tmux('if-shell', '-F', '-t', args.pane, guard, ' ; '.join(commands),
             'display-message "Transpose: layout changed; retry"',
             ';', 'set-option', '-wu', '-t', window, expected)
    except (ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        message(detail)


if __name__ == '__main__':
    main()
