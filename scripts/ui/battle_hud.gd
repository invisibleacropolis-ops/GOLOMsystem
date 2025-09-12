extends CanvasLayer
class_name BattleHUD

## Minimal battle HUD used by the vertical slice.
##
## The controller updates this node each turn to show actor status
## and contextual messages.  The node tree is intentionally
## lightweight: only the labels that exist in the scene will be
## manipulated, allowing outside engineers to swap in their own
## layouts without changing script code.

@onready var name_label: Label = get_node_or_null("Name")
@onready var hp_label: Label = get_node_or_null("HP")
@onready var ap_label: Label = get_node_or_null("AP")
@onready var tooltip_label: Label = get_node_or_null("Tooltip")
@onready var outcome_label: Label = get_node_or_null("Outcome")

func set_status(name: String, hp: int, ap: int) -> void:
    """Update the primary HUD fields for the active actor.

    `name` is displayed as-is while HP/AP are prefixed for clarity.
    Missing labels are ignored so the HUD can operate in stripped down
    layouts during testing.
    """
    if name_label:
        name_label.text = name
    if hp_label:
        hp_label.text = "HP: %d" % hp
    if ap_label:
        ap_label.text = "AP: %d" % ap

func set_tooltip(text: String) -> void:
    """Show a transient tooltip or hint message.

    Passing an empty string hides the tooltip label if present.
    This is useful for ability descriptions or contextual prompts.
    """
    if tooltip_label:
        tooltip_label.text = text
        tooltip_label.visible = text != ""

func show_outcome(text: String) -> void:
    """Display the battle result prominently on the HUD."""
    if outcome_label:
        outcome_label.text = text
        outcome_label.visible = true
    else:
        # Fallback to tooltip if no dedicated outcome label exists
        set_tooltip(text)
