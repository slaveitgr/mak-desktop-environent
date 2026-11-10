#!/usr/bin/env python3
"""Small read-only startup inventory; the logo is ours, the host facts are real."""
import argparse
import re
import sys
from system_info import collect_system_info

LOGO = (
    '                 _     ___  ____',
    '  _ __ ___   __ _| | __/ _ \\/ ___|',
    " | '_ ` _ \\ / _` | |/ / | | \\___ \\",
    ' | | | | | | (_| |   <| |_| |___) |',
    ' |_| |_| |_|\\__,_|_|\\_\\___/|____/',
)


def clean(value):
    # Host-controlled model/hostname strings are data, never terminal escapes.
    return re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', str(value)).strip()


def render(info, color=True):
    rows = [('makOS', info.get('version', 'Not available')),
            ('Platform', info.get('platform', 'Not available')),
            ('Computer', info.get('model', 'Not available')),
            ('Kernel', info.get('kernel', 'Not available')),
            ('Architecture', info.get('architecture', 'Not available')),
            ('CPU', info.get('processor', 'Not available')),
            ('GPU', info.get('graphics', 'Not available')),
            ('Memory', info.get('memory', 'Not available'))]
    cyan, bold, reset = ('\033[36m', '\033[1m', '\033[0m') if color else ('', '', '')
    width = max(map(len, LOGO)) + 4
    lines = ['']
    for index in range(max(len(LOGO), len(rows))):
        logo = LOGO[index] if index < len(LOGO) else ''
        fact = (bold + rows[index][0] + reset + ': ' + clean(rows[index][1])) if index < len(rows) else ''
        lines.append(cyan + logo + reset + ' ' * (width - len(logo)) + fact)
    return '\n'.join(lines) + '\n\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description='Show the makOS logo and actual local system information.')
    parser.add_argument('--no-color', action='store_true')
    args = parser.parse_args(argv)
    sys.stdout.write(render(collect_system_info(), color=not args.no_color and sys.stdout.isatty()))


if __name__ == '__main__':
    main()
