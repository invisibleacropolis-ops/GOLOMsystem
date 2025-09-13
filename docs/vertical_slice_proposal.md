# Vertical Slice Proposal — XCOM‑Style Battle Mode

This master plan consolidates the project docs into a concrete, buildable vertical slice for Golom. It specifies scope, success criteria, new work, file touchpoints, and acceptance tests to ship a small, fully playable tactical encounter.

## Scope & Success Criteria

- Play a single skirmish: 2–3 player units vs. 2–3 enemies on a small procedural map (about 16×16–24×24).
- Core loop: select unit → preview move range → move → attack or special → end turn; enemies take turns with simple AI.
- Tactics: action points, line of sight, basic cover (half/full), hit/damage using Attributes.
- Visuals: grid highlights for range/paths/targets via `GridRealtimeRenderer` with minimal HUD (HP/AP, ability hotbar, end turn).
- Determinism and logs: actions and outcomes recorded to `EventBus`; headless tests pass; ASCII smoke run is stable.

## Player Experience

- Single mission loads into a compact map with visible obstacles (LOS blockers, cover tiles) and two squads placed apart.
- Click a unit to select; reachable tiles heat‑mapped; path preview on hover; confirm to move; valid targets highlighted when in LOS.
- Basic attack (melee or ranged) and one simple special per archetype; end turn button advances to enemy AI.
- Win: eliminate opposing squad. Loss: player squad eliminated.

## Systems To Build or Finish (What’s Next)

1) Squad Control + Turn UI
- Leverage: `scripts/modules/turn_timespace.gd`, `scripts/modules/loadouts.gd`, `scripts/modules/attributes.gd`, signals in docs/turn_timespace_manual.md.
- New Work:
  - Minimal HUD: current actor, HP/AP, ability buttons, End Turn.
  - Unit selection and focus handoff between player input and AI based on `turn_started/turn_ended`.
- Files (new/changed):
  - New `scripts/ui/battle_hud.gd` + `scenes/BattleHUD.tscn` (hooks into `RuntimeServices` signals and `Loadouts.get_available()`).
  - Update `scripts/core/root.gd` or add `scenes/VerticalSlice.tscn` + controller script to assemble slice scene.

2) Action Binding (Hotbar → Abilities/Timespace)
- Leverage: `scripts/modules/abilities.gd`, `scripts/modules/loadouts.gd`, `scripts/modules/turn_timespace.gd`, `data/actions.json`.
- New Work:
  - Define canonical actions: `move`, `attack_basic`, per‑archetype special in `data/actions.json`.
  - Bridge HUD buttons → `Abilities.can_use()` → `Abilities.execute()` and/or `TurnBasedGridTimespace.perform()`.
- Files:
  - Expand `data/actions.json` with `attack_basic`, archetype specials, and Move metadata for UI.
  - `scripts/ui/battle_hud.gd` hotbar wiring; `scripts/game/battle_controller.gd` to coordinate calls.

3) Movement Preview + Execution
- Leverage: `scripts/grid/grid_map.gd` (`find_path`, occupancy), `scripts/modules/GridRealtimeRenderer.gd` overlays, `turn_timespace.gd` AP spend.
- New Work:
  - Compute reachable set from AP budget (sum path tile cost vs. ACT value from `Attributes`).
  - Heatmap reachable tiles; stroke path preview; click to confirm; timespace deducts AP and moves actor via `LogicGridMap.move_actor()`.
- Files:
  - `scripts/grid/grid_interactor.gd` small additions for path hover; visuals via `GridRealtimeRenderer`.
  - `scripts/game/battle_controller.gd` reachability/path logic and AP budgeting.

4) Attack Ability (Hit/Damage Rules)
- Leverage: `abilities.gd` (costs, cooldowns), `attributes.gd` (HLTH, ACT, PWR/ACC), `event_bus.gd` (log), `grid_map.gd` (LOS check helper).
- New Work:
  - Define deterministic hit formula: e.g., Hit if LOS and range ≤ weapon range; start without RNG (or fixed seed). Damage = `PWR` with cover/LOS modifiers.
  - Emit `damage_applied` signal (already in docs) and reduce target HP via `Attributes` or actor property mediated by Attributes.
- Files:
  - Extend `data/actions.json` for `attack_basic` schema: {range, uses_los, damage_key, cover_mod}.
  - Implement execution branch in `abilities.gd` (data‑driven: read range/los, call grid/attr, push events).

