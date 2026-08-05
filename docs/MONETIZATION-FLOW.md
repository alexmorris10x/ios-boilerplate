# Monetization Flow Runbook

Use this runbook when wiring purchases in apps created from this boilerplate.
`PaywallService` keeps the feature boundary small, while the compiled
`RevenueCatPaywallProvider` is the reference purchase owner.

## Customer-Facing Flow

- Free users should see a clear primary purchase action, for example `Unlock Pro`.
- Purchased users should see a calm account-style state, for example `Plan: Pro`
  and `Access: Lifetime Access` or `Access: Active`.
- `Restore Purchases` should remain available from Settings even after purchase.
- Avoid showing developer test controls, test product names, or test prices in the
  live purchase section.
- Keep failure messages actionable but short. Log full provider errors in the
  debug console or nonfatal logging, not as long user-facing text.

## RevenueCat Shape

- Create one RevenueCat project for this production app and bundle ID. Do not attach a derived app to a shared portfolio project unless cross-app customer identity or entitlements are an explicit product decision.
- RevenueCat customers, charts, and lifetime-value history are project-scoped. App filters inside a shared project do not create independent analytics.
- Use a public SDK key in the app only. Never commit secret API keys.
- Retrieve the Apple public SDK key from `Apps` -> the matching App Store app -> `Public API Key` -> `Show key`. The project-level `API keys` page contains secret management keys and is not the app-key source.
- Replace every value in `AppConstants.Subscription`, then verify the complete
  product -> entitlement -> offering/package chain in RevenueCat.
- Treat RevenueCat entitlements as the app's paid-access source of truth.
- Let RevenueCat process and finish purchases. Do not independently finish the
  same transactions in StoreKit.
- Offerings choose what can be bought; they never decide whether a customer can
  enter the paid app.
- Anonymous RevenueCat identity survives relaunch and app updates, but not app
  deletion. A no-account app therefore needs visible, user-initiated Restore and
  a deliberately chosen RevenueCat restore-transfer policy.

If an existing app is being separated from a shared RevenueCat project, export the available customers, transactions, and charts before changing keys. Keep the shared project and private exports as the historical record. Older installed builds continue reporting there until customers update, so move and verify one app at a time.

## Launch Access Policy

Use optimistic continuity, not optimistic free access:

- Configure the purchase SDK before creating the SwiftUI root.
- Initialize `PaywallService` synchronously from the provider's persisted,
  previously verified entitlement snapshot. For RevenueCat, use
  `Purchases.shared.cachedCustomerInfo`.
- A cached active trial or subscription opens the complete app on the first
  frame while customer info refreshes in the background.
- A cached free or expired state shows the mandatory paywall immediately.
- An install with no cached decision stays gated. Start the check during
  onboarding; after the 1.5-second launch budget, replace progress with explicit
  Retry and Restore actions while allowing a late response to resolve access.
- A refresh error preserves a known locked or unlocked state. Only a successful
  inactive entitlement response can revoke access.
- Consume exactly one RevenueCat `customerInfoStream` and apply the supplied
  customer info directly. Do not start another fetch from inside the update.
  The stream begins with its last known value, so ignore a request-date
  duplicate or older snapshot without advancing the revision that protects an
  in-flight refresh.
- Prewarm offerings independently from entitlement resolution. Never make
  product/catalog loading the condition for opening an already-paid app.
- Do not invalidate the customer-info cache, call `AppStore.sync()`,
  `syncPurchases()`, or restore automatically on ordinary launch. RevenueCat
  restore is the one explicit customer action.
- A failed refresh never proves that access ended. A successful, newer inactive
  `CustomerInfo` may replace a cached active decision.
- Revision numbers prevent an older launch refresh from overwriting a newer
  purchase, restore, or stream result.

### Verified Apple fallback

The boilerplate also wires one positive-only StoreKit 2 continuity source for
the mapped subscription product. This covers an existing Apple subscriber whose
current anonymous RevenueCat record is inactive:

- RevenueCat remains the only purchase and transaction-finishing owner.
- Effective access is RevenueCat active **or** verified mapped StoreKit active.
- RevenueCat inactive plus StoreKit unresolved stays on Checking; a timeout can
  show Retry and Restore, but never the paywall.
