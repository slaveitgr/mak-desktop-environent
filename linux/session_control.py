#!/usr/bin/env python3
"""Openbox hotkeys talk only to this session's private local socket."""
import os
import socket
import sys


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('show', 'apps', 'terminal', 'logout', 'lock'):
        raise SystemExit('Usage: tahoe-session-control show|apps|terminal|logout|lock')
    address = os.environ.get('TAHOE_SESSION_SOCKET')
    if not address:
        raise SystemExit('No Tahoe session is active in this environment.')
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(3)
        client.connect(address)
        client.sendall((sys.argv[1] + '\n').encode('ascii'))
        if client.recv(128) != b'OK\n':
            raise SystemExit('The desktop did not accept the command.')


if __name__ == '__main__':
    main()
