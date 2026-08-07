# Subscription Access SOP

**Confirmed source contract:** 2026-08-02  
**Runtime status:** Active-subscriber launch and force-close/relaunch accepted on Memex `e9ea6d5` and Prime `8f822b7`; reinstall, restore, expiry, refund, and revocation remain separate proof  
**Research:** [Subscription Launch Gating Study](file:///Users/10x/10x-os/50-engineering/2026-08-02%20-%20Subscription%20Launch%20Gating%20Study/Subscription%20Launch%20Gating%20Study.md)

## The standard

Use one purchase owner, one access decision, and eligibility-aware offer copy.

For portfolio apps already using RevenueCat:

- RevenueCat purchases, validates, finishes transactions, and owns normal access through `CustomerInfo`.
- StoreKit 2 may provide privacy-safe diagnostics. It must not silently become a second authority that cancels RevenueCat access.
- A verified StoreKit entitlement may be added later as a positive fallback only through one atomic, tested reconciliation rule. An empty StoreKit result never disproves active RevenueCat access.

If an app owns StoreKit 2 purchases itself, configure RevenueCat for app-completed purchases and implement verification, delivery, `Transaction.updates`, and `finish()` in the app. Never let both layers believe they finish the same transaction.

## Non-negotiable access rule

Open immediately only from previously verified active evidence. Keep an unknown install gated. Preserve a known decision through transport failure. Replace it only with a successful, newer entitlement result.

Do not persist a second `hasPaid` Boolean. It cannot reliably represent expiry, revocation, identity changes, or offline freshness.

## Root state machine

```text
onboarding not complete → onboarding

onboarding complete + cached active → app immediately + background refresh
onboarding complete + cached inactive + no fallback → paywall immediately + background refresh
onboarding complete + cached inactive + StoreKit fallback unresolved → checking
onboarding complete + saved verified StoreKit active → app immediately + background refresh
onboarding complete + no cache → checking

checking + active response → app
checking + inactive response → paywall
checking + budget exceeded or request failed → retry + restore recovery

known state + request error → preserve known state
known state + successful newer entitlement → apply it atomically
active result while offer is visible → finish the access step automatically
```

Use explicit root meanings: `checking`, `unlocked`, `locked`, `unavailable`, and `notConfigured`. Trial, active, free, and expired are subscription details, not competing root Booleans.

## RevenueCat launch contract

1. Configure RevenueCat once before SwiftUI creates the root access surface.
2. Declare identity mode as `anonymous` or `accountLinked`.
3. Subscribe to one `CustomerInfo` update mechanism.
4. Read `cachedCustomerInfo` synchronously and render from it.
5. Start ordinary `customerInfo()` refresh, offerings loading, and eligibility loading independently.
6. Refresh on foreground using normal cached-or-fetched behavior.
7. Do not routinely invalidate the cache or force a network-only fetch.
8. Prevent a refresh started before purchase or restore from overwriting the newer result.
9. Order successful snapshots by `CustomerInfo.requestDate`. RevenueCat's stream starts by replaying its last known value; a duplicate or older snapshot must not advance the revision or suppress a newer in-flight refresh.

Five RevenueCat inputs may update access:

| Input | Rule |
|---|---|
| Cached first-frame snapshot | Apply synchronously. |
| Ordinary current refresh | Apply only if still current; preserve known state on failure. |
| CustomerInfo stream | Apply it directly only when newer; do not fetch again inside the callback or advance the revision for the replayed cached value. |
| Purchase response | Invalidate older refreshes and unlock only when the required entitlement is active. |
| Restore response | Invalidate older refreshes and report active, no active purchase, or failure accurately. |

Offerings availability never decides access. A missing product can disable purchase while an existing subscriber remains unlocked.

## Positive StoreKit reconciliation

Use this only when an existing Apple subscriber can be absent from RevenueCat's
current anonymous customer record. RevenueCat still owns purchases and finishes
transactions. StoreKit only adds verified positive access.

1. Scan one verified mapped `Transaction.currentEntitlements` sequence.
2. Compute effective access atomically as `RevenueCat active OR StoreKit active`.
3. Keep RevenueCat inactive plus StoreKit unresolved on Checking. If the display budget expires, show Retry and Restore—not the paywall.
4. Coalesce launch, foreground, paywall, and transaction-update scans. Never replace an in-flight scan's operation number and then ignore its result.
5. Save only mapped product ID, expiration, and verification time from verified positive evidence. Keep it at most 24 hours and never beyond the known expiration.
6. Open a cold launch immediately from that saved evidence, then reverify both providers in the background.
7. Clear the saved Apple evidence only after a completed verified scan finds no mapped active transaction. Preserve it through unverified or interrupted scans.
8. An empty StoreKit scan may remove StoreKit-derived access but cannot veto active RevenueCat access.

The first launch after adding this reconciler may briefly show Checking because
no saved Apple evidence exists. It must never show the paywall before StoreKit
finishes. After verification is saved, force-close/relaunch must open the app on
the first frame.

## Identity, relaunch, and reinstall

Treat these as different cases:

- **Relaunch or app update:** RevenueCat's anonymous ID and `CustomerInfo` cache persist. A known subscriber should not see a paywall flash.
- **Delete and reinstall:** RevenueCat removes the cached anonymous ID and creates a new one.
- **Account-linked app:** Configure or log in with the stable backend user ID before showing paid UI.
- **No-account app:** Anonymous identity is valid, but Restore Purchases must be visible and RevenueCat restore behavior must allow the Apple purchase to move to the new anonymous user.

Do not invent a device account with a hard-coded ID, email, advertising identifier, or shared UUID. Do not log the raw RevenueCat App User ID.

## Purchase, restore, and sync

- Apply the `CustomerInfo` returned from purchase immediately.
- Cancellation, pending approval, and failure do not change access.
- Do not dismiss a hard paywall until the required entitlement is active.
- `restorePurchases()` is an explicit customer action because it may prompt for Apple credentials.
- Do not call RevenueCat restore and `AppStore.sync()` as two separate restore owners.
- `syncPurchases()` is a non-prompting migration or repair tool that may transfer or alias anonymous users. It is not an ordinary launch refresh and must not run every launch.
- `AppStore.sync()` is for an explicit customer restore action in rare StoreKit cases, not background startup work.

## Trial and offer copy

Trial eligibility is merchandising state, never access state.

| Eligibility | Customer copy |
|---|---|
| Eligible | “Start 7-Day Free Trial” and the live post-trial price and period. |
| Ineligible or no offer | “Subscribe” and the live price and period. |
| Unknown | Neutral purchase copy: Apple will confirm any trial and final terms before purchase. |

RevenueCat's eligibility result is best effort. Apple's payment sheet is final. Do not put unconditional trial language in a headline, eyebrow, onboarding card, button identifier, or renewal terms.

## Required diagnostics

Each app must record one privacy-safe timeline that explains every access decision. Use unified logging for support diagnostics and product analytics only for aggregate, low-cardinality events.

Record:

- trigger: cache, launch refresh, foreground, stream, purchase, restore, or retry;
- operation or revision number;
- identity mode: anonymous or account-linked, never the raw ID;
- cache present or absent;
- CustomerInfo request age;
- required entitlement present, active, period type, environment, and verification result;
- previous and next root access state;
- request duration;
- offering and exact package/product mapping result;
- trial eligibility outcome;
- optional StoreKit diagnostic: positive entitlement found, no positive entitlement, or diagnostic error;
- safe error domain and code.

Never log API keys, receipts, JWS payloads, transaction IDs, Apple account details, raw App User IDs, or complete `CustomerInfo` objects.

For physical-device diagnosis, Debug builds should also retain a bounded local
timeline that survives process exit. The portfolio reference is a 256 KB
`Library/Application Support/subscription-diagnostics.ndjson` file containing
only the privacy-safe fields above.

## Required deterministic tests

- Cached active starts unlocked.
- Cached inactive starts locked.
- No cache starts checking and becomes recoverable on failure.
- Refresh failure preserves active and locked decisions.
- Confirmed expiry or revocation locks access.
- Purchase active unlocks; inactive, canceled, pending, and error do not.
- Restore distinguishes active, none found, and error.
- A stale launch refresh cannot overwrite purchase or restore.
- A stream event is applied without a nested fetch.
- The stream's replayed cached value cannot suppress a newer launch refresh.
- Empty StoreKit diagnostics cannot revoke RevenueCat active access.
- RevenueCat inactive plus StoreKit unresolved cannot present the paywall.
- Verified StoreKit active can unlock an inactive RevenueCat record.
- A cached verified StoreKit active result opens the first frame while refresh runs.
- Duplicate launch and foreground StoreKit scans coalesce instead of invalidating each other.
- Active access resolving while a persisted onboarding offer is visible finishes the access step.
- Eligible, ineligible, no-offer, and unknown states render accurate copy.

## Runtime proof ladder

1. **Compile:** app target and focused tests build. This proves source compatibility only.
2. **Local StoreKit:** deterministic purchase, pending, cancellation, renewal, expiry, billing retry, grace, revocation, restore, and offline scenarios.
3. **RevenueCat Test Store:** offering, package, entitlement, purchase, restore, stream, and diagnostics without Apple sandbox variability.
4. **Physical Apple sandbox or TestFlight:** purchase, immediate unlock, force-close/relaunch, reinstall/restore, offline relaunch, renewal, expiry, refund or revocation, and trial eligibility.
5. **Production monitoring:** real paid-customer access time, unavailable checks, restore outcomes, and unexpected paywall returns.

Build, install, local StoreKit, sandbox, TestFlight, and production observations are separate evidence. Call only the named case accepted for the exact candidate and environment exercised; do not generalize active-subscriber relaunch proof to reinstall, restore, expiry, refund, revocation, or a fresh purchase.
