---
name: test-guard
description: Comprehensive multi-dimensional testing suite. Runs quality gates across 7 dimensions: kill/chaos, code quality, functional tests, performance, security, accessibility, and coverage. Use when user says "run tests", "test everything", "full scan", "quality gate", "CI check", "chaos test", "kill test", "load test", "benchmark", "a11y test", "accessibility check", "security scan", "coverage report", or "quick test". Supports --quick, --full, --kill, --dim=<name> modes.
argument-hint: "[--quick|--full|--kill|--dim=<lint|func|security|perf|a11y|coverage|chaos>] [--target=<service|file|url>] [--language=<python|typescript|rust|auto>]"
level: 3
---

## Overview

Test Guard is a comprehensive quality-gating skill that runs testing across seven dimensions. It auto-detects project language and tooling, executes the appropriate checks, and produces a unified pass/fail report.

**Philosophy**: Tests are proof. "Seems right" is not done. Every dimension must produce auditable evidence -- exit codes, coverage percentages, timing histograms, vulnerability counts.

## When to Use

- Before merging a PR or cutting a release
- After completing a feature implementation
- When debugging a regression
- On a schedule as a CI-alike health check
- When onboarding a new codebase to establish baseline quality

## Modes

| Mode | Flag | Dimensions Run | Use Case |
|------|------|----------------|----------|
| **quick** | `--quick` | code quality + functional (unit only) | Pre-commit, fast feedback |
| **full** | `--full` | all 7 dimensions | PR merge gate, release candidate |
| **kill** | `--kill` | chaos only | Resilience validation |
| **dim** | `--dim=<name>` | single dimension | Targeted investigation |
| **default** | (none) | code quality + functional + security | Balanced everyday check |

### Dimension → Phase Mapping

| `--dim=` value | Phase | Title |
|---------------|-------|-------|
| `lint` | Phase 1 | Code Quality |
| `func` | Phase 2 | Functional Testing |
| `security` | Phase 3 | Security Scanning |
| `perf` | Phase 4 | Performance Testing |
| `a11y` | Phase 5 | Accessibility Testing |
| `coverage` | Phase 6 | Coverage Analysis |
| `chaos` | Phase 7 | Kill/Chaos Testing |

If `--dim=<name>` does not match any valid value, report: `Unknown dimension '<name>'. Valid: lint, func, security, perf, a11y, coverage, chaos.`

## Phase 0: Environment Discovery

### 0.1 Language Detection

Inspect the project root for ecosystem signals:

| Check | Language |
|-------|----------|
| `pyproject.toml` / `setup.py` / `setup.cfg` | Python |
| `package.json` | TypeScript/JavaScript |
| `Cargo.toml` | Rust |

### 0.2 Tool Availability

Run once and cache results:

```bash
for tool in pytest vitest playwright k6 trivy ruff shellcheck axe http cargo-tarpaulin nyc eslint bandit vegeta pa11y; do
  which $tool >/dev/null 2>&1 && echo "$tool:OK" || echo "$tool:MISSING"
done
```

### 0.3 Test Runner Discovery

- **Python**: `pytest` (check `pytest.ini`, `pyproject.toml[tool.pytest]`)
- **TypeScript/JS**: `vitest` (check `vitest.config.*`), fallback `jest`
- **Rust**: `cargo test`

### 0.4 MCP Server Discovery

Check if complementary MCP servers are configured. If available, prefer their structured, lifecycle-safe tools over raw bash commands.

**Chaos MCP (Typewise/mcp-chaos-rig)** -- preferred for the kill/chaos dimension:
- Provides `mcp__chaos_rig__kill_process`, `mcp__chaos_rig__exhaust_cpu`, `mcp__chaos_rig__exhaust_memory`, `mcp__chaos_rig__inject_latency`, `mcp__chaos_rig__drop_packets`, `mcp__chaos_rig__partition_network`, `mcp__chaos_rig__heal_all`
- If available, use these instead of bash-level kill/pkill/stress-ng

