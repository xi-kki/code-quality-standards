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
    // ── Guard 1: State validation ──────────────────────────────────────────
    // Why this check exists: Only active escrows can be completed. This
    // invariant prevents double-spending (completing an already-completed
    // escrow) or completing escrows that are under active dispute.
    assert!(escrow.state == STATE_ACTIVE, EINVALID_STATE);

    // ── Guard 2: Amount validation ─────────────────────────────────────────
    // Why this check exists: We must release exactly the amount that was
    // locked when the escrow was created. This prevents partial-release
    // attacks (where someone releases less and keeps the remainder) and
    // over-payment attacks (where someone drains more than deposited).
    assert!(escrow.funds.value == amount, EAMOUNT_MISMATCH);

    // ── Fund transfer ──────────────────────────────────────────────────────
    // Why public_transfer over transfer: The recipient may be an address from
    // a different module or a user account. public_transfer grants direct
    // access to the transferred funds without requiring additional capability
    // checks, which would fail for cross-module recipients.
    transfer::public_transfer(escrow.funds, escrow.recipient);

    // ── State transition ──────────────────────────────────────────────────
    escrow.state = STATE_COMPLETED;

    // ── Event emission ────────────────────────────────────────────────────
    // Why emit an event: Off-chain systems (indexers, UIs, notification
    // services) rely on events to detect state changes. Without this event,
    // the frontend would need to poll the chain, which is expensive and slow.
    event::emit(EscrowCompleted {
        escrow_id: escrow.id,
        recipient: escrow.recipient,
        amount,
        timestamp: clock::now(),
    });
}
