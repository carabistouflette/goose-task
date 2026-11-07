# Testing

Use the exact compiler revision in GOOSE_REVISION. `make check test test-debug
property` checks formatting and all programs, runs JIT/optimized/debug API tests,
and compares optimized/debug oracles against an independent Python model.

The model exhausts all directed graphs through three nodes (including loops),
all loop-free four-node directed graphs, and 1,500 fixed-seed random graphs,
including duplicates. It compares full FIFO plans, dispatched tasks, invalid
completion errors, every task state and summary counters after each operation.
Its order calculation uses repeated edge scans; failure uses fixed-point
reachability, independently of the library's CSR/indegree and queue algorithms.
Protocol integers are explicit test mappings, not enum ABI assumptions.

API regressions cover hard task/edge caps, cap-plus-one rejection, lower and
zero limits, endpoint validation, empty/cyclic graphs, deep reverse chains,
duplicate-heavy graphs, overlapping failing ancestors in both completion
orders, one-shot initialization, unchanged state after rejection, concurrency
limits and input ownership after mutation.

Run with both `CC=gcc` and `CC=clang`. `make sanitize SANITIZER_CC=gcc` and
`SANITIZER_CC=clang` instrument standalone generated program and runtime C,
with ASan/UBSan, debug bounds checking, leak detection and a separate optimized
API pass. The model runner has a 90-second subprocess timeout and fixed input
count. Test oracle input is trusted, test-only and not a public parser.

CI uses pinned actions, read-only permissions and GCC/Clang on Ubuntu 24.04.
CI proves execution/correctness, never speed. Hosted CI and other architectures
remain unverified until actual runs exist. No portable/native dual backend is
needed because this library contains only Goose code.
