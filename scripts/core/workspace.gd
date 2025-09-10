extends Control

## Workspace launcher for running logic modules and their tests.
##
## Provides a minimal GUI that lists each loaded module, its load
## status, test result, and a button to view detailed test output.
## The workspace can run in headless mode, but defaults to showing
## the GUI when a display is available.

const MODULE_DIR = "res://scenes/modules"
const CONFIG_PATH := "user://workspace.cfg"

var module_scenes: Dictionary = {}
var module_ui := {}
var event_log: Array = []
var modules: Array = []
var module_list: VBoxContainer
var run_button: Button
var loop_check: CheckButton
var interval_spin: SpinBox
var module_field: LineEdit
var run_selected_button: Button
var loop_timer := Timer.new()

# New UI elements
var generate_docs_button: Button
var docs_status_label: Label
var benchmark_button: Button
var iterations_spinbox: SpinBox
var map_gen_button: Button
var map_width_spin: SpinBox
var map_height_spin: SpinBox
var map_seed_line: LineEdit
var map_renderer: Node
var console_input: LineEdit
var console_output: TextEdit
var benchmark_results: TextEdit
var export_benchmark_button: Button
var last_benchmark_data: Dictionary = {}


## Emitted after all requested modules finish executing their tests.
## The dictionary contains `{"failed": int, "total": int, "log": String}`.
signal tests_completed(result)

## Emitted whenever `log_event()` records a new entry.
##
## The event dictionary mirrors the structure appended to `event_log` so
## external observers (like the HUD) can react immediately without
## polling the log array.
signal event_logged(evt)

const Logging = preload("res://scripts/core/logging.gd")
const ConsoleCommands = preload("res://scripts/tools/console_commands.gd")

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
        # Build the event dictionary for both internal storage and any
        # listeners. While `Logging.log` already constructs this structure, we
        # duplicate the fields here so the emitted signal remains decoupled
        # from the `event_log` array implementation.
        var evt: Dictionary = {"t": t}
        if actor != null:
                evt["actor"] = actor
        if pos != null:
                evt["pos"] = pos
        if data != null:
                evt["data"] = data

        Logging.log(event_log, t, actor, pos, data)
        event_logged.emit(evt)
        WorkspaceDebugger.log_info(str(t))

func _ready() -> void:

    # Build the UI programmatically
    _build_ui()

    module_list = $Tabs/Modules/Scroll/ModuleList
    run_button = $TopBar/RunTests
    loop_check = $TopBar/LoopTests
    interval_spin = $TopBar/Interval
    module_field = $TopBar/ModuleField
    run_selected_button = $TopBar/RunSelected

    module_scenes = _discover_modules()
    add_child(loop_timer)
    loop_timer.one_shot = true
    loop_timer.timeout.connect(_on_loop_timeout)
    run_button.pressed.connect(func(): _run_module_tests())
    run_selected_button.pressed.connect(_on_run_selected)
    loop_check.toggled.connect(func(pressed):
            if pressed:
                _queue_loop()
            else:
                loop_timer.stop()
    )
    
    #    generate_docs_button.pressed.connect(_on_generate_docs_pressed)
    #    benchmark_button.pressed.connect(_on_benchmark_pressed)
    map_gen_button.pressed.connect(_on_map_gen_pressed)
    map_export_button.pressed.connect(_on_export_map_pressed)
    console_input.text_submitted.connect(_on_console_input)

    modules = _get_cli_modules()
    _load_config()
    if modules.is_empty():
        modules = module_scenes.keys()
    module_field.text = ",".join(modules)
    # `modules` is an array; wrap it in brackets so `%` receives a single
    # argument instead of treating the array as multiple placeholders.
    log_event("workspace_init", null, null, modules)
    await _run_module_tests()
    WorkspaceDebugger.log_info("All module tests executed")
    print("All module tests executed. Workspace running...")


