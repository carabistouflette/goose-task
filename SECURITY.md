# Security policy

This library is experimental and currently an unpublished standalone checkout.
Only its latest source is maintained. Report suspected vulnerabilities privately
to the project maintainer; do not disclose sensitive inputs in public issues or
CI logs. A public release must provide a verified private reporting destination.
Include affected commit, compiler revision, platform and a minimal reproducer;
omit credentials and production data.

Untrusted node counts, limits and edge endpoints are validated before indexing.
Hard caps bound logical work and storage; choose lower application limits where
needed. No recursion, command execution, filesystem access, callbacks, hashing
or native code occurs in the library. The Goose compiler and runtime remain
trusted; allocation failure is not recoverable through this interface.

Scheduler fields and detail_* helpers are private by contract. Fabricated or
mutated internal state is unsupported. Call each scheduler serially and report
completion only when the caller's actual work has completed. Task IDs do not
provide authentication or permission checks. Scheduling does not confine tasks,
stop descendants, enforce real-time deadlines or validate process results.

Independent models, hard-limit tests, debug checks and ASan/UBSan validation
improve confidence but do not prove the absence of defects. Publication and
consumer adoption require separate review and exact-source CI evidence.
