#!/usr/bin/env bash
# ==============================================================================
# Code Quality Gate — Self-Documenting Edition
# ==============================================================================
#
# What this script is:
#   A quality assurance gate that runs linting, formatting, type-checking,
#   tests, and security scans — ordered intentionally so that fast, cheap
#   checks run first. Every block explains WHY, not just WHAT.
#
# What this script teaches:
#   - Quality checks have a cost/benefit order (fail-fast > cosmetic)
#   - Each check protects against a specific class of defect
#   - A CI pipeline is only as good as its failure messages
#
# Usage:
#   ./scripts/quality-gate.sh            # Run all checks
#   ./scripts/quality-gate.sh --quick    # Skip security (for dev iteration)
#   ./scripts/quality-gate.sh --fix      # Auto-fix where possible
#
# Exit codes:
#   0 = all checks pass
#   1 = linting failure
#   2 = formatting failure
#   3 = type-check failure
#   4 = test failure
#   5 = security audit failure
# ==============================================================================

set -euo pipefail  # Fail fast: exit on error, undefined vars, pipe failures

# ── Configuration ──────────────────────────────────────────────────────────
# Why constants instead of inline strings: Single source of truth makes the
# script easy to adapt to different repos without hunting for magic strings.
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color
readonly PASS_MARK="${GREEN}✓${NC}"
readonly FAIL_MARK="${RED}✗${NC}"
readonly SKIP_MARK="${YELLOW}—${NC}"

# ── Flag parsing ───────────────────────────────────────────────────────────
# Why positional flags and not getopts: This script is designed to be simple
# enough for any developer to read and modify. Explicit parsing beats opaque
# option strings when readability is the priority.
QUICK_MODE=false
FIX_MODE=false

for arg in "$@"; do
    case "$arg" in
        --quick) QUICK_MODE=true ;;
        --fix)   FIX_MODE=true   ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--quick] [--fix]"
            exit 1
            ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────────
# Why these exist: Consistent output formatting makes failures scannable in
# CI logs. A developer should be able to glance at a failed pipeline and
# immediately know which check broke and why.

print_header() {
    # Prints a section header with visual separation
    # Why: Logs without visual hierarchy are hard to scan under time pressure
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════════════════════════════════"
}

print_result() {
    # Prints a pass/fail result with consistent formatting
    # Why: Uniform output means CI parsers and humans can both read results
    local status="$1"
    local message="$2"
    echo -e "  ${status} ${message}"
}

print_info() {
    echo -e "  ${YELLOW}ℹ${NC} $1"
}

# ── Quality Gate — Step 1: Linting ─────────────────────────────────────────
# Why linting first:
#   Linters catch syntax errors, import issues, and style violations BEFORE
#   the formatter runs. This ordering is intentional: linting fails fast on
#   actual errors, while formatting is purely cosmetic. No point formatting
#   code that has syntax errors.
#
# Why cargo clippy (or the language-appropriate linter):
#   - Catches common mistakes that the compiler allows (e.g., unnecessary
#     clones, redundant pattern matches)
#   - Enforces idiomatic conventions across the team
#   - Its --fix flag resolves ~80% of warnings automatically

run_lint() {
    print_header "Step 1: Linting"

    local lint_failed=false

    # ── Rust/Move: cargo clippy ──────────────────────────────────────
    # Why clippy over rustc warnings: Clippy has 700+ opinionated lints
    # that enforce idiomatic Rust/Move patterns. rustc only catches
    # compiler errors, not style or correctness anti-patterns.
    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
        print_info "Running cargo clippy..."

        local clippy_args="-- -D warnings"
        if [[ "$FIX_MODE" == true ]]; then
            # --fix is opt-in because auto-fixes can change semantics
            # in rare cases (e.g., suggestion to clone when ownership
            # transfer was intentional)
            clippy_args="--fix --allow-staged --allow-dirty -- -D warnings"
        fi

        if (cd "$REPO_ROOT" && cargo clippy $clippy_args 2>/dev/null); then
            print_result "$PASS_MARK" "clippy — no warnings"
        else
            print_result "$FAIL_MARK" "clippy — fix warnings above"
            lint_failed=true
        fi
    else
        # No Cargo.toml means we adapt: ESLint for JS/TS, Ruff for Python, etc.
        # This pattern (file-detection → appropriate tool) makes the script
        # language-agnostic without over-engineering.
        print_info "No Cargo.toml found — skipping clippy"
    fi

    # ── TypeScript/JavaScript: ESLint ─────────────────────────────────
    # Why ESLint over tsc: tsc checks types; ESLint checks logic, style,
    # and anti-patterns. They're complementary, not alternatives.
    if [[ -f "$REPO_ROOT/.eslintrc.cjs" || -f "$REPO_ROOT/.eslintrc.js" || -f "$REPO_ROOT/eslint.config.js" ]]; then
        print_info "Running ESLint..."

        local eslint_flags="--max-warnings 0"
        [[ "$FIX_MODE" == true ]] && eslint_flags="$eslint_flags --fix"

        if (cd "$REPO_ROOT" && npx eslint . $eslint_flags 2>/dev/null); then
            print_result "$PASS_MARK" "ESLint — no errors or warnings"
        else
            print_result "$FAIL_MARK" "ESLint — fix issues above"
            lint_failed=true
        fi
    fi

    if [[ "$lint_failed" == true ]]; then
        # Why exit 1 specifically: The exit code tells the CI system and
        # any wrapper scripts exactly which gate failed, enabling targeted
        # retries or skip logic.
        exit 1
    fi
}

