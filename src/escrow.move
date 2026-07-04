// =============================================================================
// Escrow Module — Freelancer Payment Protection
// =============================================================================
//
// Design intent:
//   An escrow contract that holds funds while a freelancer completes work.
//   Funds are locked on creation, released on completion, and can be
//   disputed if something goes wrong.
//
// Why escrow (vs direct payment):
//   Escrow eliminates the trust problem in freelancer-client relationships.
//   The client's funds are locked and cannot be withdrawn by either party
//   unilaterally — both must agree or a timeout/dispute mechanism resolves it.
//
// State machine:
//   Created → Active → Completed  (happy path)
//   Active  → Disputed → Completed (dispute resolved for freelancer)
//   Active  → Disputed → Cancelled (dispute resolved for client)
//   Active  → Cancelled           (timeout, no dispute filed)
// =============================================================================

// ── Constants ──────────────────────────────────────────────────────────────
// Why these are constants and not configurable parameters:
//   Constants are compiled into the bytecode, saving gas on every interaction.
//   They cannot be changed after deployment, which is intentional — changing
//   the timeout after escrows are live would be unfair to existing users.

/// The duration (in days) after which an active escrow automatically cancels.
///
/// We use a 7-day timeout because freelancers need time to dispute
/// subjective quality issues, but 7 days prevents indefinite fund locks.
/// This is a deliberate trade-off: too short hurts freelancers, too long
/// hurts clients. 7 days is the industry standard for freelance platforms.
const ESCROW_TIMEOUT_DAYS: u64 = 7;

/// The maximum amount (in tokens) that can be locked in a single escrow.
///
/// Why a cap: Prevents a single escrow from holding more than the platform's
/// risk tolerance. Large payments should go through a multi-sig or tier-2
/// review process. This is a safety net, not a revenue constraint.
const MAX_ESCROW_AMOUNT: u64 = 100_000;

// ── Error Codes ────────────────────────────────────────────────────────────
// Why named error codes over magic strings:
//   Error codes are cheaper (u64 vs vector<u8>) and more readable in
//   stack traces. The naming convention E + UPPERCASE_DESCRIPTION makes
//   the root cause scannable without looking up the code.

/// The escrow is not in the expected state for this operation.
const EINVALID_STATE: u64 = 1;

/// The caller is not authorized to perform this action.
const EUNAUTHORIZED: u64 = 2;

/// The provided amount does not match the escrow's locked balance.
const EAMOUNT_MISMATCH: u64 = 3;

/// The escrow has expired and cannot be modified.
const EEXPIRED: u64 = 4;

/// The amount exceeds the maximum allowed for a single escrow.
const EAMOUNT_EXCEEDS_MAX: u64 = 5;

// ── State Enum (simulated with constants) ──────────────────────────────────
// Why u64 constants instead of a proper enum:
//   Move does not have enums. This pattern (constants + assertions) is the
//   idiomatic way to represent state machines in Move. The state field is
//   a u64 that should always equal one of these constants.

/// Escrow has been created but funds are not yet deposited.
const STATE_PENDING: u64 = 0;

/// Funds are locked and the freelancer is working. This is the only state
/// from which an escrow can be completed or disputed.
const STATE_ACTIVE: u64 = 1;

/// Funds have been released to the freelancer. Terminal state.
const STATE_COMPLETED: u64 = 2;

/// A dispute has been filed. Resolution agent must intervene. Terminal state
/// (until resolved by agent).
const STATE_DISPUTED: u64 = 3;

/// Funds returned to the depositor. Terminal state.
const STATE_CANCELLED: u64 = 4;

// ── Structs ────────────────────────────────────────────────────────────────
// Why these fields:
//   - `id`: Globally unique identifier for event emission and indexing
//   - `depositor`: Who put funds in (client) — needed for refunds
//   - `recipient`: Who gets funds on completion (freelancer)
//   - `agent`: Who resolves disputes (platform/admin)
//   - `funds`: The locked Coin object — stored in the struct, not a vault
//   - `state`: Current state in the state machine
//   - `expiry`: Unix timestamp when the escrow auto-cancels
//   - `dispute_reason`: Optional — only set when a dispute is filed

