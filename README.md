# Code Quality Standards

**Self-documenting code as a first-class skill.**

> Here are the GitHub repositories that will transform your code from "it works" to "this is how a senior engineer writes production-grade code." These repos teach you how to structure, document, and explain every line so your GitHub becomes a masterclass in professional development.

---

## 📚 Part 1: Code Documentation & Commenting Standards

### 1. [ryanmcdermott/clean-code-javascript](https://github.com/ryanmcdermott/clean-code-javascript)

Applies Robert C. Martin's *Clean Code* principles to JavaScript. Covers naming, functions, comments, error handling, and SOLID — the foundation of self-documenting code.

**What it teaches:** The bible of clean code principles adapted for JavaScript/TypeScript. Shows you exactly how to name variables, write functions, and structure code so it's self-documenting.

**Why it's epic:** 90k+ stars. Every senior dev has read this. If your code follows these principles, reviewers will instantly recognize you as a professional.

**Why it's epic:** Shows you how to set up a repo that looks like it was built by a team of 10 senior engineers, not a solo dev.

### 2. [elsewhencode/project-guidelines](https://github.com/elsewhencode/project-guidelines)

A comprehensive set of project guidelines covering Git workflow, project structure, documentation, environment config, and code reviews — everything beyond just writing code.

**What it teaches:** How to structure an entire project—folder organization, naming conventions, README templates, and documentation standards. The difference between a hobby project and a professional codebase.

### 3. [kettanaito/naming-cheatsheet](https://github.com/kettanaito/naming-cheatsheet)

A concise guide to naming variables, functions, classes, and files in any language. The single most underrated skill in programming.

**What it teaches:** The exact rules for naming variables, functions, classes, and files. Covers camelCase vs snake_case, when to use prefixes/suffixes, and how to name things so they're instantly understandable.

**Why it's epic:** Good naming eliminates 80% of the need for comments. This repo teaches you how to write code that explains itself.

### 4. [jrgarciadev/nextjs-docs](https://github.com/jrgarciadev/nextjs-docs) (or any top-tier docs repo)

Study how the best-documented frameworks explain their APIs. The Next.js docs are a gold standard for technical writing.

**What it teaches:** How to write documentation that developers actually read — concise, example-driven, every section has a clear purpose. The same principles apply to code comments.

**Why it's epic:** If your code comments follow the same structure as the Next.js docs, they'll be clear, scannable, and actually helpful.

A comprehensive set of project guidelines covering Git workflow, project structure, documentation, environment config, and code reviews — everything beyond just writing code.

**What it teaches:** How to structure an entire project—folder organization, naming conventions, README templates, and documentation standards. The difference between a hobby project and a professional codebase.

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

## First Impressions: What Recruiters & Senior Devs See

When they open the `xi-kki/code-quality-standards` repo, they'll see:

- **Every function has NatSpec docs** explaining purpose, arguments, returns, errors
- **Inline comments explain WHY, not WHAT** — trade-offs, edge cases, attack vectors
- **Clear naming throughout** — `calculateEscrowExpirationTime()` not `calc()`
- **Consistent structure** — every public function follows the same doc template
- **A production-grade QA script** with more comments than code
- **Architecture diagrams** in the README showing the state machine
- **Architecture diagrams** generated alongside the source
- **Usage examples** for every public function
- **Error codes are documented** with explanations of when each one triggers
- **Security considerations** are called out explicitly
- **Zero magic numbers** — every constant has a named definition and a rationale

This repo isn't just code — it's a **portfolio piece** that proves you understand that code is read far more often than it's written.

**This is the difference between "this person can code" and "this person writes production-grade, maintainable, professional code."**

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