- Launch and foreground share one StoreKit scan instead of replacing each
  other's results.
- A verified active scan saves only product ID, expiration, and verification
  time for at most 24 hours. A later cold launch opens immediately from that
  unexpired evidence while both providers refresh.
- A completed verified inactive scan clears saved StoreKit evidence. An
  unverified or interrupted scan preserves prior positive evidence.
- StoreKit never vetoes an active RevenueCat entitlement.

The canonical decision record lives in the 10x-os iOS Boilerplate
`Subscription Access SOP`. This repository includes the state machine and the
RevenueCat adapter so a derived app starts with one working ownership model.

## Trial Wording

- Load the exact offering, package, and product before enabling purchase.
- Show trial wording only when RevenueCat reports `eligible` and an introductory
  offer exists.
- For `ineligible` or no offer, show `Subscribe` and the localized price.
- For `unknown`, use neutral wording because Apple's purchase sheet makes the
  final eligibility decision.

## Diagnostic Timeline

Every access change should log the trigger and revision, anonymous versus
account-linked identity, cache hit or miss, CustomerInfo request age,
entitlement present/active, period, sandbox or production environment,
verification result, prior and next gate, duration, package/product match,
eligibility, and a safe error domain/code. Never log raw RevenueCat user IDs,
Apple account details, receipts, transaction IDs, JWS data, SDK keys, or full
CustomerInfo objects.

Debug builds also retain a bounded 256 KB timeline at
`Library/Application Support/subscription-diagnostics.ndjson`. Pull that file
from the app data container during physical-device QA so a short paywall flash
or launch race remains inspectable after the process exits.

## Debug And Simulator Testing

- Prefer RevenueCat Test Store for simulator purchase flow testing.
- Use the Test Store key only in `DEBUG` builds; Release/App Store builds must use
  the real platform app key.
- Test Store purchase modals may include success and failure buttons. That is
  expected and lets you validate both paths without real charges.
- Hide or relabel Test Store prices in Debug if they do not match production.
- Put any reset/replay controls in a separate `Developer Testing` section behind
  `#if DEBUG`.
- A useful reset flow rotates to a fresh test customer and clears local paid state,
  so the app can replay the purchase path without reinstalling.

## App Store Connect Readiness

- A working RevenueCat Test Store purchase proves the app entitlement path, not
  Apple's production catalog.
- Before App Review, verify the real App Store product is no longer missing
  metadata and is attached to the correct entitlement/offering.
- Test one StoreKit sandbox or TestFlight purchase against the real App Store
  product before submission.
- Test restore after deleting and reinstalling the app.
- Confirm the RevenueCat project uses the intended restore-transfer behavior for
  anonymous customers before relying on reinstall recovery.
- If offerings are empty, inspect logs for whether RevenueCat fetched the offering
  but StoreKit returned zero products. That usually points to App Store Connect
  metadata, product ID mismatch, unavailable sandbox catalog, or a simulator
  StoreKit configuration issue.

## Launch Checklist

- Dedicated RevenueCat project contains exactly this app unless intentional sharing is documented.
- Product ID and entitlement ID match across app code, RevenueCat, and store.
- Release build uses the production public SDK key.
- Debug-only Test Store code cannot compile into Release.
- Purchase, cancellation/failure, restore, and already-purchased states are tested.
- Trial-eligible, ineligible, no-offer, and unknown copy states are tested.
- Cached active launch reaches the complete app without a paywall flash.
- With RevenueCat inactive and Apple active, the first recognition shows at
  most Checking and then opens; after force-close, saved positive evidence opens
  the complete app on the first frame.
- Unknown/no-network launch reaches retry/restore recovery without an endless
  spinner or full-app bypass.
- Expiry or revocation shows the paywall only after an authoritative inactive
  result, with user data preserved.
- Settings shows plan/access status and restore path.
- The same build passes purchase -> immediate unlock -> force-close/relaunch
  online and offline, update-over-install, delete/reinstall -> Restore, expiry,
  refund, and revocation checks before continuity is called runtime-confirmed.
- App Store review notes explain how reviewers can find and test the purchase.
