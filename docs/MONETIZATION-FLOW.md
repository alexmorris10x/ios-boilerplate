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

- Use a public SDK key in the app only. Never commit secret API keys.
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
- Prewarm offerings independently from entitlement resolution. Never make
  product/catalog loading the condition for opening an already-paid app.
- Do not invalidate the customer-info cache, call `AppStore.sync()`,
  `syncPurchases()`, or restore automatically on ordinary launch. RevenueCat
  restore is the one explicit customer action.
- A failed refresh never proves that access ended. A successful, newer inactive
  `CustomerInfo` may replace a cached active decision.
- Revision numbers prevent an older launch refresh from overwriting a newer
  purchase, restore, or stream result.

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

- Product ID and entitlement ID match across app code, RevenueCat, and store.
- Release build uses the production public SDK key.
- Debug-only Test Store code cannot compile into Release.
- Purchase, cancellation/failure, restore, and already-purchased states are tested.
- Trial-eligible, ineligible, no-offer, and unknown copy states are tested.
- Cached active launch reaches the complete app without a paywall flash.
- Unknown/no-network launch reaches retry/restore recovery without an endless
  spinner or full-app bypass.
- Expiry or revocation shows the paywall only after an authoritative inactive
  result, with user data preserved.
- Settings shows plan/access status and restore path.
- The same build passes purchase -> immediate unlock -> force-close/relaunch
  online and offline, update-over-install, delete/reinstall -> Restore, expiry,
  refund, and revocation checks before continuity is called runtime-confirmed.
- App Store review notes explain how reviewers can find and test the purchase.
