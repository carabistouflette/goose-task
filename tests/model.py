#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Independent scan-based graph and scheduler model, fixed-seed and exhaustive."""
import itertools
import random
import subprocess
import sys


def order_for(n, edges):
    # Independent repeated scans, deliberately no CSR or indegree array.
    done, queue = set(), [i for i in range(n) if not any(b == i for a, b in edges)]
    queued = set(queue)
    for node in queue:
        done.add(node)
        for index, (a, b) in enumerate(edges):
            if (a, b) in edges[index + 1:]:
                continue
            if a == node and b not in queued and all(x in done for x, y in edges if y == b):
                queue.append(b)
                queued.add(b)
    return queue if len(done) == n else None


def simulate(n, edges, cap, rng):
    states = [2 if not any(b == i for a, b in edges) else 1 for i in range(n)]
    queue = [i for i in range(n) if states[i] == 2]
    ops, trace = [], []
    for step in range(8 * n + 12):
        running = [i for i, s in enumerate(states) if s == 3]
        if running and rng.randrange(3):
            node = rng.choice(running)
            success = rng.randrange(4) != 0
            ops += [node, int(success)]
            states[node] = 4 if success else 5
            if success:
                for index, (a, b) in enumerate(edges):
                    if (a, b) in edges[index + 1:]:
                        continue
                    if a == node and states[b] == 1 and all(states[x] == 4 for x, y in edges if y == b):
                        states[b] = 2
                        queue.append(b)
            else:
                # Fixed-point reachability independent of library queue traversal.
                reached = {node}
                while True:
                    new = reached | {b for a, b in edges if a in reached}
                    if new == reached:
                        break
                    reached = new
                for child in reached - {node}:
                    assert states[child] in (1, 2, 6)
                    states[child] = 6
            trace.append('F0')
        elif step % 7 == 3:
            node = rng.choice([n, n + 1]) if rng.randrange(2) else rng.randrange(n) if n else 0
            ops += [node, 1]
            if 0 <= node < n and states[node] == 3:
                # Choose an invalid completion instead, so state stays unchanged.
                ops[-2] = n
                node = n
            trace.append('F4' if node >= n else 'F6')
        else:
            ops += [-1, 0]
            terminal = all(s in (4, 5, 6) for s in states)
            if terminal:
                trace.append('T2:-1')
            elif len(running) >= cap:
                trace.append('T1:-1')
            else:
                queue = [i for i in queue if states[i] == 2]
                if queue:
                    node = queue.pop(0)
                    states[node] = 3
                    trace.append(f'T0:{node}')
                else:
                    assert running
                    trace.append('T1:-1')
        trace += ['S' + ''.join(f'{s},' for s in states),
                  'C' + ','.join(str(states.count(s)) for s in (3, 4, 5, 6))]
        if all(s in (4, 5, 6) for s in states) and step > 2:
            # One final take verifies Done after the last completion.
            ops += [-1, 0]
            trace += ['T2:-1', 'S' + ''.join(f'{s},' for s in states),
                      'C' + ','.join(str(states.count(s)) for s in (3, 4, 5, 6))]
            break
    else:
        raise AssertionError('model did not complete')
    return ops, trace


def main():
    rng = random.Random(20261107)
    inputs, expected = [], []
    graphs = []
    # Exhaust all directed graphs through 3 nodes, including self loops.
    for n in range(4):
        possible = list(itertools.product(range(n), repeat=2))
        for mask in range(1 << len(possible)):
            graphs.append((n, [e for i, e in enumerate(possible) if mask >> i & 1]))
    # Exhaust all 4-node loop-free graphs; random suite also covers 4-node self loops.
    possible = [(a, b) for a in range(4) for b in range(4) if a != b]
    graphs += [(4, [e for i, e in enumerate(possible) if mask >> i & 1]) for mask in range(1 << 12)]
    for _ in range(1500):
        n = rng.randrange(1, 20)
        edges = [(rng.randrange(n), rng.randrange(n)) for _ in range(rng.randrange(60))]
        if rng.randrange(2):
            edges = [(min(a, b), max(a, b)) for a, b in edges if a != b]
        rng.shuffle(edges)
        graphs.append((n, edges))
    for n, edges in graphs:
        order = order_for(n, edges)
        cap = rng.randrange(1, max(n, 1) + 3)
        ops, trace = ([], []) if order is None else simulate(n, edges, cap, rng)
        values = [n, cap, len(edges)] + [v for edge in edges for v in edge] + [len(ops) // 2] + ops
        inputs.append(' '.join(map(str, values)))
        expected.append('E 5' if order is None else ' '.join(['P'] + list(map(str, order)) + trace))
    result = subprocess.run([sys.argv[1]], input='\n'.join(inputs) + '\n', text=True,
                            capture_output=True, timeout=90, check=True)
    actual = result.stdout.splitlines()
    assert len(actual) == len(expected), (len(actual), len(expected), result.stderr)
    for i, (got, want) in enumerate(zip(actual, expected)):
        assert got == want, (i, inputs[i], got, want)
    print(f'model passed: {len(inputs)} graphs; exhaustive small graphs and random completion traces')


if __name__ == '__main__':
    main()
