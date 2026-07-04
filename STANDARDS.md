---
title: Code Quality Standards
description: Self-documenting code as a first-class skill — a 5-layer framework
---

# Code Quality Standards

> *"The code itself is the documentation."*

When writing code, you must:

---

## Table of Contents

1. [Self-Documenting Code](#1-self-documenting-code)
2. [Strategic Comments (Not Redundant Ones)](#2-strategic-comments-not-redundant-ones)
3. [Function Documentation (NatSpec Style)](#3-function-documentation-natspec-style)
4. [Inline Explanations for Complex Logic](#4-inline-explanations-for-complex-logic)
5. [Auto-Generate Documentation](#5-auto-generate-documentation)
6. [Example: `complete_escrow`](#example-complete_escrow)

---

### 1. Self-Documenting Code

The code itself should tell the story. No novel-length comments needed when the code reads cleanly.

| Rule | Bad | Good |
|------|-----|------|
| Descriptive variable names | `bal` | `userEscrowBalance` |
| Descriptive function names | `calc()` | `calculateEscrowExpirationTime()` |
| Single responsibility | A function that validates + transfers + emails | One function = one job |
| Early returns | Deeply nested `if/else` chains | Return early, reduce nesting |

```move
// BAD — what does this mean?
let b = bal - fee;

// GOOD — reads like a sentence
let payout_amount = escrow_balance - platform_fee;
```

---

### 2. Strategic Comments (Not Redundant Ones)

Comments should explain **why**, not **what**. The code already says *what* it does.

| ❌ Redundant | ✅ Strategic |
|-------------|-------------|
| `// Check if balance is sufficient` | `// We use a 7-day timeout because freelancers need time to dispute` |
| `// Increment counter` | `// Subjective quality issues, but 7 days prevents indefinite fund locks` |

**Good example:**

```move
// We use a 7-day timeout because freelancers need time to dispute
// subjective quality issues, but 7 days prevents indefinite fund locks
const ESCROW_TIMEOUT_DAYS: u64 = 7;
```

The comment captures the **tension**: subjective quality disputes vs. the risk of indefinite fund locks. That's a design decision that isn't visible in the code itself.

---

### 3. Function Documentation (NatSpec Style)

Every public function must have structured doc comments. Following the **Purpose → Arguments → Returns → Side Effects → Errors → Example → Security** format.

```move
/// # Function Name
/// Brief explanation of what this function does.
///
/// ## Arguments
/// * `param_name` - What this parameter is for
///
/// ## Returns
/// What this function returns
///
/// ## Side Effects
/// What state changes occur
///
/// ## Errors
/// When and why this function might fail
///
/// ## Example
/// ```move
/// // Code example showing usage
/// ```
///
/// ## Security
/// Security considerations and assumptions
pub fun my_function(param: Type) -> ReturnType { ... }
```

This mirrors **NatSpec** (Solidity) conventions and Rust doc conventions, adapted for Move.

---

### 4. Inline Explanations for Complex Logic

For any non-obvious logic, add a comment explaining:

- **Why this approach** was chosen over alternatives
- **What edge cases** are being handled
- **What invariants** must be maintained

```move
// Verify state: Only active escrows can be completed
// This prevents double-spending or completing disputed escrows
assert!(escrow.state == STATE_ACTIVE, EINVALID_STATE);
```

The pattern: **What** is being verified → **Why** it matters → **Which attack** it prevents.

---

### 5. Auto-Generate Documentation

After writing code, automatically generate:

- **README section** explaining the module
- **Architecture diagrams** using Mermaid syntax
- **Usage examples** extracted from doc comments
- **API reference** from structured function docs

This ensures documentation never goes stale — it's generated from the code itself.

---

### Example: `complete_escrow`

The following function demonstrates **all five layers** working together in a single function:

```move
/// # Complete Escrow
/// Transitions an escrow from `Active` to `Completed` state and releases funds.
///
/// ## Arguments
/// * `escrow` - Mutable reference to the escrow object
/// * `amount` - The amount to release (must match escrow.funds)
///
/// ## Side Effects
/// - Transfers funds to the recipient
/// - Emits `EscrowCompleted` event
/// - Changes state from `Active` to `Completed`
///
/// ## Errors
/// - Panics if escrow is not in `Active` state
/// - Panics if amount doesn't match escrow balance
///
/// ## Security
/// Uses `transfer::public_transfer` to prevent reentrancy attacks.
pub fun complete_escrow(
    escrow: &mut Escrow,
    amount: u64,
) {
    // ── Guard 1: State validation ──────────────────────────────────
    // Only active escrows can be completed. This prevents
    // double-spending or completing escrows that are in dispute.
    assert!(escrow.state == STATE_ACTIVE, EINVALID_STATE);

    // ── Guard 2: Amount validation ─────────────────────────────────
    // We must release exactly the amount locked. This prevents
    // partial releases or over-payment attacks.
    assert!(escrow.funds.value == amount, EAMOUNT_MISMATCH);

    // ── Fund transfer ──────────────────────────────────────────────
    // Using public_transfer (not transfer) because the recipient
    // may be a different module or user who needs direct access
    // to the transferred funds.
    transfer::public_transfer(escrow.funds, escrow.recipient);

    // ── State transition & event emission ───────────────────────────
    escrow.state = STATE_COMPLETED;

    event::emit(EscrowCompleted {
        escrow_id: escrow.id,
        recipient: escrow.recipient,
        amount,
        timestamp: clock::now(),
    });
}
```

**Layer map:**
| Layer | Evidence in function |
|-------|---------------------|
| **1. Self-documenting code** | `complete_escrow`, `escrow`, `amount`, `EAMOUNT_MISMATCH` — names are clear |
| **2. Strategic comments** | "prevents double-spending", "prevents partial releases" — *why*, not *what* |
| **3. Function documentation** | Full doc block: Purpose, Arguments, Side Effects, Errors, Security |
| **4. Inline explanations** | Each guard has a two-line comment: what + why |
| **5. Auto-generate docs** | Structured format supports doc extraction and README generation |