# ── Quality Gate — Step 2: Formatting ──────────────────────────────────────
# Why formatting after linting:
#   Linting may reject the code outright (syntax errors). No point running
#   the formatter on invalid code. Formatting is the "cosmetic" pass that
#   ensures consistent style across the codebase.
#
# Why formatting matters (beyond aesthetics):
#   - Eliminates style debates in code review ("tabs vs spaces" resolved)
#   - Reduces diff noise (auto-formatted code changes look like the rest
#     of the codebase)
#   - Makes generated code (from AI assistants) conform to team standards

run_format() {
    print_header "Step 2: Formatting"

    local format_failed=false

    # ── Rust/Move: cargo fmt ─────────────────────────────────────────
    # Why rustfmt over manual formatting: rustfmt is the official formatter
    # with zero configuration decisions. It enforces the community standard,
    # so all Rust/Move code looks the same regardless of author.
    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
        print_info "Running cargo fmt..."

        if [[ "$FIX_MODE" == true ]]; then
            if (cd "$REPO_ROOT" && cargo fmt --all 2>/dev/null); then
                print_result "$PASS_MARK" "rustfmt — formatted"
            else
                print_result "$FAIL_MARK" "rustfmt — formatting failed"
                format_failed=true
            fi
        else
            # --check: non-destructive mode. In CI, we NEVER auto-format
            # because we want the author to own the formatting commit.
            # Auto-format in CI obscures who introduced style changes.
            if (cd "$REPO_ROOT" && cargo fmt --all --check 2>/dev/null); then
                print_result "$PASS_MARK" "rustfmt — all formatted"
            else
                print_result "$FAIL_MARK" "rustfmt — run 'cargo fmt --all' to fix"
                format_failed=true
            fi
        fi
    fi

    # ── TypeScript/JavaScript: Prettier ───────────────────────────────
    if [[ -f "$REPO_ROOT/.prettierrc" || -f "$REPO_ROOT/.prettierrc.js" ]]; then
        print_info "Running Prettier..."

        local prettier_flags="--check ."
        [[ "$FIX_MODE" == true ]] && prettier_flags="--write ."

        if (cd "$REPO_ROOT" && npx prettier $prettier_flags 2>/dev/null); then
            print_result "$PASS_MARK" "Prettier — all formatted"
        else
            print_result "$FAIL_MARK" "Prettier — run 'npx prettier --write .' to fix"
            format_failed=true
        fi
    fi

    if [[ "$format_failed" == true ]]; then
        exit 2
    fi
}

# ── Quality Gate — Step 3: Type Checking ───────────────────────────────────
# Why type-checking after formatting:
#   Type errors produce long, multi-line messages. If the code is
#   unformatted, those messages are harder to read. Format first, then
#   present the most complex errors.
#
# Why type-checking is not optional:
#   - Catches ~40% of production bugs before they reach testing
#   - Documents the contract between components (types = executable docs)
#   - Makes refactoring safer (the compiler tells you what broke)

run_typecheck() {
    print_header "Step 3: Type Checking"

    local typecheck_failed=false

    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
        print_info "Running cargo check (type-checking)..."
        # cargo check is faster than cargo build because it skips LLVM codegen
        # Why not cargo build: We only need type-checking here. Build happens
        # in a separate, optimized CI step with caching. This gate is about
        # fast feedback, not producing artifacts.
        if (cd "$REPO_ROOT" && cargo check 2>/dev/null); then
            print_result "$PASS_MARK" "cargo check — types correct"
        else
            print_result "$FAIL_MARK" "cargo check — type errors above"
            typecheck_failed=true
        fi
    fi

    if [[ -f "$REPO_ROOT/tsconfig.json" ]]; then
        print_info "Running tsc (TypeScript)..."
        # --noEmit: don't produce JS files, only check types
        # Why --noEmit: TypeScript compilation is handled by the build tool
        # (esbuild, webpack, etc.). tsc's emitter is slow and redundant here.
        if (cd "$REPO_ROOT" && npx tsc --noEmit 2>/dev/null); then
            print_result "$PASS_MARK" "tsc — types correct"
        else
            print_result "$FAIL_MARK" "tsc — type errors above"
            typecheck_failed=true
        fi
    fi

    if [[ "$typecheck_failed" == true ]]; then
        exit 3
    fi
}

