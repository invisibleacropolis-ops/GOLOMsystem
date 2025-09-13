Humanizer System — Narrative Drivers for Events

Overview
The Humanizer converts structured gameplay events into human‑readable narration. It is designed to be provider‑driven so you can swap a rule‑based formatter for a local LLM later without changing game code.

Goals
- Deterministic, testable text during development (rule provider)
- Pluggable LLM provider for richer prose
- Stable event “driver” payloads that can be fed to LLMs

Architecture
- EventHumanizer (scripts/humanize/humanizer.gd)
  - Facade instantiated by the UI with a `services` reference and a provider mode.
  - Methods:
    - `humanize_event(evt: Dictionary) -> String`
    - `humanize_move_summary(actor, steps, dest, tags) -> String`
  - Provider selection: environment `HUMANIZER_PROVIDER` (rules | llm | llm_stub)

- Providers
  - Base (scripts/humanize/providers/base_provider.gd): interface
  - Rule (scripts/humanize/providers/rule_provider.gd): deterministic, readable text; supports terrain‑aware move aggregation
  - LLM Stub (scripts/humanize/providers/llm_stub_provider.gd): writes driver prompts to `user://humanizer_prompts.log` and returns simple prose for testing the integration path

Driver Payloads (Examples)
1) Action (move)
{
  "type": "action",
  "actor": {"name": "Hero", "faction": "player"},
  "data": {"id": "move", "payload": [12, 7]}
}

2) Damage
{
  "type": "damage",
  "actor": {"name": "Hero", "faction": "player"},
  "data": {"defender": {"name": "Goblin", "faction": "enemy"}, "amount": 2}
}

3) Move Summary (aggregated)
{
  "type": "move_summary",
  "actor": {"name": "Hero", "faction": "player"},
  "steps": 6,
  "dest": [15, 10],
  "tags": {"grass": 4, "road": 2}
}

Integration Points
- Event source: RuntimeServices bridges TurnTimespace signals to EventBus (round/turn/ap/action/damage/status/reaction/battle_over).
- Consumer: EventLogUI creates EventHumanizer and routes events or aggregated move summaries to it; the returned text is appended to the log.

Runtime Selection
- Set `HUMANIZER_PROVIDER=rules` for deterministic rule text (default).
- Set `HUMANIZER_PROVIDER=llm` (or `llm_stub`) to enable the LLM path; with the stub, prompts are logged to `user://humanizer_prompts.log`.

Future LLM Addon Hook
- Implement a provider that calls your local LLM (shared memory, TCP, or Godot plugin API).
- Accept the driver payloads above, return a string. Keep responses short to preserve UI pacing.

Testing
- Rule provider is deterministic and suitable for CI.
- LLM stub ensures the plumbing works without a model present; inspect `humanizer_prompts.log` to validate inputs.

