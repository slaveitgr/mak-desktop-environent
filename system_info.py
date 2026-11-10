"""Read-only About This Mak inventory: no serials, privileged probes or network.

Linux MemTotal means usable RAM, not an invented installed DIMM capacity.
"""
import getpass
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import socket
import subprocess
import sys

UNAVAILABLE = 'Not available'
_PLACEHOLDERS = {'', 'none', 'unknown', 'default string', 'system product name',
                 'system manufacturer', 'to be filled by o.e.m.', 'not specified'}


def _text(path, limit=65536):
    try:
        with Path(path).open('rb') as source:
            return source.read(limit).decode('utf-8', errors='replace').replace('\0', '').strip()
    except OSError:
        return ''


def _clean(value):
    return ' '.join(str(value).split())


def _model_text(value):
    value = _clean(value)
    return '' if value.lower() in _PLACEHOLDERS else value


def _command(arguments):
    try:
        result = subprocess.run(arguments, capture_output=True, text=True,
                                timeout=2, check=False,
                                env={**os.environ, 'LC_ALL': 'C'})
        return result.stdout[:262144] if result.returncode == 0 else ''
    except (OSError, subprocess.SubprocessError):
        return ''


def _release(path):
    """Parse data rather than executing/sourcing os-release shell syntax."""
    result = {}
    for line in _text(path).splitlines():
        if '=' not in line or line.lstrip().startswith('#'):
            continue
        key, value = line.split('=', 1)
        if not re.fullmatch(r'[A-Z_][A-Z_0-9]*', key):
            continue
        try:
            tokens = shlex.split(value, comments=True)
        except ValueError:
            continue
        if len(tokens) == 1:
            result[key] = tokens[0]
    return result


def _memory_text(size):
    if size <= 0:
        return UNAVAILABLE
    return ('%.1f' % (size / (1024 ** 3))).rstrip('0').rstrip('.') + ' GiB'


def _linux_graphics(root, command, which):
    executable = which('lspci')
    graphics = []
    if executable:
        # Local PCI ID database only; never -q/-Q (DNS lookup).
        for line in command([executable, '-D', '-mm', '-nn']).splitlines():
            try:
                fields = shlex.split(line)
            except ValueError:
                continue
            if len(fields) < 4 or not re.search(r'\[03[0-9a-f]{2}\]$', fields[1], re.I):
                continue
            vendor, device = (re.sub(r'\s*\[[0-9a-f]{4}\]$', '', x, flags=re.I)
                              for x in fields[2:4])
            name = device if device.lower().startswith(vendor.lower()) else vendor + ' ' + device
            name = _clean(name)
            if name and name not in graphics:
                graphics.append(name)
    if not graphics:
        try:
            cards = sorted((root / 'sys/class/drm').iterdir())[:128]
        except OSError:
            cards = []
        for card in cards:
            if not re.fullmatch(r'card\d+', card.name):
                continue
            vendor, device = (_text(card / 'device' / key, 32) for key in ('vendor', 'device'))
            if re.fullmatch(r'0x[0-9a-f]{4}', vendor, re.I) and re.fullmatch(r'0x[0-9a-f]{4}', device, re.I):
                name = 'PCI ' + vendor[2:] + ':' + device[2:] + ' (model unavailable)'
                if name not in graphics:
                    graphics.append(name)
    return '\n'.join(graphics) or UNAVAILABLE


def collect_system_info(root='/', *, platform_name=None, command=None, which=None):
    """The injectable root and command callbacks allow tests with fixtures only."""
    root = Path(root)
    target = sys.platform if platform_name is None else platform_name
    command = command or _command
    which = which or shutil.which
    computer = _clean(socket.gethostname()) or UNAVAILABLE
    try:
        user = getpass.getuser()
    except (KeyError, OSError):
        user = 'User'
    model, manufacturer, cpu, graphics, memory = '', '', '', UNAVAILABLE, 0
    release = {}
    host_platform = platform.platform()
    memory_source = ''
    if target.startswith('linux'):
        dmi = root / 'sys/class/dmi/id'
        manufacturer = _model_text(_text(dmi / 'sys_vendor', 4096))
        model = _model_text(_text(dmi / 'product_name', 4096))
        if not model:
            model = _model_text(_text(root / 'sys/firmware/devicetree/base/model', 4096))
        if model and manufacturer and not model.casefold().startswith(manufacturer.casefold()):
            model = manufacturer + ' ' + model
        fields = {}
        for line in _text(root / 'proc/cpuinfo', 262144).splitlines():
            if ':' in line:
                key, value = line.split(':', 1)
                fields.setdefault(key.strip().lower(), _clean(value))
        cpu = fields.get('model name', '') or fields.get('hardware', '')
        if not cpu and fields.get('processor', '') and not fields['processor'].isdigit():
            cpu = fields['processor']
        match = re.search(r'^MemTotal:\s*(\d+)\s+kB\s*$', _text(root / 'proc/meminfo'), re.M)
        if match:
            memory = int(match.group(1)) * 1024
            memory_source = 'Kernel-reported usable RAM'
        graphics = _linux_graphics(root, command, which)
        release = _release(root / 'etc/os-release') or _release(root / 'usr/lib/os-release')
        host_platform = release.get('PRETTY_NAME') or release.get('NAME') or 'Linux'
    elif target == 'darwin':
        model = _clean(command(['/usr/sbin/sysctl', '-n', 'hw.model']))
        cpu = _clean(command(['/usr/sbin/sysctl', '-n', 'machdep.cpu.brand_string']))
        raw_memory = _clean(command(['/usr/sbin/sysctl', '-n', 'hw.memsize']))
        if raw_memory.isdigit():
            memory = int(raw_memory)
            memory_source = 'Physical memory'
        version = _clean(command(['/usr/bin/sw_vers', '-productVersion']))
        host_platform = 'macOS' + (' ' + version if version else '')
    running_makos = target.startswith('linux') and release.get('ID', '').lower() == 'makos'
    version = (release.get('VERSION') or release.get('VERSION_ID') or UNAVAILABLE) if running_makos else 'Development preview'
    return {'name': model or computer, 'model': model or UNAVAILABLE,
            'modelSource': 'macOS-reported model identifier' if target == 'darwin' else 'Firmware-reported model' if model else 'Host name fallback',
            'computerName': computer, 'manufacturer': manufacturer or UNAVAILABLE,
            'processor': cpu or UNAVAILABLE, 'graphics': graphics,
            'memory': _memory_text(memory), 'memoryBytes': memory, 'memorySource': memory_source,
            'version': version, 'osName': 'makOS', 'isPreview': not running_makos,
            'platform': host_platform, 'kernel': platform.release(),
            'architecture': platform.machine(), 'user': user}