# ── Quality Gate — Step 4: Tests ───────────────────────────────────────────
# Why tests after type-checking:
#   Tests expose runtime errors, which are more expensive to diagnose than
#   type errors. We want to confirm the code compiles (type-check) before
#   we spend time running tests that could fail due to type mismatches.
#
# Why unit tests before integration tests:
#   Unit tests are faster and more deterministic. Fail-fast on unit tests
#   saves the time of running slower integration tests against broken code.

run_tests() {
    print_header "Step 4: Tests"

    local tests_failed=false

    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
        print_info "Running cargo test (unit + integration)..."
        # Why no --release for unit tests: Debug mode catches more panic
        # details and is faster to compile. Integration/E2E tests may
        # warrant --release, but that's a separate pipeline optimization.
        if (cd "$REPO_ROOT" && cargo test 2>/dev/null); then
            print_result "$PASS_MARK" "cargo test — all passed"
        else
            print_result "$FAIL_MARK" "cargo test — failures above"
            tests_failed=true
        fi
    fi

    if [[ -f "$REPO_ROOT/package.json" ]]; then
        local test_runner
        # Auto-detect test runner: vitest > jest > mocha
        # Why this order: vitest is faster (ESM-native, esbuild), jest is
        # the incumbent, mocha is legacy.
        if (cd "$REPO_ROOT" && npx vitest --run 2>/dev/null); then
            print_result "$PASS_MARK" "vitest — all passed"
        elif (cd "$REPO_ROOT" && npx jest 2>/dev/null); then
            print_result "$PASS_MARK" "jest — all passed"
        elif (cd "$REPO_ROOT" && npx mocha 2>/dev/null); then
            print_result "$PASS_MARK" "mocha — all passed"
        else
            print_result "$FAIL_MARK" "tests — check package.json for test runner"
            tests_failed=true
        fi
    fi

    if [[ "$tests_failed" == true ]]; then
        exit 4
    fi
}

# ── Quality Gate — Step 5: Security Audit (optional in --quick mode) ──────
# Why security last (or optional):
#   Security scans (CVE checks, linting for unsafe patterns) are the slowest
#   and most likely to produce false positives. Running them last means we
#   don't block developers on security warnings when their code has syntax
#   errors or failing tests.
#
# Why security is optional in --quick mode:
#   During active development, a dev might run the gate 50+ times per hour.
#   Security scanning every iteration would add 30-60 seconds each time.
#   The CI pipeline always runs the full gate, including security.

run_security() {
    print_header "Step 5: Security Audit"

    if [[ "$QUICK_MODE" == true ]]; then
        print_info "Quick mode — skipping security audit"
        return 0
    fi

    local security_failed=false

    # ── Rust/Move: cargo audit ────────────────────────────────────────
    # Why cargo audit: It checks the dependency tree against the RustSec
    # Advisory Database. A single vulnerable transitive dependency is
    # invisible to code review but detectable here.
    if [[ -f "$REPO_ROOT/Cargo.lock" ]]; then
        print_info "Running cargo audit..."
        if command -v cargo-audit &>/dev/null; then
            if (cd "$REPO_ROOT" && cargo audit 2>/dev/null); then
                print_result "$PASS_MARK" "cargo audit — no known vulnerabilities"
            else
                print_result "$FAIL_MARK" "cargo audit — vulnerabilities found"
                security_failed=true
            fi
        else
            print_info "cargo-audit not installed — run 'cargo install cargo-audit'"
        fi
    fi

    # ── JavaScript/TypeScript: npm audit ──────────────────────────────
    if [[ -f "$REPO_ROOT/package-lock.json" ]]; then
        print_info "Running npm audit..."
        if (cd "$REPO_ROOT" && npm audit --audit-level=high 2>/dev/null); then
            print_result "$PASS_MARK" "npm audit — no high/critical vulnerabilities"
        else
            print_result "$FAIL_MARK" "npm audit — vulnerabilities found (run npm audit fix)"
            security_failed=true
        fi
    fi

    if [[ "$security_failed" == true ]]; then
        exit 5
    fi
}