**QA Master MCP (kao273183/mk-qa-master)** -- preferred for unified test orchestration:
- Provides `mcp__mk_qa_master__run_tests`, `mcp__mk_qa_master__run_lint`, `mcp__mk_qa_master__coverage_report`, `mcp__mk_qa_master__security_scan`
- If available, delegate test/lint/coverage/security dimensions to it
- Covers pytest, Jest, Cypress, Go, Maestro across web+mobile

If MCP tools are unavailable, fall back to the bash commands documented below.

### 0.5 Target Discovery

If `--target` is not provided:
- For functional/perf/chaos: check for `docker-compose.yml`, running dev server on ports 3000/4000/5000/8000/8080/9000
- For a11y: require a URL; prompt user if none found
- For lint/coverage: default to project root

## Phase 1: Code Quality (Lint, Format, Static Analysis)

**Goal**: Zero lint errors, consistent formatting.

### Commands by Language

**Python:**
```bash
ruff check . --output-format=concise
ruff format . --check --diff
```

**TypeScript/JavaScript:**
```bash
# Lint: distinguish "not configured" from "found errors"
ESLINT_OUTPUT=$(npx eslint . --max-warnings 0 2>&1)
ESLINT_EXIT=$?
if [ $ESLINT_EXIT -eq 0 ]; then
  echo "eslint: PASSED"
elif echo "$ESLINT_OUTPUT" | grep -q "ESLint couldn't find\|No ESLint configuration"; then
  echo "eslint not configured, skipping"
else
  echo "eslint: FAILED"
  echo "$ESLINT_OUTPUT" | head -20
fi

# Type check
npx tsc --noEmit 2>/dev/null && echo "tsc: PASSED" || echo "tsc not configured, skipping"
```

**Rust:**
```bash
cargo fmt --check
cargo clippy -- -D warnings
```

**Shell (any project):**
```bash
find . -name "*.sh" -type f -exec shellcheck --severity=warning {} + 2>/dev/null
```

### Output
```
[TEST-GUARD] Code Quality:
[TEST-GUARD]   lint:   PASSED (0 errors)
[TEST-GUARD]   format: PASSED
```

### Failure Handling
If lint fails, report first 5 errors. Do NOT auto-fix unless `--fix` is passed. Do not proceed past a failed Phase 1.


## Phase 2: Functional Testing (Unit, Integration, E2E)

**Goal**: All tests pass.

### Commands by Language

**Python:**
```bash
python -m pytest -x -q --tb=short
```

**TypeScript/JavaScript:**
```bash
npx vitest run --reporter=verbose
npx playwright test --reporter=line 2>/dev/null || echo "Playwright not configured, skipping E2E"
```

**Rust:**
```bash
cargo test
```

### Output
```
[TEST-GUARD] Functional:
[TEST-GUARD]   unit:        PASSED (N tests, <time>)
[TEST-GUARD]   integration: PASSED (N tests, <time>)
[TEST-GUARD]   e2e:         SKIPPED (not configured)
```


## Phase 3: Security Scanning (SAST, Dependencies)

**Goal**: Zero critical/high vulnerabilities. No hardcoded secrets.

### Commands (language-agnostic)

```bash
# Dependency scanning
trivy fs --severity HIGH,CRITICAL --ignore-unfixed --no-progress .

# Hardcoded secrets check
grep -rE "(password|secret|api[_-]?key|token)\s*=\s*['\"][^'\"]+['\"]" --include="*.ts" --include="*.js" --include="*.py" . 2>/dev/null | grep -v "process.env" | grep -v "example" | grep -v "placeholder" || echo "No hardcoded secrets found"
```

**Python (additional):**
```bash
python -m bandit -r . -ll 2>/dev/null || ruff check . --select=S
```

**Rust (additional):**
```bash
cargo audit 2>/dev/null || echo "cargo-audit not installed, skipping"
```

**TypeScript/JS (additional):**
```bash
npm audit --audit-level=high 2>/dev/null || echo "npm audit not applicable (no package-lock.json)"
```

### Output
```
[TEST-GUARD] Security:
[TEST-GUARD]   dependencies: PASSED (0 HIGH, 0 CRITICAL)
[TEST-GUARD]   secrets:      PASSED
```

