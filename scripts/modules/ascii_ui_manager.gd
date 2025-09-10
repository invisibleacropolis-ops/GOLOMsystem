# ascii_ui_manager.gd
extends Node
signal command_entered(command: String)

# --- Exported Properties ---
@export var runtime_services_path: NodePath
@export var grid_realtime_renderer_path: NodePath
@export var player_actor_path: NodePath

# --- Internal References ---
var _runtime_services: Node = null
var _grid_realtime_renderer: Node = null
var _player_actor: Node = null

# --- State Machine for Input Modes ---
enum InputMode {
    MODE_NONE,
    MODE_MOVEMENT,
    MODE_TARGETING,
    MODE_MENU,
    MODE_COMMAND_INPUT
}
var _current_input_mode: InputMode = InputMode.MODE_NONE
var _potential_target_pos: Vector2i = Vector2i.ZERO # NEW: For movement preview
var _target_cursor_pos: Vector2i = Vector2i.ZERO # NEW: For targeting mode
var _current_menu_items: Array[String] = [] # NEW: For menu mode
var _selected_menu_item_index: int = 0 # NEW: For menu mode
var _command_input_string: String = "" # NEW: For command input mode

# --- Thread for stdin loop ---
var _input_thread: Thread = null

# --- Combat Log ---
var _combat_log_messages: Array = []
const MAX_LOG_MESSAGES: int = 5 # Display last 5 messages

# --- Initialization ---
func _ready() -> void:
    # Get references to the necessary nodes
    _runtime_services = get_node_or_null(runtime_services_path)
    _grid_realtime_renderer = get_node_or_null(grid_realtime_renderer_path)
    _player_actor = get_node_or_null(player_actor_path)

    if not _runtime_services:
        push_error("AsciiUIManager: RuntimeServices node not found at path: ", runtime_services_path)
        return
    if not _grid_realtime_renderer:
        push_error("AsciiUIManager: GridRealtimeRenderer node not found at path: ", grid_realtime_renderer_path)
        return
    if not _player_actor:
        push_error("AsciiUIManager: PlayerActor node not found at path: ", player_actor_path)
        return

    # Configure the renderer for ASCII output
    _grid_realtime_renderer.ascii_use_color = true
    _grid_realtime_renderer.ascii_include_actors = true
    _grid_realtime_renderer.ascii_actor_group = &"actors"
    _grid_realtime_renderer.set_grid_size(_runtime_services.grid_map.width, _runtime_services.grid_map.height)

    # Subscribe to necessary game logic signals
    var timespace = _runtime_services.timespace
    if timespace:
        timespace.round_started.connect(_on_round_started)
        timespace.turn_started.connect(_on_turn_started)
        timespace.ap_changed.connect(_on_ap_changed)
        timespace.action_performed.connect(_on_action_performed)
        
    # Connect to EventBus for combat log
    if _runtime_services.event_bus:
        _runtime_services.event_bus.event_pushed.connect(_on_event_bus_event)

    # Set initial input mode
    _current_input_mode = InputMode.MODE_MOVEMENT
    _potential_target_pos = _player_actor.grid_pos # Initialize potential target position

    # Start stdin loop for interaction.
    _input_thread = Thread.new()
    _input_thread.start(Callable(self, "_stdin_loop"))

    # Initial display update
    _update_ascii_display()

# --- Input Processing ---
func _input(event: InputEvent) -> void:
    pass

# --- Stdin Loop ---
func _stdin_loop() -> void:
    while true:
        var line := OS.read_string_from_stdin(1024).strip_edges()
        if line == "quit":
            call_deferred("quit_ascii_mode")
            return
        
        call_deferred("_process_stdin_command", line)

# --- Process Stdin Command (called from main thread) ---
func _process_stdin_command(command: String) -> void:
    match _current_input_mode:
        InputMode.MODE_MOVEMENT:
            _handle_movement_input(command)
        InputMode.MODE_TARGETING:
            _handle_targeting_input(command)
        InputMode.MODE_MENU:
            _handle_menu_input(command)
        InputMode.MODE_COMMAND_INPUT:
            _handle_command_input(command)
        _:
            emit_signal("command_entered", command) # Emit signal for unhandled commands
            pass

