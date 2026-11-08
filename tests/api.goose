// SPDX-License-Identifier: Apache-2.0
import task from "..";
import std;
fn rejected(count: i64, edges: const task::Edge[:], limits: task::Limits&, expected: task::ErrorKind) {
    let order, error = task::plan(count, edges, limits);
    assert(order.len == 0 && error.kind == expected);
    var s = task::Scheduler { .. };
    assert(task::start(s, count, edges, 1, limits).kind == expected);
    assert(task::take(s).kind == task::DispatchKind.InvalidState);
    assert(task::summary(s).tasks == 0 && task::state(s, 0) == task::State.Unknown);
    var normal = task::Limits { .. };
    assert(task::start(s, 0, [], 1, normal).kind == task::ErrorKind.None);
    assert(task::take(s).kind == task::DispatchKind.Done);
}
fn validation() {
    var limits = task::Limits { .. };
    let bad_order, bad = task::plan(3, [task::Edge { 0, 1 }, task::Edge { -2, 5 }, task::Edge { 7, 0 }], limits);
    assert(bad_order.len == 0 && bad.kind == task::ErrorKind.InvalidTask && bad.edge == 1 && bad.task == -2);
    let bad_after_order, bad_after = task::plan(3, [task::Edge { 0, 1 }, task::Edge { 1, -7 }], limits);
    assert(bad_after_order.len == 0 && bad_after.edge == 1 && bad_after.task == -7);
    rejected(-1, [], limits, task::ErrorKind.TaskLimit);
    rejected(task::MAX_TASKS + 1, [], limits, task::ErrorKind.TaskLimit);
    rejected(2, [task::Edge { -1, 0 }], limits, task::ErrorKind.InvalidTask);
    rejected(2, [task::Edge { 0, 2 }], limits, task::ErrorKind.InvalidTask);
    rejected(2, [task::Edge { 2, 0 }], limits, task::ErrorKind.InvalidTask);
    rejected(2, [task::Edge { 0, -1 }], limits, task::ErrorKind.InvalidTask);
    rejected(0, [task::Edge { 0, 0 }], limits, task::ErrorKind.InvalidTask);
    rejected(1, [task::Edge { 0, 0 }], limits, task::ErrorKind.Cycle);
    // The first unresolved task is downstream of the cycle, not on it.
    let cycle = [task::Edge { 1, 2 }, task::Edge { 2, 1 }, task::Edge { 1, 0 }];
    let order, error = task::plan(3, cycle, limits);
    assert(order.len == 0 && error.kind == task::ErrorKind.Cycle && error.task == 0);
    var invalid = task::Limits { tasks: -1, .. }; rejected(0, [], invalid, task::ErrorKind.InvalidLimits);
    invalid.tasks = task::MAX_TASKS + 1; rejected(0, [], invalid, task::ErrorKind.InvalidLimits);
    invalid.tasks = 0; invalid.edges = -1; rejected(0, [], invalid, task::ErrorKind.InvalidLimits);
    invalid.edges = task::MAX_EDGES + 1; rejected(0, [], invalid, task::ErrorKind.InvalidLimits);
    var lower = task::Limits { tasks: 2, edges: 1 };
    rejected(3, [], lower, task::ErrorKind.TaskLimit);
    rejected(2, [task::Edge { 0, 1 }, task::Edge { 0, 1 }], lower, task::ErrorKind.EdgeLimit);
    let exact, ok = task::plan(2, [task::Edge { 0, 1 }], lower);
    assert(ok.kind == task::ErrorKind.None && exact == [0, 1]);
    var zero = task::Limits { tasks: 0, edges: 0 };
    let empty, empty_error = task::plan(0, [], zero);
    assert(empty.len == 0 && empty_error.kind == task::ErrorKind.None);
    var s = task::Scheduler { .. };
    assert(task::finish(s, 0, true).kind == task::ErrorKind.InvalidState);
    for cap in [0, -1, task::MAX_TASKS + 1] {
        assert(task::start(s, 0, [], cap, limits).kind == task::ErrorKind.InvalidParallelism);
        assert(task::take(s).kind == task::DispatchKind.InvalidState);
    }
    assert(task::start(s, 0, [], task::MAX_TASKS, limits).kind == task::ErrorKind.None);
    assert(task::take(s).kind == task::DispatchKind.Done);
    assert(task::start(s, 1, [], 1, limits).kind == task::ErrorKind.InvalidState);
    assert(task::take(s).kind == task::DispatchKind.Done);
}
fn failures_and_ownership() {
    var limits = task::Limits { .. };
    for reverse in 2 {
        var edges: task::Edge[>..] = [task::Edge { 0, 2 }, task::Edge { 1, 2 }, task::Edge { 2, 3 }, task::Edge { 0, 2 }, task::Edge { 1, 3 }];
        var s = task::Scheduler { .. };
        assert(task::start(s, 5, edges, 2, limits).kind == task::ErrorKind.None);
        // Prove graph ownership after caller storage changes.
        edges[0].after = 4; edges.clear();
        assert(task::state(s, -1) == task::State.Unknown && task::state(s, 5) == task::State.Unknown);
        assert(task::take(s).task == 0 && task::take(s).task == 1);
        assert(task::take(s).kind == task::DispatchKind.Waiting);
        assert(task::finish(s, -1, true).kind == task::ErrorKind.InvalidTask);
        assert(task::finish(s, 5, true).kind == task::ErrorKind.InvalidTask);
        assert(task::finish(s, 2, true).kind == task::ErrorKind.InvalidState);
        assert(task::start(s, 0, [], 1, limits).kind == task::ErrorKind.InvalidState);
        assert(task::summary(s).running == 2 && task::summary(s).tasks == 5);
        let first = reverse; let second = 1 - reverse;
        assert(task::finish(s, first, false).kind == task::ErrorKind.None);
        assert(task::summary(s).skipped == 2);
        assert(task::finish(s, first, true).kind == task::ErrorKind.InvalidState);
        assert(task::finish(s, 3, false).kind == task::ErrorKind.InvalidState);
        assert(task::finish(s, second, false).kind == task::ErrorKind.None);
        assert(task::summary(s).skipped == 2 && task::summary(s).failed == 2);
        assert(task::take(s).task == 4);
        assert(task::take(s).kind == task::DispatchKind.Waiting);
        assert(task::finish(s, 4, true).kind == task::ErrorKind.None);
        assert(task::take(s).kind == task::DispatchKind.Done);
    }
}
fn boundaries() {
    var limits = task::Limits { .. };
    var chain: task::Edge[>..] = [];
    for i in task::MAX_TASKS - 1 { chain.push(task::Edge { i + 1, i }); }
    let order, error = task::plan(task::MAX_TASKS, chain, limits);
    assert(error.kind == task::ErrorKind.None && order.len == task::MAX_TASKS);
    for id, i in order { assert(id == task::MAX_TASKS - 1 - i); }
    var s = task::Scheduler { .. };
    assert(task::start(s, task::MAX_TASKS, chain, 1, limits).kind == task::ErrorKind.None);
    assert(task::take(s).task == task::MAX_TASKS - 1);
    assert(task::finish(s, task::MAX_TASKS - 1, false).kind == task::ErrorKind.None);
    assert(task::summary(s).skipped == task::MAX_TASKS - 1);
    assert(task::take(s).kind == task::DispatchKind.Done);
    chain.clear();
    for i in task::MAX_EDGES { chain.push(task::Edge { 0, 1 }); }
    let duplicates, duplicate_error = task::plan(2, chain, limits);
    assert(duplicate_error.kind == task::ErrorKind.None && duplicates == [0, 1]);
    var d = task::Scheduler { .. };
    assert(task::start(d, 2, chain, 1, limits).kind == task::ErrorKind.None);
    assert(task::take(d).task == 0 && task::finish(d, 0, true).kind == task::ErrorKind.None);
    assert(task::take(d).task == 1 && task::finish(d, 1, true).kind == task::ErrorKind.None);
    assert(task::take(d).kind == task::DispatchKind.Done);
    chain.push(task::Edge { 0, 1 });
    rejected(2, chain, limits, task::ErrorKind.EdgeLimit);
}
fn wide_success() {
    var limits = task::Limits { .. };
    var s = task::Scheduler { .. };
    assert(task::start(s, task::MAX_TASKS, [], task::MAX_TASKS, limits).kind == task::ErrorKind.None);
    for i in task::MAX_TASKS { assert(task::take(s).task == i); }
    assert(task::summary(s).running == task::MAX_TASKS);
    assert(task::take(s).kind == task::DispatchKind.Waiting);
    for i in task::MAX_TASKS {
        assert(task::finish(s, task::MAX_TASKS - 1 - i, true).kind == task::ErrorKind.None);
        assert(task::summary(s).running == task::MAX_TASKS - 1 - i);
    }
    assert(task::take(s).kind == task::DispatchKind.Done);
    assert(task::summary(s).succeeded == task::MAX_TASKS);
}
// Endpoint validation runs over the whole edge array before the CSR arrays are
// built, so a bad endpoint is reported with its own index wherever it sits, and
// the first offender in input order wins.
fn endpoint_order() {
    var limits = task::Limits { .. };
    var late: task::Edge[>..] = [];
    for i in 4095 { late.push(task::Edge { i, i + 1 }); }
    late.push(task::Edge { 0, 4096 });
    let late_order, late_error = task::plan(4096, late, limits);
    assert(late_order.len == 0 && late_error.kind == task::ErrorKind.InvalidTask);
    assert(late_error.edge == 4095 && late_error.task == 4096);
    var early: task::Edge[>..] = [task::Edge { -1, 0 }];
    for i in 4095 { early.push(task::Edge { i, i + 1 }); }
    let early_order, early_error = task::plan(4096, early, limits);
    assert(early_order.len == 0 && early_error.kind == task::ErrorKind.InvalidTask);
    assert(early_error.edge == 0 && early_error.task == -1);
    // The earlier edge is reported even though a later one is also invalid.
    let first_order, first = task::plan(3, [task::Edge { 0, 1 }, task::Edge { 5, 0 }, task::Edge { 0, 9 }], limits);
    assert(first_order.len == 0 && first.kind == task::ErrorKind.InvalidTask && first.edge == 1 && first.task == 5);
    // Within one edge, `before` is reported before `after`.
    let both_order, both = task::plan(3, [task::Edge { 9, 8 }], limits);
    assert(both_order.len == 0 && both.kind == task::ErrorKind.InvalidTask && both.edge == 0 && both.task == 9);
    // A rejected start leaves the scheduler untouched and reusable.
    var s = task::Scheduler { .. };
    assert(task::start(s, 4096, late, 4, limits).kind == task::ErrorKind.InvalidTask);
    assert(task::take(s).kind == task::DispatchKind.InvalidState);
    assert(task::summary(s).tasks == 0 && task::state(s, 4095) == task::State.Unknown);
    assert(task::start(s, 4096, early, 4, limits).kind == task::ErrorKind.InvalidTask);
    assert(task::take(s).kind == task::DispatchKind.InvalidState);
    assert(task::start(s, 2, [task::Edge { 0, 1 }], 1, limits).kind == task::ErrorKind.None);
    assert(task::take(s).task == 0);
    assert(task::finish(s, 0, true).kind == task::ErrorKind.None);
    assert(task::take(s).task == 1);
    assert(task::finish(s, 1, true).kind == task::ErrorKind.None);
    assert(task::take(s).kind == task::DispatchKind.Done);
    // Duplicate edges stay a valid plan, and exact limits are accepted.
    var duplicates: task::Edge[>..] = [];
    for i in 65536 { duplicates.push(task::Edge { 0, 1 }); }
    let duplicate_order, duplicate_error = task::plan(2, duplicates, limits);
    assert(duplicate_error.kind == task::ErrorKind.None && duplicate_order == [0, 1]);
    var exact = task::Limits { tasks: 2, edges: 65536 };
    let exact_order, exact_error = task::plan(2, duplicates, exact);
    assert(exact_error.kind == task::ErrorKind.None && exact_order == [0, 1]);
}
fn main() {
    validation(); endpoint_order(); failures_and_ownership(); boundaries(); wide_success();
    var limits = task::Limits { .. };
    let edges = [task::Edge { 0, 2 }, task::Edge { 1, 2 }, task::Edge { 2, 3 }, task::Edge { 0, 2 }];
    let order, error = task::plan(5, edges, limits);
    assert(error.kind == task::ErrorKind.None && order == [0, 1, 4, 2, 3]);
    var scheduler = task::Scheduler { .. };
    assert(task::start(scheduler, 5, edges, 2, limits).kind == task::ErrorKind.None);
    assert(task::take(scheduler).task == 0); assert(task::take(scheduler).task == 1);
    assert(task::take(scheduler).kind == task::DispatchKind.Waiting);
    assert(task::finish(scheduler, 0, false).kind == task::ErrorKind.None);
    assert(task::state(scheduler, 2) == task::State.Skipped && task::state(scheduler, 3) == task::State.Skipped);
    assert(task::take(scheduler).task == 4);
    assert(task::finish(scheduler, 1, true).kind == task::ErrorKind.None);
    assert(task::finish(scheduler, 4, true).kind == task::ErrorKind.None);
    assert(task::take(scheduler).kind == task::DispatchKind.Done);
    let result = task::summary(scheduler);
    assert(result.succeeded == 2 && result.failed == 1 && result.skipped == 2 && result.running == 0);
    print("api passed");
}
