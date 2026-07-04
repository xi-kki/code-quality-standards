# Escrow Module — Usage Guide

## Creating an Escrow

```move
let escrow = escrow::create_escrow(
    buyer: @alice,
    seller: @bob,
    amount: 1000,
    agent: @platform,
);
```

## Completing an Escrow

```move
escrow::complete_escrow(
    escrow: &mut escrow_obj,
    amount: 1000,
);
```

## Disputing an Escrow

```move
escrow::dispute_escrow(
    escrow: &mut escrow_obj,
    reason: b"Work was not delivered",
);
```

## State Reference

| State | Can Complete? | Can Dispute? | Can Refund? | Auto-Cancels? |
|-------|:------------:|:------------:|:-----------:|:-------------:|
| `Active` | ✅ | ✅ | ❌ | After 7 days |
| `Disputed` | ❌ | ❌ | ❌ | ❌ |
| `Completed` | ❌ | ❌ | ❌ | ❌ |
| `Cancelled` | ❌ | ❌ | ❌ | ❌ |