5) Cover Mechanics (Half/Full)
- Leverage: `grid_map.gd` (`get_cover/set_cover`), `attributes.gd` modifiers, docs/grid_map_manual.md.
- New Work:
  - Author a few tiles with assigned cover types or set directional cover at runtime during map gen.
  - Apply defense/hit modifiers when target is in cover (e.g., half: −20% damage, full: −40%).
  - Visual indicators (icon/outline) for covered tiles/targets.
- Files:
  - Map gen step to place cover; `scripts/modules/procedural_map_generator.gd` small hook or a wrapper.
  - `scripts/game/combat_rules.gd` helper with `compute_cover_bonus()` consumed by abilities and AI.

6) LOS + Targeting UX
- Leverage: `grid_map.gd` (`has_line_of_sight`, LOS blockers), `GridRealtimeRenderer` for previews.
- New Work:
  - Hover target tiles highlights if LOS true; draw line/marks; filter valid targets list.
- Files:
  - `scripts/game/battle_controller.gd` hover targeting; `battle_hud.gd` tooltip with hit/damage preview.

7) Enemy AI (Simple)
- Leverage: `turn_timespace.gd` current actor/turn signals, `grid_map.gd` path/LOS, `abilities.gd` execution.
- New Work:
  - Stateless heuristic per enemy: if LOS to player in range → attack; else path to nearest cover within AP; else move toward nearest player.
- Files:
  - New `scripts/ai/simple_enemy_ai.gd` with `take_turn(actor)` used by controller when `turn_started` for enemy faction.

8) Win/Loss Conditions
- Leverage: `turn_timespace.gd` battle_over signal (per docs), `grid_map.gd` occupancy queries.
- New Work:
  - Monitor alive actors per faction; end on zero; show result screen/panel.
- Files:
  - `scripts/game/battle_controller.gd` victory check; HUD panel in `BattleHUD.tscn`.

9) Map Setup (Small Procedural Sandbox)
- Leverage: `scripts/modules/procedural_map_generator.gd`, `scripts/modules/procedural_world.gd`, `scripts/integration/t2g_bridge.gd`, `data/terrain.json`.
- New Work:
  - Parameterized small map (seeded), sprinkle `stone` LOS blockers, establish cover at edges of blockers, place spawn clusters.
- Files:
  - `scenes/VerticalSlice.tscn` world scene wiring generator → T2G bridge → `RuntimeServices`.

10) Data Setup (Archetypes & Baselines)
- Leverage: `scripts/core/base_actor.gd`, `scripts/actors/player_actor.gd`, `scripts/actors/enemy_actor.gd`, `data/*.json`.
- New Work:
  - Define two archetypes: Rifle Trooper (ranged special: overwatch or burst) and Bruiser (melee dash or stun). Enemies mirror simplified stats.
  - Seed `Attributes` bases (HLTH, ACT per round, PWR/ACC) via a loader or on spawn.
  - `Loadouts` grants: Move, Attack Basic, Special.
- Files:
  - Small loader in `scripts/game/archetypes.gd` or in `battle_controller.gd` to apply `Attributes.set_base()` and `Loadouts.grant()` at spawn.

11) Minimal Telemetry & Replays
- Leverage: `scripts/modules/event_bus.gd`, `turn_timespace.gd` event log/serialize.
- New Work:
  - Ensure major events recorded: round/turn, move, ability, damage, KO, victory.
- Files:
  - None beyond using `EventBus.push()` in controller/abilities where missing.

12) Tests, Headless + ASCII
- Leverage: `scripts/test_runner.gd`, `scripts/tools/ascii_console.gd`, docs/headless_tooling.md.
- New Work:
  - Add `scripts/tests/vertical_slice_test.gd`: headless setup, place 1v1, exercise move→attack→victory; assert HP/AP changes and `EventBus` schema.
  - Add CI smoke: run ASCII for a fixed script of commands; confirm no errors.
- Files:
  - New test script; optional `logs/ascii_commands.txt` example.

## Deliverables & File Changes

- Scenes/UI
  - New: `scenes/VerticalSlice.tscn` (world root + `RuntimeServices` + `BattleHUD` + `GridRealtimeRenderer`).
  - New: `scenes/BattleHUD.tscn` + `scripts/ui/battle_hud.gd` (HP/AP/abilities/end turn, signal wiring).

- Gameplay/Control
  - New: `scripts/game/battle_controller.gd` (state, selection, previews, turn routing, victory checks).
  - New: `scripts/game/combat_rules.gd` (cover/damage helpers; single import for formulae).
  - New: `scripts/ai/simple_enemy_ai.gd` (seek cover → attack → advance fallback).
  - Light edits: `scripts/grid/grid_interactor.gd` (hover path preview hooks).

