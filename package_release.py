#!/usr/bin/env python3
"""Package source/reference assets; never include workspace records or local runtimes."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent
VERSION = '0.7'
DIRECTORIES = {'qml', 'assets', 'shaders', 'tests', 'reference', 'linux', '.github'}
FILES = {'README.md', 'RENDERING.md', 'run.sh', 'Launch.command', 'requirements.txt',
         'settings_catalog.json', '.gitignore', 'extract_reference_icons.swift', 'extract_settings_assets.swift'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT.parent / f'tahoe-desktop-prototype-{VERSION}.zip')
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('Output already exists. Choose a new --output path to preserve that release.')
    sources = []
    for source in sorted(ROOT.rglob('*')):
        relative = source.relative_to(ROOT)
        if source.is_symlink() or not source.is_file() or '__pycache__' in relative.parts or source.suffix == '.pyc' or source.name == '.DS_Store':
            continue
        if relative.parts[0] in DIRECTORIES or (len(relative.parts) == 1 and (source.name in FILES or source.suffix == '.py')):
            sources.append((source, relative))
    manifest = {'version': VERSION, 'format': 'source-and-reference-assets',
                'excluded': ['user workspace', 'application database', 'camera originals', 'browser downloads', 'Python/Node environments', 'local macOS launcher'],
                'files': {str(relative): hashlib.sha256(source.read_bytes()).hexdigest() for source, relative in sources}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source, relative in sources:
            archive.write(source, 'tahoe-desktop/' + str(relative))
        archive.writestr('tahoe-desktop/release-manifest.json', json.dumps(manifest, indent=2) + '\n')
    with zipfile.ZipFile(args.output) as archive:
        damaged = archive.testzip()
        if damaged:
            raise SystemExit('Archive verification failed: ' + damaged)
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(json.dumps({'path': str(args.output.resolve()), 'files': len(sources) + 1, 'bytes': args.output.stat().st_size, 'sha256': digest}, indent=2))


if __name__ == '__main__':
    main()
