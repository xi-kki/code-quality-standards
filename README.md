# Code Quality Standards

**Self-documenting code as a first-class skill.**

This repository contains a framework for writing code that teaches as it runs — a quality assurance system that not only checks your code but explains *why* each check exists, *what* it protects against, and *how* to fix it.

## The Problem

Most quality scripts are opaque. They work, but they don't teach. When a developer hits a failing check, they see:

```
ERROR: clippy failed
```

Not:

```
ERROR: Clippy found a redundant clone in src/escrow.move:42
Why this matters: Unnecessary clones allocate memory that's immediately
dropped. In a hot loop, this impacts gas costs.
```

This repo is the difference between a **tool** and a **mentor**.

## The 4-Layer Philosophy

| Layer | Principle | In Practice |
|-------|-----------|-------------|
| **1** | **Self-documenting code** — the code *is* the docs | `calculateEscrowExpirationTime()` not `calc()` |
| **2** | **Clear naming & structure** — reads like prose | Module separation by concern, consistent patterns |
| **3** | **Strategic comments** — explain *why*, not *what* | "7 days prevents indefinite fund locks" not "7-day timeout" |
| **4** | **Auto-generated documentation** — READMEs, docgen from code | Architecture diagrams, usage examples, API refs |

See [STANDARDS.md](./STANDARDS.md) for the full 5-section standards document.

## What's Here

```
├── STANDARDS.md                        # The full quality standards (5 sections)
├── src/escrow.move                     # Example: a fully-documented Move function
├── scripts/
│   └── quality-gate.sh                 # Self-documenting QA script (bash)
├── .github/workflows/
│   └── quality.yml                     # GitHub Actions CI workflow
└── docs/
    ├── ARCHITECTURE.md                 # Example: auto-generated architecture docs
    └── USAGE.md                        # Example: usage guide from doc comments
```

## The Quality Gate Script

[`scripts/quality-gate.sh`](./scripts/quality-gate.sh) is the centerpiece — a production-grade script that:

| Step | Check | Why This Order | Exit Code |
|------|-------|----------------|-----------|
| 1 | Linting (clippy, ESLint) | Fast, catches syntax errors first | 1 |
| 2 | Formatting (rustfmt, Prettier) | Cosmetic — pointless on invalid code | 2 |
| 3 | Type checking (cargo check, tsc) | Catches ~40% of production bugs | 3 |
| 4 | Tests (cargo test, vitest/jest) | Runtime correctness | 4 |
| 5 | Security audit (cargo audit, npm audit) | Slowest, optional in dev mode | 5 |
| 6 | Documentation check | Informational, non-blocking | — |

The entire script is written to be self-documenting — every block explains the *why* behind the check.

### Usage

```bash
# Full pipeline (for CI)
./scripts/quality-gate.sh

# Quick iteration (skip security, save 30s)
./scripts/quality-gate.sh --quick

# Auto-fix formatting where possible
./scripts/quality-gate.sh --fix
```

## The Example

[`src/escrow.move`](./src/escrow.move) is a single function (`complete_escrow`) that demonstrates all 5 standards applied simultaneously:

- **Layer 1:** Clear names (`complete_escrow`, `EAMOUNT_MISMATCH`)
- **Layer 2:** Strategic comments ("prevents double-spending", "prevents partial releases")
- **Layer 3:** Full doc block (Purpose, Arguments, Side Effects, Errors, Security)
- **Layer 4:** Inline explanations (each guard explains what + why + which attack)
- **Layer 5:** Structured for automatic doc generation

## CI Integration

The GitHub Actions workflow at [`.github/workflows/quality.yml`](./.github/workflows/quality.yml) runs the same checks as the local script, configured for:

- Parallel job execution (lint / typecheck / test / security / docs)
- Caching (Rust crates, npm packages)
- PR annotations (failing annotations on changed lines)
- Never auto-fixing (CI detects, devs fix locally)

## Quick Start

```bash
# Clone the repo
git clone <repo-url>
cd code-quality-standards

# Run the quality gate
./scripts/quality-gate.sh

# Review the standards
cat STANDARDS.md

# See the example function
cat src/escrow.move
```

## Contributing

This repo is designed to be forked and adapted. To add support for a new language:

1. Add the lint/format/typecheck/test commands to `scripts/quality-gate.sh`
2. Add a corresponding job in `.github/workflows/quality.yml`
3. Add a section in `STANDARDS.md` for language-specific conventions

## License

MIT — use it, fork it, learn from it, ship with it.
