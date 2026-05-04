# iOS Production-Readiness Checklist

Use this as the shipping SOP for every app created from this boilerplate. The app does not need every optional growth tool on day one, but each section needs an explicit decision before App Store submission.

## 1. First-Run Flow

- Fresh install reaches a real first value moment without dead ends.
- Onboarding is short, product-specific, and tracks `onboarding_started` and `onboarding_completed`.
- Permission prompts appear only at the moment the feature needs them.
- Login is required only for sync, identity, multi-device access, or paid entitlement recovery.
- The first meaningful success action calls `ReviewPromptService.recordSuccessfulAction(reason:)`.

## 2. Monetization

- Paid apps use a single purchase boundary through `PaywallService`.
- Subscription apps expose paywall, restore purchases, subscription status, and manage subscription.
- Paywall copy clearly states price, billing period, trial terms, and renewal behavior.
- RevenueCat is the recommended default subscription backend for derived apps.
- Superwall is optional when remote paywall placement and experimentation become a growth bottleneck.
- StoreKit sandbox purchase, restore, cancellation, and expired entitlement states are tested before release.

## 3. Reviews

- Use Apple's system review prompt, never a custom star-gating prompt.
- Ask only after a success moment, not during onboarding, first launch, or an error state.
- Keep a persistent Settings link to the App Store write-review URL.
- Track review prompt eligibility and prompt attempts through analytics events.
- Do not promise rewards, discounts, or access in exchange for reviews.

## 4. Analytics And Quality

- Keep event names stable across apps so funnels are comparable.
- Minimum events: app open, onboarding start/complete, first value action, paywall viewed, purchase started/completed/failed, restore started/completed/failed, review prompt eligible/requested, and core feature usage.
- PostHog is the recommended default product analytics provider.
- Add Sentry or Firebase Crashlytics before public launch.
- Upload dSYMs from CI so crash reports resolve to app versions and source lines.
- Add nonfatal error logging around network, auth, purchase, and persistence failures.

## 5. Settings And Trust

- Settings includes account, subscription status, restore purchases, manage subscription, contact support, privacy policy, terms, app version, and build number.
- Account apps include a delete-account flow connected to the backend before launch.
- Support email and legal URLs are app-specific, not boilerplate placeholders.
- Debug console remains visible only in development and TestFlight.

## 6. App Store And Privacy

- Replace bundle ID, display name, app icon, support URL, privacy URL, terms URL, and App Store ID.
- Complete App Store privacy details from actual app and SDK behavior.
- Update `PrivacyInfo.xcprivacy` when adding SDKs or required-reason APIs.
- If the app tracks users across apps or websites, implement App Tracking Transparency before collection starts.
- Add review notes and a demo account when App Review needs authenticated access.
- Confirm age rating, screenshots, subtitle, keywords, pricing, in-app products, and subscription metadata.

## 7. QA And Release

- Run unit tests and UI smoke tests on the current Xcode version.
- Test fresh install, returning user, offline/error states, dark mode, larger text, small iPhone, and iPad if supported.
- Test onboarding, login, paywall, restore purchases, Settings links, support links, and account deletion.
- Generate screenshots from a repeatable process before submission.
- Use TestFlight for at least one real-device pass before App Store review.
- Xcode Cloud should generate the project from `project.yml`, stamp `CURRENT_PROJECT_VERSION`, build, test, archive, and upload.

## 8. Post-Launch

- Watch crashes, refund requests, failed purchases, onboarding completion, paywall conversion, trial starts, and retention.
- Respond to reviews from App Store Connect or a review-management tool.
- Add push/email lifecycle only when the product has a real retention loop.
- Add App Store optimization tooling once downloads and keyword movement matter.
