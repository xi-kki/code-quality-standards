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

**What it teaches:** How to write documentation that actually helps people. Look at how they structure their API docs, write examples, and explain complex concepts.

**Why it's epic:** Study how the best teams document their code, then apply those patterns to your own READMEs and inline comments.

A comprehensive set of project guidelines covering Git workflow, project structure, documentation, environment config, and code reviews — everything beyond just writing code.

**What it teaches:** How to structure an entire project—folder organization, naming conventions, README templates, and documentation standards. The difference between a hobby project and a professional codebase.

This repository contains a framework for writing code that teaches as it runs — a quality assurance system that not only checks your code but explains *why* each check exists, *what* it protects against, and *how* to fix it.

> **Why it's epic:** Study how the best teams document their code, then apply those patterns to your own READMEs and inline comments.

---

## 🏗️ Part 2: Project Structure & Architecture

### 5. [bullet-train-co/bullet-train-ruby-client](https://github.com/bullet-train-co/bullet-train-ruby-client) (or any well-structured SDK)

Study how professional SDKs organize their code — client initialization, error handling, module structure, and documentation patterns.

**What it teaches:** How to structure a professional SDK/library. Look at their folder organization, how they separate concerns, and how they write modular, testable code.

**Why it's epic:** This is how real companies build production SDKs. Study their structure and apply it to your agent-sdk/ folder.

### 6. [vercel/next.js](https://github.com/vercel/next.js/tree/canary/examples) (the `examples/` folder)

The Next.js `examples/` directory is one of the best collections of reference applications you can study. Each example follows the same structure, naming conventions, and documentation pattern.

**What it teaches:** Hundreds of real-world examples of how to structure Next.js apps. Each example shows best practices for routing, data fetching, and component organization.

**Why it's epic:** You can literally copy-paste their folder structures and patterns into your Floe frontend.

### 7. [MystenLabs/sui](https://github.com/MystenLabs/sui/tree/main/crates) (the `crates/` folder)

The official Sui blockchain implementation by Mysten Labs. The `crates/` directory is a masterclass in modular Rust architecture.

**What it teaches:** How the actual Sui team structures their Rust/Move codebase. Look at how they organize modules, write tests, and document their code.

**Why it's epic:** If you're building on Sui, study how the core team writes code. This is the gold standard for Move development.

### 8. [openzeppelin/openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

The industry standard for secure Solidity smart contracts. Every pattern here has been battle-tested across thousands of deployed contracts.

**What it teaches:** The most audited, battle-tested smart contract library in existence. Look at how they write NatSpec comments, structure their contracts, and handle security.

**Why it's epic:** Every line is commented with `/// @notice` and `/// @dev` explaining exactly what it does. This is how you document Move contracts.

---

## 💎 Part 3: Move-Specific Excellence (For Your Sui Contracts)

### 9. [mystenlabs/sui/tree/main/crates/sui-framework](https://github.com/MystenLabs/sui/tree/main/crates/sui-framework)

The official Sui framework — the standard library for Sui Move development. Contains `coin`, `transfer`, `event`, `clock`, `object`, and all core modules.

**What it teaches:** The official Sui framework contracts. Look at how they document every function with `///` comments, explain invariants, and structure their modules.

**Why it's epic:** This is the literal source code of Sui. If your Move contracts follow their documentation style, you're writing at the level of the Sui core team.

### 10. [suilens/public](https://github.com/suilens/public) (or [Cetus](https://github.com/CetusProtocol), [Scallop](https://github.com/scallop-io), [Navi](https://github.com/naviprotocol) — any top Sui DeFi protocol)

Study how leading Sui DeFi protocols structure their Move contracts — real production code with real users and real audits.

**What it teaches:** How production DeFi protocols on Sui structure their Move code. Look at their event emissions, error handling, and access control patterns.

**Why it's epic:** You'll see how real protocols handle the exact problems you're solving in escrow.move.

### 11. [move-language/move](https://github.com/move-language/move/tree/main/language/documentation)

The official Move language documentation and book. The source of truth for Move's syntax, type system, and best practices.

**What it teaches:** How the language designers themselves document Move. The Move Book is the canonical reference for writing clean, idiomatic Move code.

**Why it's epic:** Before you write any Move code, read the Move Book. It will save you weeks of debugging.

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
