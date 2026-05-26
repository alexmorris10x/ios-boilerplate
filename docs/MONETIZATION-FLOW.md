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
- Settings shows plan/access status and restore path.
- App Store review notes explain how reviewers can find and test the purchase.