### Failure Handling
HIGH/CRITICAL: list each with CVE ID. Stop, require acknowledgment. Hardcoded secrets: CRITICAL, stop immediately.


## Phase 4: Performance Testing (Load, Stress, Benchmark)

**Goal**: Service meets latency/throughput targets under load. Requires a running service.

If no service is running, report: "Performance testing requires a running service. Start dev server and rerun."

### k6 Load Test

Generate and run a k6 script:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '20s', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('<TARGET_URL>');
  check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(1);
}
```

```bash
k6 run /tmp/test-guard-k6-load.js --summary-export=/tmp/test-guard-k6-summary.json
```

### Pre-flight Check

```bash
# Verify target is reachable before running load tests
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 <TARGET_URL> | grep -qE '^(2|3)[0-9]{2}$' || echo "TARGET_UNREACHABLE"
```

### Vegeta (simple load)

```bash
if which vegeta >/dev/null 2>&1; then
  echo "GET <TARGET_URL>" | vegeta attack -duration=30s -rate=10 | vegeta report
else
  echo "vegeta not installed, skipping"
fi
```

### Output
```
[TEST-GUARD] Performance:
[TEST-GUARD]   load:     PASSED (p95=<ms>ms < 500ms)
[TEST-GUARD]   stress:   SKIPPED (opt-in with --stress)
```


## Phase 5: Accessibility Testing (WCAG)

**Goal**: No critical or serious WCAG violations. Requires a URL.

### Commands

```bash
axe <TARGET_URL> --tags wcag2a,wcag2aa --exit --stdout --save /tmp/test-guard-a11y.json
pa11y <TARGET_URL> --standard WCAG2AA
```

### Output
```
[TEST-GUARD] Accessibility: <TARGET_URL>
[TEST-GUARD]   violations: 0 critical, 0 serious, 0 moderate
```


## Phase 6: Coverage Analysis

**Goal**: Meet configured coverage thresholds.

### Commands by Language

**Python:**
```bash
python -m pytest --cov=. --cov-report=term-missing -q
```

**TypeScript/JS:**
```bash
# Prefer vitest built-in coverage (v1.0+), fallback to nyc wrapper
npx vitest run --coverage 2>/dev/null || npx nyc --reporter=text vitest run 2>/dev/null
```

**Rust:**
```bash
cargo tarpaulin --out Stdout
```

### Thresholds (defaults)

| Language | Lines | Branches |
|----------|-------|----------|
| Python | 80% | N/A |
| TypeScript | 80% | 70% |
| Rust | 70% | N/A |

### Output
```
[TEST-GUARD] Coverage:
[TEST-GUARD]   lines:     84.2% (threshold: 80%) ✅
```


## Phase 7: Kill/Chaos Testing

**⚠️ WARNING**: Chaos testing is destructive. It kills processes, exhausts resources, and disrupts networks.
**NEVER run in production.** Always require user confirmation before executing.

### Confirmation Gate

1. Verify NOT in production (check `NODE_ENV`/`ENVIRONMENT`)
2. Prompt: "Chaos testing will kill processes and disrupt services. Continue? [y/N]"
3. Record state before starting for recovery

### If mcp-chaos-rig MCP is available (preferred)

Use structured tools with built-in lifecycle management:
```
mcp__chaos_rig__kill_process      -- kill a service process
mcp__chaos_rig__exhaust_cpu       -- consume CPU
mcp__chaos_rig__exhaust_memory    -- consume memory
mcp__chaos_rig__inject_latency    -- add network latency
mcp__chaos_rig__drop_packets      -- simulate packet loss
mcp__chaos_rig__partition_network -- isolate service
mcp__chaos_rig__heal_all          -- restore all injected failures
```
Always call `heal_all` at end (and in error handler).

### Bash-Only Fallback

```bash
# Process kill - verify restart
SERVICE_PID=$(pgrep -f "<service-pattern>" | head -1)
if [ -n "$SERVICE_PID" ]; then
  kill -9 $SERVICE_PID
  sleep 3
  # Check if service restarted
  pgrep -f "<service-pattern>" >/dev/null && echo "RESTARTED" || echo "NOT RESTARTED"
fi