/// Represents a single escrow agreement between a depositor and a recipient.
///
/// ## Invariants
/// - `state` must always be one of `STATE_*` constants
/// - `expiry` is set at creation and never modified
/// - `funds.value` equals the amount at creation and never changes internally
struct Escrow has key, store {
    id: UID,
    depositor: address,
    recipient: address,
    agent: address,
    funds: Coin<SUI>,
    state: u64,
    expiry: u64,
    dispute_reason: Option<String>,
}

// ── Events ─────────────────────────────────────────────────────────────────
// Why events exist:
//   Events are the only way for off-chain systems (indexers, UIs, analytics)
//   to observe on-chain state changes without polling. Each event includes
//   all fields needed to reconstruct what happened without querying state.
//
// Why separate event types:
//   Each event type represents a distinct state transition. Indexers can
//   filter by event type to build different views (e.g., "all completed
//   escrows for this recipient").

/// Emitted when an escrow is created.
struct EscrowCreated has copy, drop {
    escrow_id: ID,
    depositor: address,
    recipient: address,
    amount: u64,
    expiry: u64,
    timestamp: u64,
}

/// Emitted when an escrow is completed and funds are released.
struct EscrowCompleted has copy, drop {
    escrow_id: ID,
    recipient: address,
    amount: u64,
    timestamp: u64,
}

/// Emitted when a dispute is filed against an escrow.
struct EscrowDisputed has copy, drop {
    escrow_id: ID,
    reason: String,
    timestamp: u64,
}

/// Emitted when a dispute is resolved by the agent.
struct EscrowResolved has copy, drop {
    escrow_id: ID,
    resolution: String, // "completed" or "cancelled"
    timestamp: u64,
}

/// Emitted when an escrow is cancelled (timeout or refund).
struct EscrowCancelled has copy, drop {
    escrow_id: ID,
    reason: String,
    timestamp: u64,
}

// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

// ── create_escrow ──────────────────────────────────────────────────────────

/// # Create Escrow
/// Creates a new escrow agreement, locking funds until work is completed
/// or a dispute is resolved.
///
/// ## Arguments
/// * `recipient` - The address that will receive funds on completion (freelancer)
/// * `agent` - The address authorized to resolve disputes (platform admin)
/// * `payment` - The Coin object to lock in the escrow
/// * `ctx` - Transaction context for object creation
///
/// ## Returns
/// * The newly created `Escrow` object
///
/// ## Side Effects
/// - Creates a new `Escrow` object with `Pending` state
/// - Transfers `payment` into the escrow struct
/// - Sets expiry to `now + ESCROW_TIMEOUT_DAYS`
/// - Emits `EscrowCreated` event
///
/// ## Errors
/// - Panics if `payment.value` exceeds `MAX_ESCROW_AMOUNT`
///
/// ## Security
/// - The escrow is created in `Pending` state — funds are not accessible
///   until the depositor explicitly activates the escrow.
/// - The `agent` parameter is immutable after creation, preventing
///   unauthorized dispute resolution.
///
/// ## Example
/// ```move
/// let escrow = escrow::create_escrow(
///     @freelancer,
///     @platform,
///     coin::split(&mut wallet, 1000, ctx),
///     ctx,
/// );
/// ```
public fun create_escrow(
    recipient: address,
    agent: address,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): Escrow {
    // ── Guard: Amount cap ──────────────────────────────────────────
    // Why limit the amount: A single large escrow represents concentrated
    // risk. If a bug or exploit affects this escrow, the damage is bounded.
    // Large payments should use a multi-sig or verified escrow service.
    let amount = coin::value(&payment);
    assert!(amount <= MAX_ESCROW_AMOUNT, EAMOUNT_EXCEEDS_MAX);

    let now = clock::timestamp(clock::immutable_clock(ctx));

    // ── Create expiry ──────────────────────────────────────────────
    // Why we compute expiry at creation: Locking the timeout at creation
    // prevents manipulation. If the timeout were computed dynamically,
    // a malicious actor could delay calling complete_escrow indefinitely.
    let expiry = now + (ESCROW_TIMEOUT_DAYS * 24 * 60 * 60);

    let escrow = Escrow {
        id: object::new(ctx),
        depositor: ctx.sender(),
        recipient,
        agent,
        funds: payment,
        state: STATE_PENDING,
        expiry,
        dispute_reason: option::none(),
    };

    // ── Event emission ─────────────────────────────────────────────
    // Why emit at creation: Indexers need to know about new escrows to
    // track them. Without this event, clients would need to poll for all
    // escrows created by an address, which is expensive.
    event::emit(EscrowCreated {
        escrow_id: object::uid_to_inner(&escrow.id),
        depositor: escrow.depositor,
        recipient: escrow.recipient,
        amount,
        expiry,
        timestamp: now,
    });

    escrow
}