func _build_ui():
    var top_bar = HBoxContainer.new()
    top_bar.name = "TopBar"
    add_child(top_bar)

    run_button = Button.new()
    run_button.name = "RunTests"
    run_button.text = "Run Tests"
    top_bar.add_child(run_button)

    loop_check = CheckButton.new()
    loop_check.name = "LoopTests"
    loop_check.text = "Loop"
    top_bar.add_child(loop_check)

    interval_spin = SpinBox.new()
    interval_spin.name = "Interval"
    interval_spin.min_value = 0.1
    interval_spin.max_value = 10
    interval_spin.step = 0.1
    interval_spin.value = 1
    top_bar.add_child(interval_spin)

    module_field = LineEdit.new()
    module_field.name = "ModuleField"
    module_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_bar.add_child(module_field)

    run_selected_button = Button.new()
    run_selected_button.name = "RunSelected"
    run_selected_button.text = "Run Selected"
    top_bar.add_child(run_selected_button)

    generate_docs_button = Button.new()
    generate_docs_button.name = "GenerateDocsButton"
    generate_docs_button.text = "Generate Docs"
    top_bar.add_child(generate_docs_button)

    docs_status_label = Label.new()
    docs_status_label.name = "DocsStatusLabel"
    top_bar.add_child(docs_status_label)

    benchmark_button = Button.new()
    benchmark_button.name = "BenchmarkButton"
    benchmark_button.text = "Run Benchmark"
    top_bar.add_child(benchmark_button)

    iterations_spinbox = SpinBox.new()
    iterations_spinbox.name = "IterationsSpinBox"
    iterations_spinbox.min_value = 1
    iterations_spinbox.max_value = 10000
    iterations_spinbox.value = 100
    top_bar.add_child(iterations_spinbox)

    var tabs = TabContainer.new()
    tabs.name = "Tabs"
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(tabs)

    # Modules Tab
    var modules_panel = VBoxContainer.new()
    modules_panel.name = "Modules"
    tabs.add_child(modules_panel)
    tabs.set_tab_title(tabs.get_tab_count() - 1, "Modules")
    var scroll = ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    modules_panel.add_child(scroll)
    module_list = VBoxContainer.new()
    module_list.name = "ModuleList"
    scroll.add_child(module_list)

    # Benchmark Tab
    var benchmark_panel = VBoxContainer.new()
    benchmark_panel.name = "Benchmark"
    tabs.add_child(benchmark_panel)
    tabs.set_tab_title(tabs.get_tab_count() - 1, "Benchmark")
    # TODO: Add benchmark results view

    # Map Generator Tab
    var map_gen_panel = VBoxContainer.new()
    map_gen_panel.name = "MapGenerator"
    tabs.add_child(map_gen_panel)
    tabs.set_tab_title(tabs.get_tab_count() - 1, "Map Generator")
    var map_controls = HBoxContainer.new()
    map_gen_panel.add_child(map_controls)
    map_width_spin = SpinBox.new()
    map_width_spin.value = 32
    map_controls.add_child(Label.new())
    map_controls.get_child(0).text = "Width:"
    map_controls.add_child(map_width_spin)
    map_height_spin = SpinBox.new()
    map_height_spin.value = 32
    map_controls.add_child(Label.new())
    map_controls.get_child(2).text = "Height:"
    map_controls.add_child(map_height_spin)
    map_seed_line = LineEdit.new()
    map_seed_line.text = "default"
    map_controls.add_child(Label.new())
    map_controls.get_child(4).text = "Seed:"
    map_controls.add_child(map_seed_line)
    map_gen_button = Button.new()
    map_gen_button.text = "Generate"
    map_controls.add_child(map_gen_button)
    map_export_button = Button.new()
    map_export_button.text = "Export"
    map_export_button.disabled = true
    map_controls.add_child(map_export_button)

    map_progress = ProgressBar.new()
    map_progress.visible = false
    map_progress.min_value = 0
    map_progress.max_value = 1
    map_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_gen_panel.add_child(map_progress)
    
    var map_viewport_container = SubViewportContainer.new()
    map_viewport_container.stretch = true
    map_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_gen_panel.add_child(map_viewport_container)

    var map_viewport = SubViewport.new()
    map_viewport_container.add_child(map_viewport)

    # Console Tab
    var console_panel = VBoxContainer.new()
    console_panel.name = "Console"
    tabs.add_child(console_panel)
    tabs.set_tab_title(tabs.get_tab_count() - 1, "Console")
    console_output = TextEdit.new()
    console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    console_output.editable = false
    console_panel.add_child(console_output)
    console_input = LineEdit.new()
    console_panel.add_child(console_input)



func _discover_modules() -> Dictionary:
    var modules: Dictionary = {}
    if not DirAccess.dir_exists_absolute(MODULE_DIR):
        push_warning("Modules directory not found: " + MODULE_DIR)
        return modules

    var files = DirAccess.get_files_at(MODULE_DIR)
    for file_name in files:
        if file_name.ends_with(".tscn"):
            var module_name = file_name.get_basename().get_file()
            # Make module name more friendly, e.g. "ModuleGridPanel" -> "grid_panel"
            module_name = module_name.trim_prefix("Module").to_snake_case()
            modules[module_name] = "%s/%s" % [MODULE_DIR, file_name]
    return modules