- Data
  - Update: `data/actions.json` with `attack_basic` and two specials.
  - Optional: `data/actors.json` (if preferred) or encode bases in `battle_controller.gd` using `Attributes.set_base()`.

- Tests/Tooling
  - New: `scripts/tests/vertical_slice_test.gd` integrated into `scripts/test_runner.gd` discovery.
  - Optional: `logs/ascii_commands.txt` for scripted ASCII smoke.

## Implementation Notes (by Module)

- Turn Manager (`scripts/modules/turn_timespace.gd`)
  - Ensure `timespace.set_grid_map()` called before `start_round()` (see docs/runtime_services.md).
  - Use `turn_started/turn_ended/ap_changed/action_performed/damage_applied` signals to drive UI and AI.

- Grid Map (`scripts/grid/grid_map.gd`)
  - Use `find_path` and cost rules to compute reachable set; avoid diagonal initially; rely on `is_occupied`/footprints.
  - Author cover with `set_cover()` during map build; consult via `get_cover()` in combat.

- Abilities/Loadouts
  - Keep abilities data‑driven via `data/actions.json`; `Abilities.execute()` applies costs/cooldowns, emits events; call into `Attributes` for spend and damage.
  - `Loadouts.get_available(actor)` drives hotbar and AI action choices.

- Attributes/Statuses
  - Funnel all reads through `get_value()`. Use `set_range("HLTH", 0, max)` early. Apply temporary buffs via `Statuses` if needed.

- Renderer/Interactor
  - Prefer `GridRealtimeRenderer` for reachable/target highlights and ASCII debug; keep `GridVisualLogic` only for debug.

- EventBus
  - Standardize event dictionaries with `t` field: e.g., `move`, `attack`, `damage`, `ko`, `turn_start`, `turn_end`, `victory`.

## Acceptance Tests

- Headless Module Tests
  - Command: `scripts/godot4.cmd --headless --path . --script scripts/test_runner.gd -- --module=runtime_services` (then all).
  - Passing criteria: 0 failures; new `vertical_slice_test.gd` asserts: AP spend on move, LOS‑gated attack, HP reduction, victory detection.

- ASCII Smoke
  - Command: `pwsh -File scripts/run_headless.ps1 -Strict` or `pwsh -File scripts/ascii_play.ps1 -Pipe < logs/ascii_commands.txt`.
  - Passing criteria: no errors; final ASCII board shows victory text; logs include `victory` event.

- Manual Slice Run (GUI)
  - Open `Root.tscn` or `scenes/VerticalSlice.tscn` and play.
  - Criteria: select unit, visualize range/path, execute move and attack, enemy responds, win/loss resolves; HUD reflects HP/AP; overlay highlights correct tiles.

## Milestones & Estimates

- Phase 1: Movement + Turn Handoff (1–2 weeks)
  - Battle controller, HUD skeleton, selection, reachable heatmap, AP spend, end turn; basic victory check.

- Phase 2: Combat + Cover + LOS + AI (2–3 weeks)
  - Attack ability, damage rules, cover application, LOS gating, enemy AI v1; HUD hotbar; event logging.

- Phase 3: Polish + Specials + Tests (1–2 weeks)
  - Two unit specials, targeting previews, better feedback (labels/effects), tuning, headless test coverage, ASCII script.

## Risks & Assumptions

- Cover representation: ensure `set_cover()` supports required orientations; fallback to tagged tiles if directional cover is limited.
- Damage/hit model: start deterministic to avoid balance time; RNG can be added later.
- Performance: `GridRealtimeRenderer` batching is sufficient for small maps; monitor with `scripts/tests/grid_renderer_benchmark.gd`.
- Data workflow: prefer `data/actions.json`/attributes seeding to avoid hardcoding; keep formulas centralized in `combat_rules.gd`.

## Out of Scope (Post‑Slice)

- Campaign/meta progression, inventories, advanced AI planning, sound/music, saves/loads, cinematics, destruction, multiplayer.

---

References:
- docs/README.md (vertical slice context)
- docs/backend_architecture.md, docs/runtime_services.md, docs/turn_timespace_manual.md
- docs/grid_map_manual.md, docs/grid_realtime_renderer_manual.md
- docs/abilities_manual.md, docs/attributes_manual.md, docs/event_bus_manual.md
