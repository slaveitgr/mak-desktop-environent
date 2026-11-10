#!/usr/bin/env python3
"""Fetch the pinned Deepin base; publish an ISO only after SHA-256 verification."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import time
import urllib.request


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def fetch(base, destination, workers):
    destination.mkdir(parents=True, exist_ok=True)
    final = destination / base['filename']
    if final.exists():
        if final.stat().st_size == base['bytes'] and sha256(final) == base['sha256']:
            print('Verified: ' + str(final.resolve()), flush=True)
            return final
        raise RuntimeError('Existing ISO does not match the pinned base; it was preserved.')
    chunks = destination / (base['filename'] + '.chunks')
    chunks.mkdir(exist_ok=True)
    # Fixed boundaries make partial downloads resumable even if workers changes.
    chunk_size = 128 * 1024 * 1024
    ranges = [(i, start, min(start + chunk_size, base['bytes']) - 1)
              for i, start in enumerate(range(0, base['bytes'], chunk_size))]
    sources = base.get('mirrors', []) + [base['url']]

    def transfer(entry):
        index, start, end = entry
        target = chunks / f'{index:04d}'
        expected = end - start + 1
        for attempt in range(4):
            have = target.stat().st_size if target.exists() else 0
            if have == expected:
                return target
            if have > expected:
                raise RuntimeError('Invalid partial chunk: ' + str(target))
            request = urllib.request.Request(sources[(index + attempt) % len(sources)],
                                            headers={'Range': f'bytes={start + have}-{end}'})
            try:
                with urllib.request.urlopen(request, timeout=40) as response:
                    if response.status != 206 or response.headers.get('Content-Range') != f'bytes {start + have}-{end}/{base["bytes"]}':
                        raise RuntimeError('Mirror did not return the requested byte range.')
                    with target.open('ab') as output:
                        remaining = expected - have
                        while remaining:
                            block = response.read(min(1024 * 1024, remaining))
                            if not block:
                                raise OSError('Incomplete mirror response')
                            output.write(block)
                            remaining -= len(block)
                return target
            except (OSError, RuntimeError):
                if attempt == 3:
                    raise
                time.sleep(1 + attempt)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(transfer, entry) for entry in ranges}
        while futures:
            done, futures = concurrent.futures.wait(futures, timeout=30,
                                                  return_when=concurrent.futures.FIRST_EXCEPTION)
            for future in done:
                future.result()
            received = sum(p.stat().st_size for p in chunks.iterdir() if p.is_file())
            print(f'Downloaded {received / 1024**3:.2f} / {base["bytes"] / 1024**3:.2f} GiB', flush=True)
    assembled = destination / (base['filename'] + '.assembling')
    digest = hashlib.sha256()
    with assembled.open('wb') as output:
        for index, start, end in ranges:
            with (chunks / f'{index:04d}').open('rb') as source:
                for block in iter(lambda: source.read(4 * 1024 * 1024), b''):
                    digest.update(block)
                    output.write(block)
    if digest.hexdigest() != base['sha256'] or assembled.stat().st_size != base['bytes']:
        raise RuntimeError('Base ISO checksum mismatch; no ISO was published. Remove the partial chunks before retrying.')
    assembled.rename(final)
    for part in chunks.iterdir():
        part.unlink()
    chunks.rmdir()
    (destination / (base['filename'] + '.sha256')).write_text(base['sha256'] + '  ' + final.name + '\n')
    print('Verified: ' + str(final.resolve()), flush=True)
    return final


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path.home() / 'Downloads/makOS')
    parser.add_argument('--workers', type=int, choices=range(1, 9), default=4)
    parser.add_argument('--manifest', type=Path, default=Path(__file__).with_name('base.json'))
    args = parser.parse_args()
    base = json.loads(args.manifest.read_text())['base']
    fetch(base, args.output, args.workers)
