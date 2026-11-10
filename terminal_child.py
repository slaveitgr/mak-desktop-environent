"""Small exec helper: establish the owned PTY as the shell's controlling TTY."""
import fcntl
import os
import sys
import termios
from pathlib import Path

if __name__ == '__main__':
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    if os.environ.pop('MAKOS_TERMINAL_BANNER', '') == '1' and os.isatty(1):
        # Render output directly; never inject a command into an interactive PTY.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        try:
            from makos_fetch import main
            main([])
            sys.stdout.flush()
        except Exception:
            print('System information is unavailable.', flush=True)
    os.execvpe(sys.argv[1], sys.argv[1:], os.environ)
