# iOS Boilerplate — Product Context Brief

**Audience:** AI and Voice-mode product partner  
**Current as of:** 2026-08-01  
**Source snapshot:** `main` at `2145b07`, plus local subscription-access and native-UI-quality work present on 2026-08-01  
**Evidence status:** Current source, project configuration, repository documentation, tests, CI, and local worktree were inspected. A generic iOS Simulator app build and test-bundle build passed on 2026-08-01. No simulator journey, physical-device subscription review, or clean-clone derivation proof was produced.

## How to advise on this product

Treat iOS Boilerplate as a shared developer product whose job is to shorten the path from a product decision to a trustworthy native app. It should remove repeated launch plumbing while leaving each derived app free to own its promise, data model, branding, customer journey, and release evidence.

Keep the foundation small and replaceable. Do not turn it into a runtime framework. The performance package is copied into each app, and other shared pieces should stay self-contained too.

The sample screens, auth, paywall, and provider suggestions are seams, not production behavior. A derived app must replace placeholders, configure providers and identifiers, and prove its own launch contract.

## Product in one minute

The primary user is Alex or a coding agent starting a new iOS product. The recurring problem is that every new app otherwise repeats the same architectural choices and launch surfaces before product-specific work can begin: project generation, navigation, networking, persistence, authentication seams, onboarding, monetization, settings, analytics, reviews, performance evidence, tests, privacy declarations, CI, and release checklists.

The promise is: **start every new native app from one understandable production foundation, then spend the first serious iteration on the product rather than rebuilding launch plumbing.**

The differentiator is not the number of utilities. It is the connected derivation contract: clone or copy the source, rename and configure it, replace the example feature with the real first-value loop, connect only the providers the product needs, and carry the app through compile, manual acceptance, monetization, privacy, and release evidence without hiding placeholders.

## Current product structure

| Surface | Current role |
|---|---|
| Project definition | XcodeGen `project.yml` defines one iOS 17 application, unit-test bundle, UI-test bundle, versions, identifiers, orientations, and a local performance package. |
| App shell | `BoilerplateApp` wires Router, API, auth, analytics, paywall, review prompting, SwiftData, scene-phase performance observation, and the root journey. |
| First-run journey | The sample route is onboarding → mandatory subscription gate → login → Home, with sign-up available and UI-test onboarding reset support. |
| Example feature | A CRUD-shaped example module demonstrates feature folders, models, service protocols, view models, loading state, forms, navigation, and tests. |
| Launch surfaces | A cache-first provider-neutral entitlement state machine, non-dismissible seven-day-trial paywall path, bounded retry/restore recovery, subscription status, Settings, support/legal links, review prompting, privacy manifest, export-compliance configuration, debug tools, and account-deletion placeholder. |
| Native UI quality | Semantic theme, primitive and component tokens, reusable buttons/cards, Design System Gallery, preview guidance, parity ledger, and visual-acceptance workflow are present in the local worktree but not fully committed or runtime-accepted. |
| Performance | A repo-local privacy-safe Performance Nervous System package and thin app adapter are part of the generated app. |
| Delivery | GitHub Actions runs XcodeGen and `build-for-testing`; Xcode Cloud, monetization, production-readiness, and native-UI-quality runbooks document the intended gates. |

## Confirmed current implementation

**Implemented:** The project targets iOS 17, Swift 5.9, marketing version 1.0.0, build 1, and bundle identifier `com.10x.boilerplate`. XcodeGen owns the generated project configuration.

**Implemented:** The app uses SwiftUI, `@Observable` state, environment-based dependency injection, a type-safe Router, protocol-oriented async networking, SwiftData, Keychain, UserDefaults, structured logging, analytics events, haptics, and review-prompt eligibility.

**Implemented:** Root navigation distinguishes onboarding, signed-out authentication, and authenticated Home. The sample Home exposes the example feature, paywall, and Settings. Settings contains account, preferences, subscription status, appearance, support, legal, version/build, cache clearing, debug console, onboarding reset, data reset, sign-out, and a deliberately unconnected account-deletion action.

**Implemented:** `PaywallService` is the provider-neutral seam for purchase, restore, entitlement state, and management. The visible paywall explicitly tells a developer to connect RevenueCat, StoreKit, or Superwall; it is not proof that any provider is configured.

**Implemented in the local worktree:** Subscription access now distinguishes checking, unlocked, locked, unavailable, and not-configured states. It consumes a provider's cached entitlement synchronously, preserves known access on refresh failure, bounds an unknown launch at 1.5 seconds before Retry/Restore recovery, and routes completed onboarding through a mandatory paywall before the complete app. The concrete RevenueCat adapter and live offering remain product-specific.

**Implemented:** The repository contains focused unit tests for networking, analytics events, paywall behavior, review prompting, and the example list view model, plus a UI-test target. GitHub Actions is configured to generate the project and build the app and tests for a generic iOS Simulator.

**Implemented in the local worktree, not committed at the source snapshot:** component tokens, the Design System Gallery, the Native UI Quality System document, and changes routing primary buttons and cards through the new component tokens. These changes belong to the user’s existing dirty worktree and must not be overwritten or represented as merged.

## Evidence boundary

