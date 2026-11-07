// SPDX-License-Identifier: Apache-2.0
// Caller owns actual commands; this example only reports outcomes.
import task from "..";
import std;
fn main() {
    let names = ["compile", "lint", "test", "package"];
    let edges = [task::Edge { 0, 2 }, task::Edge { 2, 3 }, task::Edge { 1, 3 }];
    var limits = task::Limits { .. };
    var s = task::Scheduler { .. };
    assert(task::start(s, names.len, edges, 2, limits).kind == task::ErrorKind.None);
    while true {
        let next = task::take(s);
        if next.kind == task::DispatchKind.Done { break; }
        assert(next.kind == task::DispatchKind.Ready);
        print("run ", names[next.task]);
        assert(task::finish(s, next.task, true).kind == task::ErrorKind.None);
    }
    assert(task::summary(s).succeeded == names.len);
}
