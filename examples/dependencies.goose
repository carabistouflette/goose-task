// SPDX-License-Identifier: Apache-2.0
// Honk-shaped cycle validation; not an integration or ordering promise.
import task from "..";
import std;
fn main() {
    var limits = task::Limits { tasks: 256, edges: 65536 };
    let edges = [task::Edge { 0, 1 }, task::Edge { 0, 2 }, task::Edge { 1, 3 }, task::Edge { 2, 3 }];
    let order, error = task::plan(4, edges, limits);
    assert(error.kind == task::ErrorKind.None && order == [0, 1, 2, 3]);
    let cycle, cycle_error = task::plan(2, [task::Edge { 0, 1 }, task::Edge { 1, 0 }], limits);
    assert(cycle.len == 0 && cycle_error.kind == task::ErrorKind.Cycle);
    print("dependency validation passed");
}