- **Decided:** The boilerplate is the canonical starting implementation for derived iOS apps. Derived apps remain self-contained and own their customer promise and release proof.
- **Implemented:** The source and documentation contain the architecture, sample journey, launch seams, tests, performance package, CI definition, and local native-UI-quality work described above.
- **Compile/link verified:** XcodeGen regeneration, a Debug generic iOS Simulator app build, and `build-for-testing` all succeeded on 2026-08-01 using Xcode beta and the iOS 27 SDK. Tests were compiled but not executed.
- **Manually verified:** No current Alex-observed sample journey, derived-app setup, purchase path, or physical-device quality pass was found for this snapshot.
- **Unverified:** Runtime launch transitions, RevenueCat cache behavior in a derived app, seven-day trial purchase, relaunch persistence, restore, offline access, expiry/paywall return, clean-clone setup time, accessibility and visual quality, App Store submission readiness, and whether a new app can remove every placeholder without hidden coupling.

## Approved ambition versus current scaffold

The approved ambition is a dependable launch foundation, not a generic demo app. A strong result lets a new product inherit boring necessities and immediately replace the example with one credible promise and first-value path.

The current scaffold is substantial but deliberately incomplete. Authentication uses a service seam rather than a configured production identity provider. Monetization exposes the correct interface and states but no live offering. Support, legal, App Store identifiers, API URLs, bundle identity, icon, copy, and account deletion require product-specific configuration. The example CRUD flow demonstrates architecture but should not survive merely because it exists.

The uncommitted native UI quality work aims to close a real gap: reusable architecture alone does not guarantee a professional native result. Tokens, a production-component workbench, preview matrices, parity ledgers, and explicit visual acceptance can improve the starting point, but source presence and a compile pass still do not prove visual quality.

## Current priority and decision gate

The first gate is subscription launch behavior in one real RevenueCat candidate:

1. Returning active customers open the complete app from cached entitlement without a paywall flash.
2. A fresh customer completes onboarding, sees the mandatory seven-day-trial paywall, purchases, and unlocks immediately.
3. Relaunch and restore preserve access; offline cached access follows provider policy.
4. Unknown/no-network launch reaches Retry and Restore without an endless spinner or full-app bypass.
5. Confirmed expiry, refund, or revocation returns to the paywall with customer data preserved.

The source and test bundles compile, but runtime and Apple/RevenueCat evidence remain open. Do not roll the pattern into other apps until this acceptance gate passes. Clean derivation and native-UI-quality work move behind this blocker.

## Locked constraints and deferred work

- Keep iOS 17 and Swift 5.9 as the default until a real product requires an older deployment target.
- Keep XcodeGen as the project source of truth; do not hand-maintain generated project churn.
- Keep derived apps self-contained.
- Keep provider integrations replaceable and explicit.
- Keep build proof, simulator rendering, and physical-device acceptance as separate evidence.
- Preserve the user’s current dirty worktree; do not stage or overwrite it as part of documentation work.
- Defer a large plugin system, shared runtime framework, and one-command abstraction until repeated derivations prove a concrete need.

## Open product questions

1. What is the acceptable time and number of manual steps from clone to a renamed compiling app?
2. Which placeholders should fail the build or release check until replaced?
3. Should the native UI quality work become part of the committed default immediately after review, or remain an optional recipe?
4. Which provider recipes deserve first-class tested examples without making providers hard dependencies?
5. How will improvements flow back from derived apps without forcing them to track the boilerplate continuously?

## Source hierarchy

1. [Project configuration](file:///Users/10x/dev/oss/ios-boilerplate/project.yml) and [app entry point](file:///Users/10x/dev/oss/ios-boilerplate/Boilerplate/App/BoilerplateApp.swift) own implementation truth with the rest of the live source.
2. [Repository README](file:///Users/10x/dev/oss/ios-boilerplate/README.md) owns setup and the public technical promise.
3. [Architecture](file:///Users/10x/dev/oss/ios-boilerplate/ARCHITECTURE.md) owns detailed patterns.
4. [Production readiness checklist](file:///Users/10x/dev/oss/ios-boilerplate/docs/PRODUCTION-READINESS-CHECKLIST.md) and [Xcode Cloud workflow](file:///Users/10x/dev/oss/ios-boilerplate/docs/XCODE-CLOUD-WORKFLOW.md) own release and CI procedure.
5. [Native UI Quality System](file:///Users/10x/dev/oss/ios-boilerplate/docs/NATIVE-UI-QUALITY-SYSTEM.md) describes uncommitted local work and must not be treated as merged until Git confirms it.
6. [Subscription Access SOP](../SUBSCRIPTION-ACCESS-SOP.md) owns the portfolio launch-gating contract.
7. [Subscription Launch Gating Study](file:///Users/10x/10x-os/50-engineering/2026-08-02%20-%20Subscription%20Launch%20Gating%20Study/Subscription%20Launch%20Gating%20Study.md) owns its Apple, RevenueCat, and GitHub evidence.
8. [Product Board](Product%20Board.html) owns the product role and derivation journey.
9. [Backlog Board](Backlog%20Board.html) owns the current bounded work queue.

Live source wins for implementation, a clean derivation run wins for bootstrap behavior, current native rendering wins for visual behavior, and physical-device evidence wins for device-dependent quality.

## Decision handoff and maintenance rule

At the end of a product discussion, return:

- **Decision:** The foundation, derivation, provider, quality, or release decision.
- **Why:** The repeated app-development problem it removes.
- **What changes:** The affected starter surface or derivation step.
- **What stays locked:** Self-contained apps, explicit placeholders, and evidence boundaries.
- **Evidence needed:** The exact build, test, clean-derivation, rendering, or device result required next.
- **Implementation requested:** None, documentation only, or a narrow repository change.

Refresh this brief after a material foundation decision, a completed clean-derivation proof, accepted native-UI-quality work, or a new tagged release. Keep commit history and technical detail in the repository.