## Create a GUI row representing a module and store its widgets for later updates.
## A CheckBox lets engineers disable a module without editing the text field.
func _create_module_slot(module_key: String) -> void:
        var row := HBoxContainer.new()

        var checkbox := CheckBox.new()
        checkbox.button_pressed = true
        row.add_child(checkbox)

        var name_label := Label.new()
        name_label.text = module_key
        row.add_child(name_label)

        var load_label := Label.new()
        load_label.text = "Loading..."
        row.add_child(load_label)

        var result_label := Label.new()
        result_label.text = "Pending"
        row.add_child(result_label)

        var log_button := Button.new()
        log_button.text = "Show Log"
        log_button.disabled = true
        row.add_child(log_button)

        module_list.add_child(row)

        var dialog := AcceptDialog.new()
        dialog.title = module_key + " Test Log"
        var text := TextEdit.new()
        # Display-only log output
        text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        text.size_flags_vertical = Control.SIZE_EXPAND_FILL
        dialog.add_child(text)
        add_child(dialog)

        log_button.pressed.connect(func(): dialog.popup_centered_ratio())

        module_ui[module_key] = {
                "checkbox": checkbox,
                "load_label": load_label,
                "result_label": result_label,
                "log_button": log_button,
                "log_text": text,
        }

## Load the requested modules, execute their tests, and update the GUI.
## Unchecked modules are skipped, and unknown names trigger a warning.
func _run_module_tests(benchmark_iterations := 1) -> Dictionary:
        for child in get_children():
                if child.name == "Tabs" or child.name == "TopBar" or child == loop_timer or child is AcceptDialog:
                        continue
                child.queue_free()

        var mods_to_run: Array = []
        var unknown: Array[String] = []
        for module_key in modules:
                if not module_scenes.has(module_key):
                        unknown.append(module_key)
                        continue
                if not module_ui.has(module_key):
                        _create_module_slot(module_key)
                var ui = module_ui[module_key]
                ui.load_label.text = "Loading..."
                ui.result_label.text = "Pending"
                ui.log_button.disabled = true
                ui.log_text.text = ""
                if ui.checkbox.button_pressed:
                        mods_to_run.append(module_key)
                else:
                        ui.load_label.text = "Skipped"
                        ui.result_label.text = "Skipped"

        if not unknown.is_empty():
                var msg := "Unknown modules: %s" % ", ".join(unknown)
                push_warning(msg)
                WorkspaceDebugger.log_error(msg)

        var total_time = 0.0
        var summary
        var module_time_totals: Dictionary = {}
        for i in range(benchmark_iterations):
                var start_time = Time.get_ticks_usec()
                summary = await _load_modules(mods_to_run)
                total_time += (Time.get_ticks_usec() - start_time) / 1000.0
                if summary.has("timings"):
                        for k in summary.timings.keys():
                                module_time_totals[k] = module_time_totals.get(k, 0.0) + summary.timings[k]


    if benchmark_iterations > 1:
        print("Benchmark finished. Total time: %.2f ms, Average: %.2f ms" % [total_time, total_time / benchmark_iterations])

    if loop_check.button_pressed:
        _queue_loop()
    _save_config()
    emit_signal("tests_completed", summary)


func _on_run_selected() -> void:
    var list := module_field.text.strip_edges()
    if list == "":
        modules = module_scenes.keys()
    else:
        modules = list.split(",", false)
    _run_module_tests()

## Internal helper to load and test modules once.
## Displays inline errors when a scene cannot be loaded.
func _load_modules(mods: Array) -> Dictionary:
        var total := 0
        var failed := 0
        var logs: Array[String] = []
        var timings: Dictionary = {}
        for module_key in mods:
                var module_start := Time.get_ticks_usec()
                var ui = module_ui[module_key]
                var scene_path: String = module_scenes[module_key]
                var scene: PackedScene = load(scene_path)
                if scene == null:
                        var err_msg := "Failed to load scene: %s" % scene_path
                        WorkspaceDebugger.log_error(err_msg)
                        ui.load_label.text = "Error"
                        ui.result_label.text = "Load failed"
                        ui.log_text.text = err_msg
                        ui.log_button.disabled = false
                        timings[module_key] = (Time.get_ticks_usec() - module_start) / 1000.0
                        continue

                var instance: Node = scene.instantiate()
                add_child(instance)
                ui.load_label.text = "Loaded"
                log_event("%s module loaded" % module_key)

                if instance.has_method("run_tests"):
                        var result = await instance.call("run_tests")
                        if result is Dictionary and result.has("failed") and result.has("total"):
                                var status := "PASS" if int(result.failed) == 0 else "FAIL"
                                ui.result_label.text = "%s (%d/%d)" % [status, result.failed, result.total]
                                if result.has("log"):
                                        ui.log_text.text = str(result.log)
                                        ui.log_button.disabled = false
                                log_event("%s tests %s (%d/%d)" % [module_key, status, result.failed, result.total])
                                print("%s: %s (%d/%d)" % [module_key, status, result.failed, result.total])
                                total += int(result.total)
                                failed += int(result.failed)
                                if result.failed > 0 and result.has("log"):
                                        logs.append("%s:\n%s" % [module_key, str(result.log)])
                        else:
                                ui.result_label.text = "Unknown"
                                log_event("%s tests produced unknown results" % module_key)
                else:
                        ui.result_label.text = "No tests"
                        log_event("%s has no tests" % module_key)
                timings[module_key] = (Time.get_ticks_usec() - module_start) / 1000.0
        return {
                "failed": failed,
                "total": total,
                "log": "\n\n".join(logs),
                "timings": timings,
        }

