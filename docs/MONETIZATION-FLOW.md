# Monetization Flow Runbook

Use this runbook when wiring purchases in apps created from this boilerplate. Keep
the app code provider-neutral at the feature boundary, then place RevenueCat,
StoreKit, or another provider behind `PaywallService`.

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
- Keep the product identifier, entitlement identifier, and offering/package choice
  in one small configuration surface.
- Treat RevenueCat entitlements as the app's paid-access source of truth.
- For one-time Pro purchases, model the product as lifetime access in the UI.
- Keep `Restore Purchases` wired even for lifetime products so reinstall and
  device-transfer paths are obvious.

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
- Consume RevenueCat's `customerInfoStream` and apply the supplied customer info
  directly. Do not start another customer-info fetch from inside the update.
- Prewarm offerings independently from entitlement resolution. Never make
  product/catalog loading the condition for opening an already-paid app.
- Do not invalidate the customer-info cache, call `AppStore.sync()`, or restore
  automatically on ordinary launch. Restore is an explicit customer action.

The canonical product decision and adapter example live in the 10x-os iOS
Boilerplate `Subscription Access SOP`. This repository implements the
provider-neutral state machine; each derived app supplies its RevenueCat adapter.

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
- If offerings are empty, inspect logs for whether RevenueCat fetched the offering
  but StoreKit returned zero products. That usually points to App Store Connect
  metadata, product ID mismatch, unavailable sandbox catalog, or a simulator
  StoreKit configuration issue.

## Launch Checklist

- Product ID and entitlement ID match across app code, RevenueCat, and store.
- Release build uses the production public SDK key.
- Debug-only Test Store code cannot compile into Release.
- Purchase, cancellation/failure, restore, and already-purchased states are tested.
- Cached active launch reaches the complete app without a paywall flash.
- Unknown/no-network launch reaches retry/restore recovery without an endless
  spinner or full-app bypass.
- Expiry or revocation shows the paywall only after an authoritative inactive
  result, with user data preserved.
- Settings shows plan/access status and restore path.
- App Store review notes explain how reviewers can find and test the purchase.
