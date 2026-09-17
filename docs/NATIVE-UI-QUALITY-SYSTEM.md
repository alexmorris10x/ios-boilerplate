# Native UI Quality System

Use this system to translate an approved Product Board, HTML reference, or
storyboard into high-quality native SwiftUI without losing hierarchy, depth,
state design, or motion.

## Authority

Keep four forms of evidence separate:

1. The approved visual reference owns product and visual decisions.
2. Swift source proves which decisions are implemented.
3. Native previews or Simulator captures prove rendering in inspected states.
4. Physical-device review proves device-dependent appearance, motion, touch,
   accessibility, and feel.

A successful build proves only that the source compiles.

## Token Layers

Use one-directional dependencies:

```text
primitive -> semantic -> component -> feature composition
```

- `UIConstants` owns raw spacing, radius, size, border, and similar values.
- `AppTheme` owns product meaning such as surface, text, action, success,
  warning, and error.
- `ComponentTokens` owns the exact construction of buttons, cards, rows,
  dials, and other reusable components.
- Feature views compose components and should not introduce unrelated visual
  constants.

When HTML and SwiftUI share a visual system, keep reusable decisions in a
platform-neutral token source when practical. Generate or map CSS variables and
Swift values from it. Do not try to convert HTML layout directly into SwiftUI.

## Component Contract

Every distinctive or repeated visual object needs:

- stable parity identifier
- native component name
- named inputs and states
- primitive, semantic, and component tokens
- layer anatomy
- motion meaning and Reduce Motion behavior
- Dynamic Type and accessibility behavior
- allowed native adaptation

The production screen and the native workbench must use the same component.

## Native Workbench

`DesignSystemGallery` is the dependency-free Storybook equivalent included in
the boilerplate. Keep it debug-only or unreachable from production navigation.
Add each important production component and its representative states.

Add named `#Preview` entries for the smallest relevant matrix:

- approved representative state
- default/live state
- loading, empty, partial, unavailable, and error states
- light and dark appearance
- target device width
- large text
- Reduce Motion for animated components

Use Prefire when generated component playbooks, flows, or preview-derived tests
materially reduce work. Use Inject when debug hot reload materially improves
motion or in-context tuning.

## Parity Ledger

Track source and visual status separately:

```text
Surface | Reference detail | Native target | Source | Visual | Notes
Home hero | layered dial | CapacityDial | implemented | uninspected | Phase 2 review required
```

Allowed source states:

```text
missing | partial | implemented | intentionally deferred
```

Allowed visual states:

```text
uninspected | differs | accepted | intentionally adapted
```

Never report `implemented` as visual parity.

## Acceptance Loop

1. Approve the visual reference and component construction.
2. Implement tokens and the isolated native component.
3. Add the component's preview matrix and workbench states.
4. Complete the Phase 1 compile/link gate. Visual status remains uninspected.
5. With an authorized visual-testing contract, capture the native component at
   a matched size.
6. Compare it with the approved reference side by side and, when useful, with
   an overlay or image diff.
7. Classify every difference as accepted native adaptation, defect, or explicit
   deferral.
8. Obtain human visual acceptance.
9. Add snapshot baselines for stable accepted components and representative
   screens.
10. Verify device-dependent appearance, motion, touch, and accessibility on a
    physical iPhone when those claims matter.

Snapshot tests preserve an accepted result. They do not determine whether the
first render is good.
