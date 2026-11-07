# Qualified consumers

These consumers use the unchanged alpha.1 source at
`166b684ca96403fea94072cc8e0c630321fb832d`. This documents integration evidence;
it does not expand the task API or promote the experimental library to stable.

## Honk

[Honk's qualified source](https://github.com/carabistouflette/honk/tree/0d8093487547462556bf41f86e7e7c794ca6f86d)
uses `task::plan` to validate dependency graphs. It preserves Honk's parent/child
edge orientation; validation does not reorder dependency traversal.

Its opt-in `test --jobs 1..8` path uses `start`, `take` and `finish` for independent
test targets. Honk compiles targets sequentially, owns process supervision and
runs bounded cohorts. The task library does not spawn or supervise processes.
See Honk's [parallel-test contracts](https://github.com/carabistouflette/honk/blob/0d8093487547462556bf41f86e7e7c794ca6f86d/docs/parallel-tests.md)
for failure, cancellation and supervision limits. Default test execution remains
sequential. This integration does not establish a general speedup claim.

## goose-msgpack plan example

[The qualified example](https://github.com/carabistouflette/goose-msgpack/tree/58f15ab4a5c83d82ddac4372565b8c8e3b9e5775)
decodes a bounded MessagePack manifest, passes it to the pinned task scheduler,
then reports task outcomes from a caller-owned loop. This is an example workflow,
not a production executor. It starts no workers or processes.

The example owns strict schema checks and limits of 64 tasks and 256 edges;
`task::start` owns endpoint and cycle validation. Direct tests cover malformed
input, exact bounds, duplicate edges, deterministic dispatch, failed prerequisites,
independent work, rejected reinitialization and caller cancellation. Cancellation stops
admission and finishes admitted work; queued tasks can remain nonterminal.

The [retained qualification evidence](https://github.com/carabistouflette/goose-msgpack/tree/58f15ab4a5c83d82ddac4372565b8c8e3b9e5775/docs/task-consumer-evidence)
compares the same 512 generated wire cases with an independent Python model in
release, debug, GCC ASan/UBSan and Clang ASan/UBSan configurations. Comparisons
cover admission/completion ID sequences and final task states and counters.
Each codec regression run covers 102,723 cases; these repeated runs are not
distinct corpora. Source/tool hashes and an offline evidence verifier accompany
the reports. A retained counterexample explains an independent-model correction
to duplicate-edge release ordering; no task-library change was required.

The codec source and task source remain unchanged by this integration. No
performance measurement or production deployment is claimed for this example.
