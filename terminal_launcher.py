"""x-terminal-emulator -e adapter; argv is never evaluated by a shell."""
import os
from pathlib import Path
import sys


def command(arguments, source, home):
    result = [str(source / 'main.py'), '--root', str(home), '--cutefish-app', 'terminal']
    if arguments:
        if arguments[0] != '-e' or len(arguments) < 2:
            raise ValueError('Usage: makos-terminal [-e command [argument ...]]')
        result += ['--terminal-execute', *arguments[1:]]
    else:
        result += ['--new-window']
    return result


if __name__ == '__main__':
    try:
        arguments = command(sys.argv[1:], Path(__file__).resolve().parent, Path.home())
    except ValueError as error:
        print(error, file=sys.stderr); sys.exit(2)
    os.execv(sys.executable, [sys.executable, *arguments])
