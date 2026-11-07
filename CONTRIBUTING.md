# Contributing

Use focused feat/, fix/ or docs/ branches and Conventional Commits such as
`feat: add bounded graph planning`. One coherent change per commit. Commit no
binaries, toolchains, credentials or private coordination notes.

Use the exact GOOSE_REVISION. Run `make format check test test-debug sanitize
property bench` with GCC and Clang where applicable. Public behavior needs
positive, failure, boundary and model-based regression coverage. Keep process I/O
outside the library; preserve ownership, error and bounded-work contracts.

Get independent review and fix actionable findings before publication. Profile
before optimizing. Keep reproducible benchmark inputs, raw slower results and
exact source/compiler/platform identities; CI checks correctness, not speed.
Compiler changes need independent review and full validation. Releases use SemVer;
never move a published tag. Before 1.0 the interface may change.