# --- Specific Input Handlers ---
func _handle_movement_input(command: String) -> void:
    var current_actor = _runtime_services.timespace.get_current_actor()
    if not current_actor or current_actor != _player_actor: return

    var player_pos = current_actor.grid_pos
    var new_potential_target_pos = _potential_target_pos

    match command:
        "w": new_potential_target_pos.y -= 1
        "s": new_potential_target_pos.y += 1
        "a": new_potential_target_pos.x -= 1
        "d": new_potential_target_pos.x += 1
        "enter":
            if _runtime_services.timespace.perform(current_actor, "move", {"target_pos": _potential_target_pos}):
                _runtime_services.timespace.end_turn()
                _potential_target_pos = player_pos # Reset after successful move
            _update_ascii_display()
            return
        "q":
            _runtime_services.timespace.end_turn()
            _update_ascii_display()
            return
        "r": # Reset potential target position
            _potential_target_pos = player_pos
            _update_ascii_display()
            return
        _:
            pass

    # Update potential target position only if it's within bounds and different from current
    if new_potential_target_pos != _potential_target_pos:
        _potential_target_pos = new_potential_target_pos
        _update_ascii_display()

func _handle_targeting_input(command: String) -> void:
    var new_target_cursor_pos = _target_cursor_pos

    match command:
        "w": new_target_cursor_pos.y -= 1
        "s": new_target_cursor_pos.y += 1
        "a": new_target_cursor_pos.x -= 1
        "d": new_target_cursor_pos.x += 1
        "enter":
            _combat_log_messages.append("Target selected: " + str(_target_cursor_pos))
            set_input_mode(InputMode.MODE_MOVEMENT) # Return to movement mode after selecting target
            return
        "r": # Cancel targeting
            set_input_mode(InputMode.MODE_MOVEMENT)
            return
        _:
            pass

    # Update target cursor position only if it's within bounds and different from current
    if new_target_cursor_pos != _target_cursor_pos:
        _target_cursor_pos = new_target_cursor_pos
        _update_ascii_display()

func _handle_menu_input(command: String) -> void:
    match command:
        "w":
            _selected_menu_item_index = wrapi(_selected_menu_item_index - 1, 0, _current_menu_items.size())
            _update_ascii_display()
        "s":
            _selected_menu_item_index = wrapi(_selected_menu_item_index + 1, 0, _current_menu_items.size())
            _update_ascii_display()
        "enter":
            if _current_menu_items.size() > 0:
                var selected_item = _current_menu_items[_selected_menu_item_index]
                _combat_log_messages.append("Menu item selected: " + selected_item)
                # In a real game, you'd trigger an action based on selected_item
            set_input_mode(InputMode.MODE_MOVEMENT) # Exit menu after selection
            return
        "r": # Exit menu
            set_input_mode(InputMode.MODE_MOVEMENT)
            return
        _:
            pass

func _handle_command_input(command: String) -> void:
    match command:
        "enter":
            _combat_log_messages.append("Command executed: " + _command_input_string)
            # In a real game, you'd parse and execute the command
            _command_input_string = ""
            set_input_mode(InputMode.MODE_MOVEMENT) # Exit command mode after execution
            return
        "backspace":
            if _command_input_string.length() > 0:
                _command_input_string = _command_input_string.substr(0, _command_input_string.length() - 1)
                _update_ascii_display()
            return
        "r": # Exit command mode
            _command_input_string = ""
            set_input_mode(InputMode.MODE_MOVEMENT)
            return
        _:
            if command.length() == 1: # Allow single character input
                _command_input_string += command
                _update_ascii_display()
            pass