func _queue_loop() -> void:
    loop_timer.wait_time = interval_spin.value
    loop_timer.start()

func _on_loop_timeout() -> void:
    if loop_check.button_pressed:
        await _run_module_tests()

func _on_generate_docs_pressed():
    docs_status_label.text = "Generating..."
    generate_docs_button.disabled = true
    # This will be implemented by the agent running a shell command.
    # For now, we'll just show a message.
    await get_tree().create_timer(0.1).timeout
    docs_status_label.text = "Requesting doc generation..."


func _on_benchmark_pressed() -> void:
	var list := module_field.text.strip_edges()
	if list == "":
		modules = module_scenes.keys()
	else:
		modules = list.split(",", false)
	var result = await _run_module_tests(iterations_spinbox.value)
	if benchmark_results:
		var text := "Benchmark results (%d iterations):\n" % iterations_spinbox.value
		for module_key in result.module_averages.keys():
			text += "%s: %.2f ms\n" % [module_key, result.module_averages[module_key]]
		text += "Average total: %.2f ms\n" % result.average_time
		benchmark_results.text = text
	last_benchmark_data = result

## Export the most recent benchmark data to `user://` for external analysis.
func _on_export_benchmark_pressed() -> void:
	if last_benchmark_data.is_empty():
		return
	var file_path := "user://benchmark_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(last_benchmark_data))
		file.close()
		print("Benchmark data saved to %s" % file_path)

func _on_map_gen_pressed():
	if map_renderer:
		map_renderer.queue_free()

	var pw_scene = load("res://scenes/modules/ProceduralWorld.tscn")
	var pw = pw_scene.instantiate()
	
	var result = pw.generate(map_width_spin.value, map_height_spin.value, map_seed_line.text)
	pw.queue_free()

	var renderer_scene = load("res://scenes/modules/GridRealtimeRenderer.tscn")
	map_renderer = renderer_scene.instantiate()
	var map_viewport = $Tabs/MapGenerator/SubViewport
	map_viewport.add_child(map_renderer)
	
	map_renderer.grid_size = Vector2i(map_width_spin.value, map_height_spin.value)
	map_renderer.apply_color_map(result.colors)


func _on_console_input(text: String):
        console_output.append_text("> " + text + "\n")
        console_input.clear()

        var result := ConsoleCommands.run(text, self)
        if not result.is_empty():
                console_output.append_text(result + "\n")


## Public helper so external scenes can enable continuous test looping
## without relying on GUI interaction.
func start_loop(interval: float = 1.0) -> void:
    loop_check.button_pressed = true
    interval_spin.value = interval
    _queue_loop()

## Parse command-line flags to determine which modules to load.
func _get_cli_modules() -> Array:
    var cli_modules: Array = []
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        var arg: String = args[i]
        var value: String
        if arg.begins_with("--module="):
            cli_modules.append(arg.trim_prefix("--module="))
        elif arg.begins_with("--modules="):
            cli_modules.append_array(arg.trim_prefix("--modules=").split(",", false))
        elif (arg == "--module" or arg == "--modules") and i + 1 < args.size():
            value = args[i + 1]
            i += 1 # Consume next arg as value
            if arg == "--module": cli_modules.append(value)
            else: cli_modules.append_array(value.split(",", false))
        i += 1
    return cli_modules

func _load_config() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONFIG_PATH) == OK:
        interval_spin.value = cfg.get_value("workspace", "interval", interval_spin.value)
        var saved: Array = cfg.get_value("workspace", "modules", [])
        if saved.size() > 0 and modules.is_empty():
            modules = saved # Note: `modules` is the instance variable

func _save_config() -> void:

    var cfg := ConfigFile.new()
    cfg.set_value("workspace", "interval", interval_spin.value)
    cfg.set_value("workspace", "modules", modules)
    cfg.save(CONFIG_PATH)
