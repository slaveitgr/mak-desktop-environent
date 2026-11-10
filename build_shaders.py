#!/usr/bin/env python3
"""Rebuild portable Qt shaders using the qsb shipped by the pinned PySide6."""
from pathlib import Path
import subprocess
import PySide6
root = Path(__file__).resolve().parent
qsb = Path(PySide6.__file__).parent / 'qsb'
for source in sorted((root / 'shaders').iterdir()):
    if source.suffix in ('.vert', '.frag'):
        subprocess.run([str(qsb), '--qt6', '-o', str(source) + '.qsb', str(source)], check=True)
        print(source.name)
