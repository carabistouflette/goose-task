# Supported interface

`namespace task` exports the following supported types and functions.
Everything else, including `Graph`, `detail_*` and scheduler fields, is an
implementation detail. Never construct or mutate scheduler internals.

## Graph inputs and errors

- `MAX_TASKS = 65536`, `MAX_EDGES = 1048576`.
- `Limits { tasks: i64 = MAX_TASKS, edges: i64 = MAX_EDGES }`.
- `Edge { before: i64, after: i64 }`: prerequisite to dependent.
- `Error { kind: ErrorKind = None, edge: i64 = -1, task: i64 = -1 }`.
- `ErrorKind`: `None`, `InvalidLimits`, `TaskLimit`, `EdgeLimit`, `InvalidTask`,
  `Cycle`, `InvalidState`, `InvalidParallelism`.

`plan(count: i64, edges: const Edge[:], limits: Limits&) -> i64[], Error`
validates and returns an owned topological order. Errors return an empty order.
Validation precedence: invalid limits, invalid task count, oversized edge slice,
then endpoints in input order (`before` checked before `after`), then cycles.
For invalid endpoints `edge` identifies the first offending edge and `task` the
invalid endpoint. For cycles `task` is the first unresolved ID, which may be
downstream of a cycle; it is not a cycle witness. Other error details are -1.

Negative counts return TaskLimit. Negative limits or limits above hard maxima
return InvalidLimits. Duplicates retain multiplicity and ordering. FIFO ordering
is described in the README. Both compile and plan use O(V+E) time and storage.
No input slices are retained.

## Scheduler lifecycle

Construct `var s = task::Scheduler { .. };`, then:

`start(s: Scheduler&, count: i64, edges: const Edge[:], parallelism: i64, limits: Limits&) -> Error`
initializes once, owning a graph snapshot. Later input mutation is safe.
`parallelism` must be 1..MAX_TASKS, and may exceed count even for empty graphs.
Validation precedence is already initialized, invalid parallelism, then graph
validation. Rejected initialization leaves the owner unchanged, so failed initial
attempts can be retried. Successful initialization is one-shot, even after Done;
construct a fresh owner for another run. No task IDs survive into another owner.

`take(s: Scheduler&) -> Dispatch` returns `{ kind, task = -1 }`:

- `Ready`: returns a task ID and changes Ready to Running.
- `Waiting`: concurrency cap reached, or prerequisites await running tasks.
- `Done`: every task is Succeeded, Failed or Skipped (empty graphs immediately).
- `InvalidState`: not initialized.

Non-Ready results always have task=-1. Repeated Waiting/Done calls are harmless.
This does no external work and does not wait, sleep or poll.

`finish(s: Scheduler&, id: i64, success: bool) -> Error` accepts only a Running
ID. It changes Running to Succeeded or Failed and frees capacity. Success makes
newly unblocked tasks Ready. Failure eagerly marks every descendant Skipped;
independent branches continue and each descendant is processed at most once.
A failure cannot skip a running descendant: dependencies require success before
dispatch. Invalid/default-owner completion returns InvalidState; invalid IDs
return InvalidTask; nonrunning IDs return InvalidState. Rejections change no
state or counters. These errors set task=id except default-owner errors (-1).

The library trusts the caller's completion report. It does not kill, reap or
verify external work. Deadlines, cancellation, retries and process execution
belong to the caller. A Running task remains Running until finish is called.

## Observation and cost

`state(s: Scheduler&, id: i64) -> State` returns `Unknown` for uninitialized
owners or invalid IDs, otherwise `Pending`, `Ready`, `Running`, `Succeeded`,
`Failed` or `Skipped`.

`summary(s: Scheduler&) -> Summary` returns an independent value with `tasks`,
`running`, `succeeded`, `failed`, `skipped`. Default-owner counters are zero;
there is no implied initialization flag. Nonterminal count is tasks minus the
three terminal counts. Check failed/skipped as well as Done.

Initialization is O(V+E) time/storage. Observation and invalid operations are
O(1). All successful task transitions over a complete run are O(V+E), plus O(1)
per take call, including repeated Waiting/Done polling. Failure and success can
scan individual adjacency lists; this is not a hard per-call latency guarantee.
Arrays grow geometrically, so these storage costs include amortized allocation.
The library is reentrant across distinct owners, but a single owner is not
safe for concurrent calls. Helpers and fields are private by contract because
the pinned language does not enforce this interface's field visibility.
