// SPDX-License-Identifier: Apache-2.0
import task from "..";
import std;
import os;
fn measure(name: const u8[:], n: i64, edges: const task::Edge[:], iterations: i64) {
    var limits = task::Limits { .. };
    var checksum = 0;
    let begin = clock_ns();
    for round in iterations {
        let order, error = task::plan(n, edges, limits);
        assert(error.kind == task::ErrorKind.None && order.len == n);
        checksum += order.len;
    }
    print(name, "\tplan\t", clock_ns() - begin, "\t", iterations);
    for failure in 2 {
        var elapsed = 0;
        for round in iterations {
            var s = task::Scheduler { .. };
            assert(task::start(s, n, edges, 16, limits).kind == task::ErrorKind.None);
            let start = clock_ns();
            while true {
                let next = task::take(s);
                if next.kind == task::DispatchKind.Done { break; }
                assert(next.kind == task::DispatchKind.Ready);
                assert(task::finish(s, next.task, failure == 0).kind == task::ErrorKind.None);
            }
            elapsed += clock_ns() - start;
            let result = task::summary(s);
            assert(result.running == 0 && result.succeeded + result.failed + result.skipped == n);
            if failure == 0 { assert(result.succeeded == n); }
            else { assert(result.succeeded == 0); }
            checksum += result.succeeded + result.failed + result.skipped;
        }
        print(name, if failure == 0 { "\tsuccess\t" } else { "\tfailure\t" }, elapsed, "\t", iterations);
    }
    assert(checksum == 3 * iterations * n);
}
fn main() {
    let argv = args();
    var iterations = 10;
    if argv.len > 1 { let value, ok = parse_int(argv[1]); assert(ok && value > 0 && value <= 10000); iterations = value; }
    let n = 4096;
    var edges: task::Edge[>..] = [];
    measure("independent", n, edges, iterations);
    for i in n - 1 { edges.push(task::Edge { i + 1, i }); }
    measure("reverse_chain", n, edges, iterations);
    edges.clear();
    for i in n - 1 { edges.push(task::Edge { 0, i + 1 }); }
    measure("wide", n, edges, iterations);
    edges.clear();
    for i in 256 { edges.push(task::Edge { i, 256 }); }
    for i in 256..n - 1 { edges.push(task::Edge { i, i + 1 }); }
    measure("overlapping_failures", n, edges, iterations);
    edges.clear();
    for i in 65536 { edges.push(task::Edge { 0, 1 }); }
    measure("duplicates", 2, edges, iterations);
}