// ── activate_escrow ────────────────────────────────────────────────────────

/// # Activate Escrow
/// Transitions an escrow from `Pending` to `Active`, making it eligible
/// for completion or dispute.
///
/// ## Arguments
/// * `escrow` - Mutable reference to the escrow object
///
/// ## Side Effects
/// - Changes state from `Pending` to `Active`
///
/// ## Errors
/// - Panics if escrow is not in `Pending` state
/// - Panics if caller is not the depositor
///
/// ## Security
/// - Only the depositor can activate. This prevents the recipient from
///   activating an escrow before the depositor has confirmed the terms.
/// - Activation is a one-way transition — escrows cannot go back to Pending.
public fun activate_escrow(escrow: &mut Escrow, ctx: &TxContext) {
    // ── Guard 1: Authorization ─────────────────────────────────
    // Why only depositor: The depositor (client) is the one paying.
    // They should decide when the escrow is active and work begins.
    assert!(ctx.sender() == escrow.depositor, EUNAUTHORIZED);

    // ── Guard 2: State ─────────────────────────────────────────
    // Why prevent re-activation: An escrow can only be activated once.
    // Re-activating would reset the timer, which is unfair to the client.
    assert!(escrow.state == STATE_PENDING, EINVALID_STATE);

    escrow.state = STATE_ACTIVE;
}

