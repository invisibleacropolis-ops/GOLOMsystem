extends CanvasLayer

## Provides runtime control buttons (pause, end turn, grid toggle)
## and simple dialogs for confirmation or unsupported actions.
## This script is intentionally lightweight so outside engineers
## can easily follow the data flow between UI and core services.

const TurnBasedGridTimespace = preload("res://scripts/modules/turn_timespace.gd")

@onready var runtime = get_node_or_null("../Runtime")
@onready var pause_button: Button = $Root/VBox/BottomRow/BottomButtons/BottomButtonsContainer/PauseButton
@onready var end_turn_button: Button = $Root/VBox/BottomRow/BottomButtons/BottomButtonsContainer/EndTurnButton
@onready var toggle_grid_button: Button = $Root/VBox/TopRow/RightPanel/ButtonsPanel/ButtonsContainer/ToggleGridButton
@onready var confirm_end_turn: ConfirmationDialog = $Root/ConfirmEndTurn
@onready var message_dialog: AcceptDialog = $Root/MessageDialog

func _ready() -> void:
    """Wire button presses to handlers once the HUD enters the scene tree."""
    pause_button.pressed.connect(_on_pause_pressed)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    toggle_grid_button.pressed.connect(_on_toggle_grid_pressed)
    confirm_end_turn.confirmed.connect(_on_confirm_end_turn)

func _on_pause_pressed() -> void:
    """Attempt to pause or resume the tactical round.

    If the timespace module exposes a `pause_round` method it will be used.
    Otherwise a message dialog informs the user the action is unsupported.
    When paused via `IDLE` state, pressing the button again restarts the round.
    """
    if runtime == null or runtime.timespace == null:
        _show_message("Runtime not available")
        return
    if runtime.timespace.has_method("pause_round"):
        runtime.timespace.pause_round()
    elif runtime.timespace.state == TurnBasedGridTimespace.State.IDLE:
        runtime.timespace.start_round()
    else:
        _show_message("Pause action not supported")

func _on_end_turn_pressed() -> void:
    """Display a confirmation dialog before ending the active turn."""
    confirm_end_turn.popup_centered()

func _on_confirm_end_turn() -> void:
    """End the current actor's turn once confirmed."""
    if runtime != null:
        runtime.timespace.end_turn()
    else:
        _show_message("Runtime not available")

func _on_toggle_grid_pressed() -> void:
    """Toggle visibility of the world grid for debugging purposes."""
    var world := get_node_or_null("../WorldRoot")
    if world == null:
        _show_message("World not found")
        return
    var grid := world.get_node_or_null("Gridmaps/GroundGrid")
    if grid == null:
        _show_message("Grid node not found")
        return
    grid.visible = not grid.visible

func _show_message(msg: String) -> void:
    """Helper that displays a modal dialog with the provided text."""
    message_dialog.dialog_text = msg
    message_dialog.popup_centered()

## Display end-of-battle outcome prominently.
func show_outcome(text: String) -> void:
    message_dialog.title = "Battle Result"
    _show_message(text)
