#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Paired A/B runner for the goose-task CSR sized-fill qualification.

Pair process invocations for descriptive comparison; independence is not guaranteed. Each pair runs the
two sides back to back on the same pinned CPU, with the starting side alternating
strictly (seeded offset) so neither side is systematically first. Raw stdout of
every run is preserved verbatim; nothing is overwritten.
"""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import platform
import random
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def loadavg():
    return pathlib.Path('/proc/loadavg').read_text().strip()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--a-bin', required=True)
    p.add_argument('--b-bin', required=True)
    p.add_argument('--a-label', required=True)
    p.add_argument('--b-label', required=True)
    p.add_argument('--pairs', type=int, default=20)
    p.add_argument('--iterations', type=int, default=40)
    p.add_argument('--warmup', type=int, default=5)
    p.add_argument('--seed', type=int, required=True)
    p.add_argument('--cpu', type=int, required=True)
    p.add_argument('--out', required=True, help='directory for raw logs + manifest')
    a = p.parse_args()

    assert a.pairs >= 9, 'at least 9 pairs'
    out = pathlib.Path(a.out)
    assert not out.exists(), f'refuse to overwrite prior evidence: {out}'
    (out / 'raw').mkdir(parents=True)

    rng = random.Random(a.seed)
    # Strict alternation with a seeded offset: perfectly balanced for even pair
    # counts, and neither side is systematically first.
    offset = rng.randrange(2)
    schedule = []
    for i in range(a.pairs):
        first_is_a = ((i + offset) % 2 == 0)
        schedule.append('AB' if first_is_a else 'BA')
    assert schedule.count('AB') == a.pairs // 2 or abs(schedule.count('AB') - schedule.count('BA')) <= 1

    env = dict(os.environ)
    env.pop('LD_LIBRARY_PATH', None)
    env['LC_ALL'] = 'C'

    manifest = dict(
        kind='paired-ab',
        started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        a=dict(label=a.a_label, binary=str(pathlib.Path(a.a_bin).resolve()), sha256=sha(a.a_bin)),
        b=dict(label=a.b_label, binary=str(pathlib.Path(a.b_bin).resolve()), sha256=sha(a.b_bin)),
        pairs=a.pairs, iterations=a.iterations, warmup=a.warmup, seed=a.seed,
        cpu=a.cpu, affinity=f'taskset -c {a.cpu}',
        schedule=schedule,
        platform=platform.platform(),
        host=platform.node(),
        loadavg_start=loadavg(),
        runs=[],
    )

    for index, order in enumerate(schedule):
        for side in order:
            label = a.a_label if side == 'A' else a.b_label
            binary = a.a_bin if side == 'A' else a.b_bin
            log = out / 'raw' / f'pair{index:02d}-{side}-{label}.log'
            assert not log.exists()
            before = loadavg()
            begin = time.monotonic()
            proc = subprocess.run(
                ['taskset', '-c', str(a.cpu), binary, label, str(a.iterations), str(a.warmup)],
                capture_output=True, text=True, env=env)
            wall = time.monotonic() - begin
            log.write_text(proc.stdout)
            (out / 'raw' / f'pair{index:02d}-{side}-{label}.stderr').write_text(proc.stderr)
            assert proc.returncode == 0, f'{log} failed rc={proc.returncode}: {proc.stderr[:400]}'
            assert 'DONE\t' in proc.stdout, f'{log} did not finish'
            manifest['runs'].append(dict(
                pair=index, side=side, label=label, order=order,
                log=str(log), wall_s=round(wall, 4),
                loadavg_before=before, loadavg_after=loadavg(),
                stdout_sha256=hashlib.sha256(proc.stdout.encode()).hexdigest(),
            ))
        print(f'pair {index + 1}/{a.pairs} done ({order})', flush=True)

    manifest['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    manifest['loadavg_end'] = loadavg()
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'manifest: {out / "manifest.json"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
