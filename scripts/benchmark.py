#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Record raw finite benchmark samples and exact provenance; no speed claims."""
import argparse
import datetime
import hashlib
import json
import pathlib
import platform
import subprocess
import shutil


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--goose', required=True)
    p.add_argument('--cc', required=True)
    p.add_argument('--iterations', type=int, default=10)
    p.add_argument('--rounds', type=int, default=5)
    p.add_argument('--output', default='.build/benchmark.json')
    a = p.parse_args()
    assert 1 <= a.iterations <= 10000 and 1 <= a.rounds <= 20
    root = pathlib.Path(__file__).resolve().parents[1]
    assert pathlib.Path.cwd() == root, 'run from library root'
    target = pathlib.Path(a.output)
    assert not target.exists(), 'preserve previous samples; choose a new output path'
    paths = [x for x in sorted(root.rglob('*')) if x.is_file()
             and not any(v in ('.git', '.build', '.toolchain', '__pycache__') for v in x.relative_to(root).parts)]
    report = dict(timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  source_head=run('git', 'rev-parse', 'HEAD'),
                  source_status=run('git', 'status', '--porcelain'),
                  sources={str(x.relative_to(root)): sha(x) for x in paths},
                  compiler_revision=(root / 'GOOSE_REVISION').read_text().strip(),
                  compiler_sha256=sha(a.goose), executable_sha256=sha('.build/bench'),
                  cc=run(a.cc, '--version'), cc_sha256=sha(shutil.which(a.cc)),
                  platform=platform.platform(),
                  build_flags=['-O2'], iterations=a.iterations,
                  notes='Local shared-host smoke. No competitor or speedup claim. Initialization excluded from success/failure phases.',
                  samples=[])
    for _ in range(a.rounds):
        raw = run(str(root / '.build/bench'), str(a.iterations))
        rows = [line.split('\t') for line in raw.splitlines()]
        assert len(rows) == 15
        for name, phase, elapsed, iterations in rows:
            assert int(elapsed) >= 0 and int(iterations) == a.iterations
        report['samples'].append(raw)
    assert report['sources'] == {str(x.relative_to(root)): sha(x) for x in paths}, 'sources changed during sampling'
    assert report['compiler_sha256'] == sha(a.goose), 'compiler changed during sampling'
    assert report['executable_sha256'] == sha('.build/bench'), 'executable changed during sampling'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + '\n')
    print(f'benchmark evidence: {target}')


if __name__ == '__main__':
    main()
