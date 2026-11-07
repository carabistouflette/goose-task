GOOSE ?= .toolchain/goose/build/goose
CC ?= gcc
SANITIZER_CC ?= gcc
BENCH_ITERATIONS ?= 10
BENCH_OUTPUT ?= .build/benchmark.json
.NOTPARALLEL:
.PHONY: setup format check test test-debug property sanitize bench
setup:
	./scripts/setup-goose.sh
format:
	"$(GOOSE)" format task.goose tests examples bench
check:
	"$(GOOSE)" format --check task.goose tests examples bench
	"$(GOOSE)" check tests/api.goose
	"$(GOOSE)" check tests/oracle.goose
	"$(GOOSE)" check examples/build.goose
	"$(GOOSE)" check examples/dependencies.goose
	"$(GOOSE)" check bench/bench.goose
	python3 -m py_compile tests/model.py scripts/benchmark.py
test:
	mkdir -p .build
	"$(GOOSE)" run tests/api.goose
	"$(GOOSE)" build tests/api.goose --cc "$(CC)" -O2 -o .build/api
	./.build/api
	"$(GOOSE)" run examples/build.goose
	"$(GOOSE)" run examples/dependencies.goose
test-debug:
	mkdir -p .build
	"$(GOOSE)" build tests/api.goose --cc "$(CC)" --debug --no-bce -o .build/api-debug
	./.build/api-debug
property:
	mkdir -p .build
	"$(GOOSE)" build tests/oracle.goose --cc "$(CC)" -O2 -o .build/oracle
	python3 tests/model.py .build/oracle
	"$(GOOSE)" build tests/oracle.goose --cc "$(CC)" --debug --no-bce -o .build/oracle-debug
	python3 tests/model.py .build/oracle-debug
sanitize:
	mkdir -p .build
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/api.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone --debug --no-bce -o .build/api-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 ./.build/api-sanitize
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/oracle.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone --debug --no-bce -o .build/oracle-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 python3 tests/model.py .build/oracle-sanitize
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/api.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone -O2 --no-bce -o .build/api-sanitize-optimized
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 ./.build/api-sanitize-optimized
bench:
	mkdir -p .build
	"$(GOOSE)" build bench/bench.goose --cc "$(CC)" -O2 -o .build/bench
	python3 scripts/benchmark.py --goose "$(GOOSE)" --cc "$(CC)" --iterations "$(BENCH_ITERATIONS)" --output "$(BENCH_OUTPUT)"