# --- Game Data Translation and ASCII Output ---
func _update_ascii_display() -> void:
    if not _grid_realtime_renderer: return

    _grid_realtime_renderer.clear_all()
    _grid_realtime_renderer.begin_labels()

    # --- Render Game World ---
    var logic_map = _runtime_services.grid_map
    if logic_map:
        for y in range(logic_map.height):
            for x in range(logic_map.width):
                var pos = Vector2i(x, y)
                var terrain_tags = logic_map.tile_tags.get(pos, [])
                var terrain_color = Color.WHITE
                var terrain_symbol = "."

                if terrain_tags.has("grass"):
                    terrain_color = Color.GREEN
                    terrain_symbol = ","
                elif terrain_tags.has("water"):
                    terrain_color = Color.BLUE
                    terrain_symbol = "~"
                elif terrain_tags.has("wall"):
                    terrain_color = Color.GRAY
                    terrain_symbol = "#"
                elif terrain_tags.has("door"):
                    terrain_color = Color.BROWN
                    terrain_symbol = "+"
                # Add more terrain types as needed

                _grid_realtime_renderer.set_cell_color(pos, terrain_color)
                _grid_realtime_renderer.set_ascii_entity(pos, terrain_symbol, terrain_color)

    # --- Render Potential Target Position ---
    if _current_input_mode == InputMode.MODE_MOVEMENT and _potential_target_pos != _player_actor.grid_pos:
        _grid_realtime_renderer.set_cell_color(_potential_target_pos, Color.YELLOW)
        _grid_realtime_renderer.set_ascii_entity(_potential_target_pos, "X", Color.YELLOW)

    # --- Render Target Cursor Position ---
    if _current_input_mode == InputMode.MODE_TARGETING:
        _grid_realtime_renderer.set_cell_color(_target_cursor_pos, Color.RED)
        _grid_realtime_renderer.set_ascii_entity(_target_cursor_pos, "X", Color.RED)

    # --- Render Actors ---
    var current_actor = _runtime_services.timespace.get_current_actor()
    for actor_node in get_tree().get_nodes_in_group("actors"):
        if actor_node.has_method("get_grid_pos"):
            var actor_pos = actor_node.get_grid_pos()
            var actor_hp = _runtime_services.attributes.get_value(actor_node, "HLTH")
            var actor_ap = _runtime_services.attributes.get_value(actor_node, "ACT")

            # Display actor symbol
            var actor_symbol = actor_node.get_ascii_symbol() if actor_node.has_method("get_ascii_symbol") else "?"
            var actor_color = actor_node.get_ascii_color() if actor_node.has_method("get_ascii_color") else Color.WHITE
            _grid_realtime_renderer.set_ascii_entity(actor_pos, actor_symbol, actor_color)

            # Display HP/AP near actor
            _grid_realtime_renderer.push_label(
                str(actor_hp) + "/" + str(actor_ap),
                actor_pos.to_float() * _grid_realtime_renderer.cell_size + Vector2(0, -10),
                Color.LIME_GREEN if actor_node == current_actor else Color.WHITE
            )
            # Add status indicators (conceptual)
            # var statuses = _runtime_services.statuses.get_statuses_for_actor(actor_node)
            # if statuses.has("poisoned"):
            #     _grid_realtime_renderer.set_ascii_entity(actor_pos, "P", Color.PURPLE, 100) # Higher priority

    # --- Render UI Elements ---
    var line_height = 15 # Approximate pixel height for a line of text

    # Player Stats Panel (top-right)
    if _player_actor:
        var player_hp = _runtime_services.attributes.get_value(_player_actor, "HLTH")
        var player_max_hp = _runtime_services.attributes.get_value(_player_actor, "MAX_HLTH") # Assuming MAX_HLTH
        var player_ap = _runtime_services.attributes.get_value(_player_actor, "ACT")
        var player_max_ap = _runtime_services.attributes.get_value(_player_actor, "MAX_ACT") # Assuming MAX_ACT

        var stats_x_offset = _grid_realtime_renderer.grid_size.x * _grid_realtime_renderer.cell_size.x + 20 # Right of grid
        _grid_realtime_renderer.push_label("--- Player Stats ---", Vector2(stats_x_offset, 0), Color.YELLOW)
        _grid_realtime_renderer.push_label("HP: " + str(player_hp) + "/" + str(player_max_hp), Vector2(stats_x_offset, line_height), Color.RED)
        _grid_realtime_renderer.push_label("AP: " + str(player_ap) + "/" + str(player_max_ap), Vector2(stats_x_offset, line_height * 2), Color.CYAN)
        _grid_realtime_renderer.push_label("Mode: " + InputMode.keys()[_current_input_mode], Vector2(stats_x_offset, line_height * 3), Color.WHITE)


    # Combat Log Panel (bottom)
    var log_start_y = _grid_realtime_renderer.grid_size.y * _grid_realtime_renderer.cell_size.y + 10
    _grid_realtime_renderer.push_label("--- Combat Log ---", Vector2(0, log_start_y), Color.YELLOW)
    for i in range(min(_combat_log_messages.size(), MAX_LOG_MESSAGES)):
        _grid_realtime_renderer.push_label(
            _combat_log_messages[_combat_log_messages.size() - 1 - i], # Display newest messages at bottom
            Vector2(0, log_start_y + line_height * (i + 1)),
            Color.WHITE
        )

    # --- Render Menu ---
    if _current_input_mode == InputMode.MODE_MENU:
        var menu_start_x = 5
        var menu_start_y = log_start_y + line_height * (MAX_LOG_MESSAGES + 2) # Below combat log
        _grid_realtime_renderer.push_label("--- Menu ---", Vector2(menu_start_x, menu_start_y), Color.YELLOW)
        for i in range(_current_menu_items.size()):
            var item_text = _current_menu_items[i]
            var item_color = Color.WHITE
            if i == _selected_menu_item_index:
                item_text = "> " + item_text
                item_color = Color.LIME_GREEN
            _grid_realtime_renderer.push_label(item_text, Vector2(menu_start_x, menu_start_y + line_height * (i + 1)), item_color)

    # --- Render Command Input ---
    if _current_input_mode == InputMode.MODE_COMMAND_INPUT:
        var cmd_start_x = 0
        var cmd_start_y = _grid_realtime_renderer.grid_size.y * _grid_realtime_renderer.cell_size.y + 10 + line_height * (MAX_LOG_MESSAGES + 2 + _current_menu_items.size() + 2) # Below menu/log
        _grid_realtime_renderer.push_label("CMD> " + _command_input_string + "_", Vector2(cmd_start_x, cmd_start_y), Color.WHITE)

    _grid_realtime_renderer.end_labels()
    print(_grid_realtime_renderer.generate_ascii_field())

