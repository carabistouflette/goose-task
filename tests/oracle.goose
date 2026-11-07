// SPDX-License-Identifier: Apache-2.0
// Test-only bounded integer protocol: n cap edge_count endpoints... op_count (id outcome)...
import task from "..";
import std;
import os;
fn error_code(e: task::ErrorKind) -> i64 {
    if e == task::ErrorKind.None { return 0; }
    if e == task::ErrorKind.InvalidTask { return 4; }
    if e == task::ErrorKind.Cycle { return 5; }
    if e == task::ErrorKind.InvalidState { return 6; }
    assert(false); return -1;
}
fn dispatch_code(d: task::DispatchKind) -> i64 {
    if d == task::DispatchKind.Ready { return 0; }
    if d == task::DispatchKind.Waiting { return 1; }
    if d == task::DispatchKind.Done { return 2; }
    assert(false); return -1;
}
fn state_code(s: task::State) -> i64 {
    if s == task::State.Pending { return 1; }
    if s == task::State.Ready { return 2; }
    if s == task::State.Running { return 3; }
    if s == task::State.Succeeded { return 4; }
    if s == task::State.Failed { return 5; }
    if s == task::State.Skipped { return 6; }
    assert(false); return -1;
}
fn main() {
    while true {
        var line: u8[>..] = [];
        if !read_line(line) { break; }
        assert(line.len <= 100000);
        let parts = split(line, " ");
        var numbers: i64[>..] = [];
        for part in parts { let value, ok = parse_int(part); assert(ok); numbers.push(value); }
        assert(numbers.len >= 4);
        let n = numbers[0]; let cap = numbers[1]; let count = numbers[2];
        assert(count >= 0 && count <= 4096 && numbers.len >= 4 + count * 2);
        var edges: task::Edge[>..] = [];
        for i in count { edges.push(task::Edge { numbers[3 + i * 2], numbers[4 + i * 2] }); }
        let ops = numbers[3 + count * 2];
        assert(ops >= 0 && numbers.len == 4 + count * 2 + ops * 2);
        var limits = task::Limits { .. };
        let order, error = task::plan(n, edges, limits);
        if error.kind != task::ErrorKind.None { assert(order.len == 0); print("E ", error_code(error.kind)); continue; }
        var output = str("P");
        for id in order { output.append(str(" ", id)); }
        var s = task::Scheduler { .. };
        assert(task::start(s, n, edges, cap, limits).kind == task::ErrorKind.None);
        for i in ops {
            let at = 4 + count * 2 + i * 2;
            let id = numbers[at]; let outcome = numbers[at + 1];
            if id == -1 {
                let next = task::take(s); output.append(str(" T", dispatch_code(next.kind), ":", next.task));
            } else {
                let status = task::finish(s, id, outcome != 0); output.append(str(" F", error_code(status.kind)));
            }
            output.append(" S");
            for id in n { output.append(str(state_code(task::state(s, id)))); output.push(','); }
            let totals = task::summary(s);
            output.append(str(" C", totals.running, ",", totals.succeeded, ",", totals.failed, ",", totals.skipped));
        }
        print(output);
    }
}
