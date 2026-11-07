# Design

The first proposed consumer is Honk's dependency-cycle check (currently repeated
node/edge scans). This library supplies indexed graph validation and dependency
scheduling independently of manifests or process execution. Integration is not
part of this initial library: Honk's ordering and edge orientation must be checked
before migration. A second example models build/test/package tasks.

Use compact integer task IDs and prerequisite-to-dependent edges. Compile to
compressed sparse row adjacency and use iterative FIFO Kahn traversal: O(V+E)
time and storage. Accept duplicate edges as parallel constraints, counting and
releasing each occurrence. No hashing, sorting, recursion, names or callbacks.
Initial zero-degree tasks enter in ascending ID order. Newly ready tasks enter in
input-edge order; this is deterministic, not globally lowest-ready ordering.

A noncopyable scheduler owns its graph and state. Caller-controlled dispatch and
completion permit bounded concurrency without owning threads or processes.
Initialization is one-shot: success forbids reinitialization, failure leaves the
uninitialized owner unchanged. Explicit Ready/Waiting/Done dispatch outcomes
separate temporary capacity/dependency waits from completion. Success releases
dependents; failure eagerly skips all descendants, each scanned only once.
Independent branches continue. No cancellation, retries, persistence or priority
policy in the initial interface. A completion reports only the caller's boolean
outcome; it cannot establish that an external process actually stopped.

Hard node/edge caps bound logical work and storage; callers can lower both.
Validate limits and every ID before indexed allocation. Empty graphs are valid.
Cycle errors return no partial plan; the reported unresolved task can be
 downstream of a cycle. Runtime allocation failure is not recoverable here.
Owner fields and implementation helpers are outside the supported interface.

Review checkpoints: independent design reviews, implementation review, then
final correctness/security/performance review after fixes and model testing.
