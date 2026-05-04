# iOS Boilerplate — Xcode Cloud Workflow Standard

Last updated: 2026-02-24

## Goal
Provide a reproducible default for Xcode Cloud so template-derived apps avoid flaky release behavior.

## Defaults
- Trigger builds via workflow Start Conditions (branch/PR/tag/schedule/manual), not by committing version bumps.
- Generate the Xcode project from `project.yml` with XcodeGen before building.
- Keep `MARKETING_VERSION` for release-line intent.
- Stamp `CURRENT_PROJECT_VERSION` from `CI_BUILD_NUMBER` in `ci_scripts/ci_post_clone.sh`.

## Template integration
1. Copy `ci_scripts/ci_post_clone.sh` into app repo.
2. Ensure the script is executable: `chmod +x ci_scripts/ci_post_clone.sh`.
3. Keep `project.yml` committed and generated `.xcodeproj` files untracked.
4. The post-clone script uses existing `xcodegen` or installs it with Homebrew when available.
5. If your project path is non-standard, set `IOS_XCODEPROJ_PATH` in Xcode Cloud environment (e.g. `MyApp.xcodeproj`).

## Troubleshooting
- If the project is missing, run `xcodegen generate` locally and fix `project.yml`.
- If builds seem missing, inspect all statuses (queued/completed/action_required/cancelled).
- If build is `action_required`, open details and fix the first compile/script error.
- If upload rejects build, confirm build string advanced and format remains valid.