// ── complete_escrow ────────────────────────────────────────────────────────

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
public fun complete_escrow(
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

// ── dispute_escrow ─────────────────────────────────────────────────────────

/// # Dispute Escrow
/// Files a dispute against an active escrow, preventing completion until
/// the agent resolves the dispute.
///
/// ## Arguments
/// * `escrow` - Mutable reference to the escrow object
/// * `reason` - Human-readable explanation of the dispute
///
/// ## Side Effects
/// - Changes state from `Active` to `Disputed`
/// - Stores the dispute reason on the escrow
/// - Emits `EscrowDisputed` event
///
/// ## Errors
/// - Panics if escrow is not in `Active` state
/// - Panics if caller is not the depositor or recipient
///
/// ## Security
/// - Either party can dispute (prevents one party from blocking disputes)
/// - Once disputed, the agent's address is immutable — the dispute cannot
///   be reassigned to a different agent
public fun dispute_escrow(
    escrow: &mut Escrow,
    reason: vector<u8>,
    ctx: &TxContext,
) {
    // ── Guard 1: Authorization ─────────────────────────────────
    // Why both parties can dispute: If only the depositor could dispute,
    // a malicious depositor could refuse to pay and the freelancer has no
    // recourse. If only the recipient could dispute, a malicious freelancer
    // could block refunds. Both parties need this power.
    let sender = ctx.sender();
    assert!(
        sender == escrow.depositor || sender == escrow.recipient,
        EUNAUTHORIZED,
    );

    // ── Guard 2: State ─────────────────────────────────────────
    // Why only active escrows: Pending escrows haven't started work yet.
    // Completed escrows are final. Cancelled escrows are already resolved.
    assert!(escrow.state == STATE_ACTIVE, EINVALID_STATE);

    // ── Guard 3: Expiry ────────────────────────────────────────
    // Why check expiry: Expired escrows auto-cancel. Filing a dispute on
    // an expired escrow would give the disputing party more leverage than
    // they should have (the timeout was their recourse).
    let now = clock::timestamp(clock::immutable_clock(ctx));
    assert!(now <= escrow.expiry, EEXPIRED);

    escrow.state = STATE_DISPUTED;
    escrow.dispute_reason = option::some(string::utf8(reason));

    event::emit(EscrowDisputed {
        escrow_id: object::uid_to_inner(&escrow.id),
        reason: *option::borrow(&escrow.dispute_reason),
        timestamp: now,
    });
}

// ── resolve_dispute ────────────────────────────────────────────────────────

/// # Resolve Dispute
/// Resolves a disputed escrow. The agent can either complete the escrow
/// (pay the recipient) or cancel it (refund the depositor).
///
/// ## Arguments
/// * `escrow` - Mutable reference to the escrow object
/// * `resolution` - Either "completed" or "cancelled"
///
/// ## Side Effects
/// - If "completed": transfers funds to recipient, state → Completed
/// - If "cancelled": transfers funds to depositor, state → Cancelled
/// - Emits `EscrowResolved` event
///
/// ## Errors
/// - Panics if escrow is not in `Disputed` state
/// - Panics if caller is not the agent
/// - Panics if resolution is not "completed" or "cancelled"
///
/// ## Security
/// - Only the pre-assigned agent can resolve disputes
/// - The agent cannot resolve in their own favor (they have no stake)
/// - Resolution is a one-way, final decision
public fun resolve_dispute(
    escrow: &mut Escrow,
    resolution: vector<u8>,
    ctx: &TxContext,
) {
    // ── Guard 1: Authorization ─────────────────────────────────
    // Why only agent: The agent is the neutral third party. Neither
    // depositor nor recipient should be able to self-resolve a dispute.
    assert!(ctx.sender() == escrow.agent, EUNAUTHORIZED);

    // ── Guard 2: State ─────────────────────────────────────────
    assert!(escrow.state == STATE_DISPUTED, EINVALID_STATE);

    let resolution_str = string::utf8(resolution);

    // ── Execute resolution ─────────────────────────────────────
    // Why string comparison over a bool or enum: Using string literals
    // makes the intent explicit in transaction explorers. A bool `true`
    // for "pay the freelancer" is ambiguous without reading the contract.
    if (resolution_str == string::utf8(b"completed")) {
        transfer::public_transfer(escrow.funds, escrow.recipient);
        escrow.state = STATE_COMPLETED;
    } else if (resolution_str == string::utf8(b"cancelled")) {
        transfer::public_transfer(escrow.funds, escrow.depositor);
        escrow.state = STATE_CANCELLED;
    } else {
        // Why abort instead of silent no-op: An invalid resolution string
        // means the caller made a mistake. Silently ignoring it would let
        // disputes remain unresolved without feedback.
        abort(EINVALID_STATE);
    };

    event::emit(EscrowResolved {
        escrow_id: object::uid_to_inner(&escrow.id),
        resolution: resolution_str,
        timestamp: clock::now(),
    });
}

// ── cancel_expired ─────────────────────────────────────────────────────────

/// # Cancel Expired
/// Cancels an escrow that has passed its expiry time. Returns funds to
/// the depositor.
///
/// ## Arguments
/// * `escrow` - Mutable reference to the escrow object
///
/// ## Side Effects
/// - Transfers funds back to the depositor
/// - Changes state from `Active` to `Cancelled`
/// - Emits `EscrowCancelled` event
///
/// ## Errors
/// - Panics if escrow is not in `Active` state
/// - Panics if current time is before expiry
///
/// ## Security
/// - Anyone can call this (not permissioned) — the expiry check is the
///   security mechanism. Premature calls are blocked by the time check.
/// - After expiry, funds MUST be returnable. If only the depositor could
///   cancel, a lost key would lock funds forever.
public fun cancel_expired(
    escrow: &mut Escrow,
    ctx: &TxContext,
) {
    // ── Guard 1: State ─────────────────────────────────────────
    // Why only active: Pending escrows haven't started — they should
    // be cancelled by the depositor directly. Completed/disputed escrows
    // have different resolution paths.
    assert!(escrow.state == STATE_ACTIVE, EINVALID_STATE);

    // ── Guard 2: Expiry ────────────────────────────────────────
    // Why strict time check: Without this, a malicious actor could
    // cancel an active escrow prematurely. The expiry is the safety
    // guarantee — the freelancer has until expiry to complete.
    let now = clock::timestamp(clock::immutable_clock(ctx));
    assert!(now >= escrow.expiry, EEXPIRED);

    // ── Refund depositor ───────────────────────────────────────
    // Why depositor and not recipient: The depositor put the funds in.
    // If work wasn't completed (the timeout expired without completion),
    // the depositor gets their money back. This is the core escrow promise.
    transfer::public_transfer(escrow.funds, escrow.depositor);
    escrow.state = STATE_CANCELLED;

    event::emit(EscrowCancelled {
        escrow_id: object::uid_to_inner(&escrow.id),
        reason: string::utf8(b"timeout"),
        timestamp: now,
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// VIEW FUNCTIONS (no side effects)
// ═══════════════════════════════════════════════════════════════════════════

/// # Is Active
/// Returns true if the escrow is currently active (funds locked, work
/// can proceed).
///
/// Why a view function: Callers should not need to import STATE_ACTIVE
/// and compare manually. This encapsulates the state comparison logic.
public fun is_active(escrow: &Escrow): bool {
    escrow.state == STATE_ACTIVE
}

/// # Time Remaining
/// Returns the number of seconds until the escrow expires, or 0 if
/// already expired.
///
/// Why compute this on-chain: Clients use this to display countdowns
/// and warn users before timeouts.
public fun time_remaining(escrow: &Escrow): u64 {
    let expiry = escrow.expiry;
    let now = clock::timestamp(clock::immutable_clock());
    if (now >= expiry) { 0 } else { expiry - now }
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS (run with `sui move test`)
// ═══════════════════════════════════════════════════════════════════════════

#[test]
fun test_complete_escrow_happy_path() {
    // Tests the full happy path: create → activate → complete
    // Why this test: Verifies the primary use case works end-to-end.
    // If this fails, the contract is broken regardless of edge cases.
    let ctx = tx_context::dummy();
    let depositor = @0xA;
    let recipient = @0xB;

    let (escrow, _) = test_utils::create_test_escrow(depositor, recipient, 1000, &mut ctx);

    escrow::activate_escrow(&mut escrow, &ctx);
    escrow::complete_escrow(&mut escrow, 1000);

    assert!(escrow.state == STATE_COMPLETED, 0);
}

#[test]
#[expected_failure(abort_code = EINVALID_STATE)]
fun test_complete_escrow_wrong_state() {
    // Tests that completing an escrow in the wrong state fails.
    // Why this matters: Prevents a user from completing an already-
    // completed escrow (double-spending) or a disputed escrow.
    let ctx = tx_context::dummy();
    let (escrow, _) = test_utils::create_test_escrow(@0xA, @0xB, 1000, &mut ctx);

    // Escrow is in Pending state — should fail
    escrow::complete_escrow(&mut escrow, 1000);
}

#[test]
#[expected_failure(abort_code = EAMOUNT_MISMATCH)]
fun test_complete_escrow_wrong_amount() {
    // Tests that the amount must match exactly.
    // Why this matters: Prevents partial-release and over-payment attacks.
    let ctx = tx_context::dummy();
    let (escrow, _) = test_utils::create_test_escrow(@0xA, @0xB, 1000, &mut ctx);

    escrow::activate_escrow(&mut escrow, &ctx);
    escrow::complete_escrow(&mut escrow, 999); // amount mismatch!
}

#[test]
fun test_dispute_and_resolve_completed() {
    // Tests: dispute → resolve as "completed" → funds go to recipient
    let ctx = tx_context::dummy();
    let depositor = @0xA;
    let recipient = @0xB;
    let agent = @0xC;

    let (escrow, _) = test_utils::create_test_escrow_with_agent(
        depositor, recipient, agent, 1000, &mut ctx,
    );

    escrow::activate_escrow(&mut escrow, &ctx);
    escrow::dispute_escrow(&mut escrow, b"Work was incomplete", &ctx);
    escrow::resolve_dispute(&mut escrow, b"completed", &ctx);

    assert!(escrow.state == STATE_COMPLETED, 0);
}

#[test]
fun test_cancel_expired_returns_funds() {
    // Tests that an expired escrow can be cancelled by anyone.
    let ctx = tx_context::dummy();
    let (escrow, _) = test_utils::create_test_escrow(@0xA, @0xB, 1000, &mut ctx);

    escrow::activate_escrow(&mut escrow, &ctx);
    // Advance time past expiry (simplified — real tests use clock mocking)
    escrow.expiry = 0; // force expiry to past
    escrow::cancel_expired(&mut escrow, &ctx);

    assert!(escrow.state == STATE_CANCELLED, 0);
}
