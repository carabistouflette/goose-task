#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Validate captured outputs and recompute descriptive paired medians."""
import hashlib
import json
from pathlib import Path
from statistics import median


def main():
    archive = json.loads(Path(__file__).with_name('replication-2026-11-09.json').read_text())
    template = Path(__file__).with_name('driver.goose.in')
    assert hashlib.sha256(template.read_bytes()).hexdigest() == archive['harness_sha256']
    for experiment in archive['experiments']:
        manifest = experiment['manifest']
        pairs = {}
        expected_keys = None
        for run in manifest['runs']:
            stdout = experiment['raw_stdout'][run['log']]
            assert hashlib.sha256(stdout.encode()).hexdigest() == run['stdout_sha256']
            samples, verify, totals, checksums, done = {}, [], [], [], []
            for line in stdout.splitlines():
                parts = line.split('\t')
                if parts[0] == 'SAMPLE':
                    _, label, fixture, phase, index, value = parts
                    assert label == run['label']
                    key = (fixture, phase)
                    values = samples.setdefault(key, {})
                    assert int(index) not in values and int(value) > 0
                    values[int(index)] = int(value)
                elif parts[0] == 'VERIFY':
                    verify.append(parts[1:])
                elif parts[0] == 'VERIFY_TOTAL':
                    totals.append(int(parts[2]))
                elif parts[0] == 'CHECKSUM':
                    checksums.append(int(parts[2]))
                elif parts[0] == 'DONE':
                    done.append(parts[1])
            assert len(samples) == 17
            if expected_keys is None:
                expected_keys = set(samples)
            assert set(samples) == expected_keys
            for values in samples.values():
                assert set(values) == set(range(manifest['iterations']))
            assert len(verify) == 34 and verify[:17] == verify[17:]
            assert len(totals) == 2 and totals[0] == totals[1]
            assert len(checksums) == 1 and done == [run['label']]
            sides = pairs.setdefault(run['pair'], {})
            assert run['side'] not in sides
            sides[run['side']] = (samples, verify, totals, checksums)
        assert set(pairs) == set(range(manifest['pairs']))
        for sides in pairs.values():
            assert set(sides) == {'A', 'B'}
            assert sides['A'][1:] == sides['B'][1:]
        name = experiment['name']
        summary = next(row['results'] for row in archive['summary'] if row['experiment'] == name)
        print(name, manifest['pairs'], 'complete pairs; checksums and verification agree')
        for key in sorted(expected_keys):
            deltas = []
            for _, sides in sorted(pairs.items()):
                a = median(sides['A'][0][key].values())
                b = median(sides['B'][0][key].values())
                deltas.append((b - a) / a * 100)
            recorded = summary['/'.join(key)]['median_pair_delta_percent']
            assert abs(median(deltas) - recorded) < 1e-12
            print(' ', '/'.join(key), f'{median(deltas):+.3f}%', '(descriptive)')


if __name__ == '__main__':
    main()