# CPU pressure (10s) -- kill ALL background processes, not just %1
trap 'kill $(jobs -p) 2>/dev/null' EXIT
for i in $(seq 1 $(nproc)); do dd if=/dev/zero of=/dev/null & done
sleep 10
kill $(jobs -p) 2>/dev/null
trap - EXIT

# Network latency -- check sudo availability first
if sudo -n true 2>/dev/null; then
  sudo tc qdisc add dev lo root netem delay 500ms 2>/dev/null
  sleep 10
  sudo tc qdisc del dev lo root 2>/dev/null
else
  echo "sudo not available (passwordless sudo required), skipping network chaos"
fi
```

### Output
```
[TEST-GUARD] Chaos:
[TEST-GUARD]   process-kill:    PASSED (restarted in 3.2s)
[TEST-GUARD]   cpu-pressure:    PASSED
[TEST-GUARD]   network-latency: PASSED
[TEST-GUARD]   all failures healed: YES
```

### Cleanup (MANDATORY)

Always restore system state, even on error:
```bash
pkill -f stress-ng 2>/dev/null
pkill -f "dd if=/dev/zero" 2>/dev/null
sudo tc qdisc del dev lo root 2>/dev/null
find . -name "*.test-guard-bak" -exec sh -c 'mv "$1" "${1%.test-guard-bak}"' _ {} \; 2>/dev/null
```


## Phase 8: Summary Report

Produce a unified table:

```
╔══════════════════════════════════════════════════════════════╗
║                    TEST GUARD SUMMARY                        ║
╠══════════════╦════════╦══════════════════════════════════════╣
║ Dimension    ║ Result ║ Details                              ║
╠══════════════╬════════╬══════════════════════════════════════╣
║ Code Quality ║ PASS   ║ 0 lint errors, format clean          ║
║ Functional   ║ PASS   ║ 47 unit, 12 integration              ║
║ Security     ║ WARN   ║ 2 MEDIUM findings                    ║
║ Performance  ║ PASS   ║ p95=234ms < 500ms                   ║
║ Accessibility║ SKIP   ║ No URL provided                     ║
║ Coverage     ║ PASS   ║ 84.2% lines (threshold: 80%)        ║
║ Chaos        ║ PASS   ║ 4/5 tests passed                    ║
╠══════════════╩════════╬══════════════════════════════════════╣
║ Overall: PASS          ║
╚════════════════════════╝
```


## Quick Reference: Dimension → Tool Matrix

| Dimension | Python | TypeScript | Rust | Any |
|-----------|--------|------------|------|-----|
| Lint | ruff check | eslint/oxlint | cargo clippy | shellcheck |
| Format | ruff format | prettier | cargo fmt | - |
| Unit | pytest | vitest | cargo test | - |
| E2E | Playwright | Playwright | - | - |
| Security | trivy + bandit | trivy + npm audit | trivy + cargo audit | trivy |
| Perf | k6 / vegeta | k6 / vegeta | - | httpie |
| A11y | axe + pa11y | axe + pa11y | - | - |
| Coverage | pytest-cov | nyc + vitest | cargo-tarpaulin | - |
| Chaos | bash / k6 | bash / k6 | - | stress-ng |


## Anti-Patterns

1. **Never run chaos tests in production.** Always check environment markers first.
2. **Never auto-fix lint errors without asking** (unless `--fix` is passed).
3. **Never skip the confirmation gate for destructive operations.**
4. **Never proceed past a FAILED code quality dimension.** Garbage in, garbage out.
5. **Never assume a tool is installed.** Check Phase 0 and skip gracefully if missing.
6. **Never leave chaos artifacts behind.** Always run cleanup, even on error.
7. **Never produce a summary without having actually run the checks.**

## State Cache

Cache discovery results in `/tmp/test-guard-state.json` to avoid re-detection:

```json
{
  "languages": ["python", "typescript"],
  "tools": {"pytest": "OK", "vitest": "OK", "trivy": "OK"},
  "mcp_available": {"chaos_rig": false, "mk_qa_master": false},
  "dev_server": {"port": 8000, "url": "http://localhost:8000"}
}
```
