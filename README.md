# goose-task

Experimental dependency planning and task scheduling for Goose, Apache-2.0.
Pure Goose; no native adapter, process spawning, threads, network or filesystem I/O.

- Bounded indexed DAG validation and deterministic FIFO topological plans.
- Single-owner scheduling with a caller-selected concurrency cap.
- Success/failure tracking and eager transitive skipping; independent work continues.
- Iterative O(V+E) graph compilation and total task-transition work.

## Quickstart

Requirements: Git, CMake 3.27+, a C/C++20 toolchain and Python 3 for model tests.
From a standalone checkout:

```sh
git clone https://github.com/carabistouflette/goose-task.git
cd goose-task
make setup
make check test test-debug property
make sanitize SANITIZER_CC=gcc
make sanitize SANITIZER_CC=clang
make bench
```

`make setup` fetches the full compiler commit in `GOOSE_REVISION`, also used for the initial independent validation. To reuse that exact compiler, pass
`GOOSE=/absolute/path/to/goose` to Make. This library has no third-party package
dependencies. Direct source import example:

```goose
import task from "./path/to/goose-task";
import std;

fn main() {
    var limits = task::Limits { .. };
    // Task 0 must succeed before task 1 can run.
    let edges = [task::Edge { before: 0, after: 1 }];
    var scheduler = task::Scheduler { .. };
    let error = task::start(scheduler, 2, edges, 1, limits);
    assert(error.kind == task::ErrorKind.None);
    let first = task::take(scheduler);
    assert(first.kind == task::DispatchKind.Ready && first.task == 0);
    // The caller runs its task, then reports the observed outcome.
    assert(task::finish(scheduler, first.task, true).kind == task::ErrorKind.None);
}
```

[Complete build example](examples/build.goose) and [dependency validation](examples/dependencies.goose)
are checked by Make. Honk's dependency-cycle check is the proposed first consumer;
Honk has not been migrated. Graph orientation and execution order require separate
consumer validation.

## Contracts and limits

Task IDs are integers `0..count-1`. `Edge.before` is the prerequisite;
`Edge.after` is the dependent. Duplicate edges are accepted and count toward the
edge limit. Every prerequisite must succeed before a dependent becomes ready.
Self-loops and longer cycles are rejected, with no partial plan returned.

Hard maxima are 65,536 tasks and 1,048,576 edges. `Limits` can lower either bound,
including to zero. Empty graphs are valid. Limits bound logical storage and work,
not exact allocator bytes or wall time. Allocation failure follows the runtime's
behavior, with no recovery guarantee.

Initial ready tasks enter the FIFO in ascending ID order. Newly ready tasks enter
when their final incoming edge occurrence is released, following input-edge
order for the completed prerequisite. This is deterministic for a fixed graph
and completion sequence; it does not always choose the smallest ready ID.

The scheduler is a noncopyable `root struct`. Call it serially from one owner;
workers report outcomes back to that owner. Concurrency limits dispatched tasks,
not OS threads or processes. `Waiting` means capacity is full or prerequisites
are still running. `Done` means all tasks are terminal, including skipped tasks;
it does not mean all succeeded. There is no blocking wait inside the library.

See [supported interface](docs/api.md), [testing](docs/testing.md),
[benchmarks](bench/README.md), [contributing](CONTRIBUTING.md) and
[security policy](SECURITY.md).
