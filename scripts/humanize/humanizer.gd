extends RefCounted
class_name EventHumanizer

## Provider facade that turns structured events into narration.
##
## Roadmap:
## - rules: deterministic, testable narrative (current default)
## - llm: local LLM addon integration (set HUMANIZER_PROVIDER=llm)
## - tone: allow callers to pass a tone/style hint for the LLM
## - localization: optional target language code passed to providers

const BaseProvider = preload("res://scripts/humanize/providers/base_provider.gd")
const RuleProvider = preload("res://scripts/humanize/providers/rule_provider.gd")
const LlmStubProvider = preload("res://scripts/humanize/providers/llm_stub_provider.gd")

var _services: Node = null
var _provider: BaseProvider = null

func _init(services: Node = null, mode: String = "rules") -> void:
    _services = services
    _provider = _select_provider(mode)

func _select_provider(mode: String) -> BaseProvider:
    var m := (mode if mode != null and mode != "" else OS.get_environment("HUMANIZER_PROVIDER"))
    m = String(m).to_lower()
    match m:
        "llm", "llm_stub":
            return LlmStubProvider.new()
        _:
            return RuleProvider.new()

func humanize_event(evt: Dictionary) -> String:
    if _provider == null:
        return ""
    return _provider.humanize_event(evt, _services)

func humanize_move_summary(actor: Object, steps: int, dest: Vector2i, tags: Dictionary) -> String:
    if _provider == null:
        return ""
    return _provider.humanize_move_summary(actor, steps, dest, tags, _services)
