# Sized CSR replication

These are descriptive microbenchmarks on one shared Linux x86-64 host, an Intel
Core Ultra 7 258V, CPU 1, with the `powersave` governor and uncontrolled frequency.
They do not establish a general speedup, allocation counts or a competitive ranking.

Baseline: `40fc59e4fd99224819aa85259a42ca6a6e44def6`.
Candidate: `c58fb3e0e3cd53978cbc376591c32fc11ce30447`.
The later source comment clarification does not change the algorithm. These
measurements name the exact earlier sources, rather than the moving PR head.

The [capture](replication-2026-11-09.json) retains all 160 process outputs from
four coordinator replication runs, binary/source/harness/compiler hashes, seeds,
order, timestamps and descriptive summaries. Compiler source pin:
`eadca409f68210893f366e60d0c2f0dc29a339be`; executable SHA-256:
`5bcc8d63043837ecab55742fab8524de8754cd6b9bbb6cbf4f54e68f74fc2147`.
The GCC and Clang versions and executable hashes are in the capture. Binaries
are not included; metadata hashes alone are not build attestation.

## Coordinator replication

Entries are median paired percentage differences of process medians. Negative
means less time for the candidate. Each run has 20 alternating AB/BA process
pairs, 40 measured calls per phase and five excluded warmup calls. A/A compares
the baseline with itself under different labels.

| Compiler / fixture / phase | A/B median difference | A/A median difference |
| --- | ---: | ---: |
| GCC 16.2.1 / chain / plan | -5.464% | +0.254% |
| GCC 16.2.1 / chain / start | -4.873% | -0.061% |
| Clang 23.1.4 / dups / plan | +1.859% | +0.033% |
| Clang 23.1.4 / dups / start | +1.338% | -0.023% |

The exact absolute medians are retained in the capture; paired percentages and
ratios of marginal medians are different estimators. Other fixtures,
including slower samples, are retained there. `dense` varies substantially by
process, so no single stable speedup is claimed. `invalid_first` takes tens of
nanoseconds and shows small positive deltas: do not replace these observations
with “no regression” or dismiss them solely because the clock reports nanoseconds.

The GCC gain on the large chain and the Clang duplicate-edge regression also
appeared in the preceding exploratory agent runs. Their independent coordinator
replication is recorded here; the exploratory runs are not pooled with it.
This supports a compiler/workload-specific tradeoff, not unconditional acceptance.

## Method and limits

The same [driver template](driver.goose.in) is instantiated with different import
paths. Inputs are built outside timing. Only a `plan`, `start` or rejected `plan`
call is timed; output destruction, validation, checksums and printing are outside.
Each process verifies results before and after timing. Validation includes
topological order, deterministic FIFO behavior, scheduler completion and exact
error classifications. Cross-side verification and checksums must agree.

The ten fixtures include empty/tiny graphs, a 65,536-task chain, a wide star,
seeded sparse and dense DAGs, 65,536 duplicate edges, invalid first/last endpoints
and a cycle. The cycle fixture also contains one isolated runnable node: it tests
rejection after partial traversal, not a graph with no zero-indegree nodes.
The fixture set does not exhaust all graph shapes or error cases.

The pair is the analysis unit; iterations within a process are not independent
replicates. Alternation does not establish independence or eliminate frequency,
layout, serial or parity effects. Bootstrap and sign-test fields in the capture
are exploratory; selection across fixtures, compilers, runs and estimators limits
their interpretation. Lack of significance is not proof of equivalence, and an
observed maximum is not an upper bound on future regressions.

Both rebuilt optimized baselines already contain three `memset` call sites in
`detail_compile`, under GCC and Clang. Thus this source rewrite does not introduce
an optimization missing from every baseline. Initialization order and emitted
code differ, but the causal explanation of the measured tradeoff is unresolved.
There is no instrumentation proving allocation or instruction-count savings.

## Recheck and reproduce

Recheck the archived raw output without building or running benchmarks:

```sh
python3 bench/sized-csr/verify_archive.py
```

For a new run, from the repository root, use a matching compiler and a new output
directory. Set `BENCH_CPU` to a CPU allowed by your affinity; this capture used 1.
Preserve actual commands, toolchain identities and all outputs. A matching source
pin alone does not identify the compiler executable used here.

```sh
export GOOSE=/absolute/path/to/matching/goose
export BENCH_CPU=1
mkdir -p .build/sized-csr/src/base .build/sized-csr/src/cand .build/sized-csr/bin
git show 40fc59e4fd99224819aa85259a42ca6a6e44def6:task.goose > .build/sized-csr/src/base/task.goose
git show c58fb3e0e3cd53978cbc376591c32fc11ce30447:task.goose > .build/sized-csr/src/cand/task.goose
python3 - <<'PY'
from pathlib import Path
template = Path('bench/sized-csr/driver.goose.in').read_text()
for side in ('base', 'cand'):
    Path(f'.build/sized-csr/src/driver_{side}.goose').write_text(template.replace('TASKPATH', './' + side))
PY
env -u LD_LIBRARY_PATH "$GOOSE" build .build/sized-csr/src/driver_base.goose --cc gcc -O2 -o .build/sized-csr/bin/base
env -u LD_LIBRARY_PATH "$GOOSE" build .build/sized-csr/src/driver_cand.goose --cc gcc -O2 -o .build/sized-csr/bin/cand
python3 bench/sized-csr/run_pairs.py --a-bin .build/sized-csr/bin/base --b-bin .build/sized-csr/bin/cand \
  --a-label base --b-label cand --pairs 20 --iterations 40 --warmup 5 \
  --seed 8675309 --cpu "$BENCH_CPU" --out .build/sized-csr/gcc-ab
```

Repeat with `--b-bin` pointing to the baseline for A/A, and with both binaries
rebuilt using `--cc clang` for Clang. Use distinct output directories; the runner
refuses to overwrite earlier evidence. CI must not use timing thresholds.