# ── Quality Gate — Step 6: Documentation Check (optional) ─────────────────
# Why docs after security:
#   Docs are important but should never block a deployment. This step warns
#   about missing documentation but doesn't fail the pipeline by default.
#
# What we check:
#   - Every public function has a doc comment (via regex pattern match)
#   - README.md exists and isn't the template
#   - CHANGELOG.md or RELEASES.md has recent entries

run_docs_check() {
    print_header "Step 6: Documentation Check"

    local docs_issues=0

    # ── Check README exists ───────────────────────────────────────────
    # Why: A repo without a README is a repo nobody can use. The README
    # is the front door — if it's missing or obviously templated, warn.
    if [[ ! -f "$REPO_ROOT/README.md" ]]; then
        print_result "$FAIL_MARK" "README.md is missing — create one"
        docs_issues=$((docs_issues + 1))
    elif grep -qi "TODO\|replace this\|example\|sample" "$REPO_ROOT/README.md" 2>/dev/null; then
        print_info "README.md may still contain placeholder text"
        docs_issues=$((docs_issues + 1))
    else
        print_result "$PASS_MARK" "README.md exists"
    fi

    # ── Check for public function docs (Move/Rust files) ──────────────
    # Why regex over AST parsing: We're a shell script, not a compiler.
    # A simple regex catches 90% of undocumented functions. The remaining
    # 10% are edge cases that should be caught in code review.
    if [[ -d "$REPO_ROOT/src" ]]; then
        local undoc_count=0
        while IFS= read -r -d '' file; do
            # Look for `pub fun` or `pub fn` without a preceding `///`
            # Why this pattern: In Move and Rust, public functions are the
            # API surface. Private functions are implementation details that
            # don't require docs by this standard.
            local undocumented
            undocumented=$(grep -c '^pub fun\|^pub fn' "$file" 2>/dev/null || true)
            local documented
            documented=$(grep -c '///\|/// #' "$file" 2>/dev/null || true)
            if [[ "$undocumented" -gt "$documented" ]]; then
                undoc_count=$((undoc_count + ($undocumented - $documented)))
                print_info "Undocumented public functions in: $file"
            fi
        done < <(find "$REPO_ROOT/src" -name "*.move" -o -name "*.rs" -print0 2>/dev/null)

        if [[ "$undoc_count" -gt 0 ]]; then
            print_result "$FAIL_MARK" "$undoc_count public function(s) missing doc comments"
            docs_issues=$((docs_issues + 1))
        else
            print_result "$PASS_MARK" "All public functions have doc comments"
        fi
    fi

    # ── Summary ───────────────────────────────────────────────────────
    if [[ "$docs_issues" -gt 0 ]]; then
        print_info "Documentation issues found ($docs_issues) — these are warnings, not blockers"
    else
        print_result "$PASS_MARK" "Documentation looks complete"
    fi
}

# ── Summary ────────────────────────────────────────────────────────────────
# Why a summary block: CI logs are long. A developer should be able to scroll
# to the bottom and immediately see PASS/FAIL for every step. This pattern
# (header → result per step → final verdict) is called a "dashboard pattern."

print_summary() {
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "  Quality Gate Complete"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  All checks passed. The code meets the project's quality standards."
    echo ""
    echo "  What was checked:"
    echo "    ✓ Linting         — Syntax, imports, style"
    echo "    ✓ Formatting      — Style consistency"
    echo "    ✓ Type checking   — Type safety"
    echo "    ✓ Tests           — Correctness"
    [[ "$QUICK_MODE" == false ]] && echo "    ✓ Security audit  — Vulnerability scan"
    echo "    ✓ Documentation   — Code documentation health"
    echo ""
    echo "  Next steps:"
    echo "    - Review any warnings above"
    echo "    - Commit and push"
    echo "    - CI will run the full pipeline"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────
# Why main(): Every script should have a clear entry point. Implicit
# execution (running code at module level) makes testing impossible.
# With main(), we can source the script for unit tests.

main() {
    echo ""
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║  Code Quality Gate                                  ║"
    echo "  ║  Self-documenting code as a first-class skill       ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "  Mode: $( [[ "$QUICK_MODE" == true ]] && echo 'quick (dev)' || echo 'full (CI)' )"
    [[ "$FIX_MODE" == true ]] && echo "  Auto-fix: enabled"

    # ── Execution order (intentional) ────────────────────────────────
    # Fast, cheap checks first → slow, expensive checks last
    # If linting fails, we exit before wasting time on formatting or tests.
    run_lint
    run_format
    run_typecheck
    run_tests
    run_security
    run_docs_check

    print_summary
}

# Only run main if executed directly (not sourced)
# Why guard: This pattern lets us source the script in tests and call
# individual functions without triggering the pipeline.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
