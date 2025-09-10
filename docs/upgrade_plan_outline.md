# Future Upgrade Plan

This outline captures recommended enhancements for Golom's logic layer based on current code reviews. Items are grouped by area and intentionally verbose so future contributors can gauge scope and rationale.

## Core Infrastructure
- **Robust `GridLogic` implementation**
  - Replace the current stub with a coordinator that delegates to `LogicGridMap` for movement, LOS, and cover queries.
  - Expose high-level helpers (e.g., `can_move(actor, to)`, `threatened_tiles(actor)`) for AI and UI layers.
  - Include its own `run_tests()` covering edge cases like multi-tile actors and impassable terrain.
- **Workspace quality-of-life**
  - Persist module selection and loop intervals to `user://` config so engineers can resume sessions quickly.
  - Add a "Run Selected" option to target specific modules from the GUI.

## Spatial Systems
- **`LogicGridMap` extensions**
  - Support hex grids or variable movement rules via pluggable neighbor sets.
  - Implement caching for pathfinding results to accelerate repeated queries.
  - Allow dynamic terrain changes (raising/lowering height, toggling LOS blockers) with corresponding event log entries.
- **`GridInteractor` polish**
  - Right-click drag to pan the camera or cancel selections.
  - Hover previews that query `LogicGridMap` for threatened zones or reachable tiles.
  - Keyboard modifiers for snapping to orthogonal lines during drag selection.

## Timeline & Combat
- **`TurnBasedGridTimespace` depth**
  - Introduce explicit reaction windows between action phases and allow multiple watchers to respond with priority rules.
  - Expand status handling with callbacks or signals when applied/removed to update `Attributes` automatically.
  - Serialize and replay `event_log` entries to enable deterministic unit tests and replays.
- **Action system**
  - Move action definitions into data files (JSON or resources) and load them at runtime.
  - Add cooldown tracking and resource costs (`ACT`, `CHI`) with validation in `Abilities`.

## Actor Data & Effects
- **`Attributes` and `Statuses` integration**
  - Provide a `tick()` or observer pattern so status expiry automatically removes associated modifiers.
  - Implement percentage-based modifiers and clamped stat ranges.
- **`Loadouts`/`Abilities` growth**
  - Factor in equipment, class, and current statuses when computing available abilities.
  - Support ability chaining or combo systems through ordered effect lists.
- **`Reactions` engine**
  - Prioritize queued reactions by proximity or initiative rather than FIFO.
  - Offer hooks for AI to inspect pending reactions before execution.

## Visualization
- **`GridRealtimeRenderer` features**
  - GPU-based text rendering for labels to reduce draw calls.
  - Shader variations for night vision, fog of war, or colorblind-friendly palettes.
  - Benchmark harness to measure performance of large grids under heavy updates.
- **Documentation and tooling**
  - Add step-by-step tutorials demonstrating how to combine `GridRealtimeRenderer` with `TurnBasedGridTimespace` in gameplay scenes.
  - Generate API reference docs using `godot --doctool` for all modules.

## Testing & CI
- Automate `godot4 --headless` test runs in CI with log artifact uploads.
- Add regression tests for pathfinding, LOS, and ZOC calculations using deterministic seed scenarios.
- Validate documentation build steps so updates to `docs/` do not drift from code behavior.

