# iOS Boilerplate

This file applies to the entire `ios-boilerplate` repository.

## Product context

- Canonical product and technical documentation: `docs/`
- Read `docs/product/Product Context Brief.md` before substantive product decisions.
- Keep dated work packets and temporary evidence in dated Google Drive folders following the central Google Drive `AGENTS.md`.

## Repository map

- `Boilerplate/`, `BoilerplateTests/`, and `BoilerplateUITests/` — current coupled iOS starter source and tests.
- `Packages/` — repository-local reusable Swift packages.
- `docs/` — canonical durable product and technical documentation.
- `ci_scripts/` — Xcode Cloud hooks that require this root path.

## Working rules

- Follow the global agent rules, then these repository-specific rules.
- Preserve unrelated local changes.
- Treat `project.yml` as the source of truth for generated Xcode project configuration.
- Do not hand-edit generated Xcode project changes when XcodeGen owns them.
- After changing source paths or app code, run the smallest complete app-target compile/link build.
- Do not treat `.DS_Store`, DerivedData, build output, dependencies, or local tool state as durable source.
- Keep derived apps self-contained; they must not depend on this repository at runtime.