# --- Signal Handlers ---
func _on_round_started() -> void:
    _combat_log_messages.append("Round Started!")
    _update_ascii_display()

func _on_turn_started(actor: Object) -> void:
    _combat_log_messages.append("Turn for: " + actor.name)
    _update_ascii_display()

func _on_ap_changed(actor: Object, old_ap: int, new_ap: int) -> void:
    _combat_log_messages.append(actor.name + " AP: " + str(old_ap) + " -> " + str(new_ap))
    _update_ascii_display()

func _on_action_performed(actor: Object, action_id: String, _payload) -> void:
    _combat_log_messages.append(actor.name + " performed: " + action_id)
    _update_ascii_display()

func _on_event_bus_event(event_data: Dictionary) -> void:
    var msg = "Event: " + event_data.get("t", "unknown")
    if event_data.has("actor"):
        msg += " Actor: " + event_data.actor.name
    if event_data.has("id"):
        msg += " ID: " + event_data.id
    _combat_log_messages.append(msg)
    _update_ascii_display()

# --- Helper to change input mode ---
func set_input_mode(mode: InputMode) -> void:
    _current_input_mode = mode
    match mode:
        InputMode.MODE_MOVEMENT:
            _potential_target_pos = _player_actor.grid_pos
        InputMode.MODE_TARGETING:
            _target_cursor_pos = _player_actor.grid_pos
        _:
            pass
    _combat_log_messages.append("Mode: " + InputMode.keys()[mode])
    _update_ascii_display()

func show_menu(items: Array[String]) -> void:
    _current_menu_items = items
    _selected_menu_item_index = 0
    set_input_mode(InputMode.MODE_MENU)

func start_command_input() -> void:
    _command_input_string = ""
    set_input_mode(InputMode.MODE_COMMAND_INPUT)

# --- Quit ASCII Mode ---
func quit_ascii_mode() -> void:
    if _input_thread and _input_thread.is_started():
        _input_thread.wait_to_finish()
    get_tree().quit()
