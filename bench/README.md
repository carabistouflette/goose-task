# Benchmarks

`make bench GOOSE=/path/to/exact/goose CC=gcc` builds at -O2 and records five
finite rounds in `.build/benchmark.json`, default ten iterations per workload.
The recorder refuses to replace prior evidence; use `BENCH_OUTPUT=.build/another-run.json` for another Make run (or
`--output` when calling the recorder directly).

Five workloads: 4,096 independent tasks; a reverse chain; a wide fanout;
256 roots sharing a descendant chain (overlapping failures); and 65,536
parallel duplicate edges over two tasks. Each measures graph planning,
successful task transitions, and failed task transitions separately.
Scheduler initialization is excluded from success/failure timing. Tasks execute
no external work. Every phase checks completion counts; the API/model suites
provide detailed behavior checks. Timing is not a correctness threshold.

Records include every raw sample, SHA-256 of source files/compiler/executable,
source commit and dirtiness, compiler revision, C compiler identity, build flags,
UTC timestamp and platform. The compiler must actually match GOOSE_REVISION.
Use a clean committed checkout, record CPU/host load for comparative work and
preserve slower samples. The harness is a local smoke baseline, not a comparison
with other libraries or Honk, and supplies no general speed claim. Profile before
changing hot paths; use the same exact workload/toolchain for comparisons.
