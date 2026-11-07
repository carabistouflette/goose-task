# Initial validation

Validated source: `033eaa5b8a621fafe366bab40baecdea9e8429ff`. Later evidence-only commits do not change
library, test, example, toolchain or build source. This is local validation;
no public remote, release tag or successful hosted CI is claimed.

- Platform: Linux-7.2.11-arch1-1-x86_64-with-glibc2.44.
- Goose revision: `eadca409f68210893f366e60d0c2f0dc29a339be`,
  independently checked against the compiler checkout's HEAD.
- Goose executable SHA-256: `7ffde13da95fbbdaa15b27419494fc9b71f2c91c0b4c4d732f51815e928a4b56`.
- GCC: gcc (GCC) 16.2.1 20260810.
- Clang: clang version 23.1.4.

Passed with GCC and Clang: format/type checks, JIT API tests/examples,
optimized and debug/no-BCE API tests, optimized and debug independent model
runs (6,127 graphs each). Standalone ASan/UBSan API and model checks passed
with both compilers, plus actual -O2 sanitized API tests. Sanitizer wrapper
preserves caller optimization flags; earlier O1 runs are not substituted for O2.

A fresh standalone local Git clone passed the complete GCC check/test/debug/model
and sanitizer targets using the exact shared compiler. It did not rebuild the
compiler through setup. The [receipt](standalone-validation.json) retains full
commands and normalized logs, source identity and compiler hash. Clang checks
were run in the original standalone repository. Other platforms and architectures
have not been validated.

Two independent reviewers examined the design, actual source/tests, and final
tooling/documentation. No core correctness or security blockers were found.
Review recommendations added maximum-concurrency and endpoint-diagnostic tests;
final tooling findings fixed sanitizer optimization override and benchmark output
selection before this validated source commit. This is review evidence, not a
claim of formal verification or maximum attainable performance.

Five-round, ten-iteration GCC/Clang benchmark smoke results are preserved under
[bench/results/local-smoke](../bench/results/local-smoke/). Both recordings used
clean source at the commit above. Each includes all raw samples and source,
compiler, C compiler and executable hashes. No competitor or speedup claim.

Before public publication: choose and verify a private vulnerability reporting
destination, perform publication review, and obtain exact-source hosted CI.
Honk adoption and parent-catalog registration require separate consumer/release
validation. Existing workspace projects have not been changed.
