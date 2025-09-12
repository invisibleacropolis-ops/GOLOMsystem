extends Object
# `class_name` intentionally omitted to prevent lingering global class
# registrations during automated headless tests.

## Whitelist-based command parser for the developer console.
##
## This module centralizes parsing and execution of console commands so
## that the logic can be unit tested independently from the UI. Only
## explicitly supported commands are executed; everything else is rejected
## to avoid evaluating arbitrary code.

const COMMANDS := ["help", "stats", "reload"]

## Parse and execute a console command.
##
## @param input The raw command text entered by the user.
## @param context Optional node that provides functions like `get_stats` or
##        access to the scene tree for commands such as "reload".
## @return A string describing the result of the command. Empty when the
##         command produces no output.
static func run(input: String, context: Node = null) -> String:
    var parts := input.strip_edges().split(" ", false, 0)
    var cmd := parts[0] if parts.size() > 0 else ""
    match cmd:
        "help":
            # String.join is used instead of Array.join to maintain Godot 4 compatibility.
            # COMMANDS.join() is not available on plain arrays, so we let the separator
            # string perform the join operation.
            return "Available commands: %s" % ", ".join(COMMANDS)
        "stats":
            if context and context.has_method("get_stats"):
                return str(context.call("get_stats"))
            return "No stats available"
        "reload":
            if context:
                context.get_tree().reload_current_scene()
                return "Reloading scene"
            return "Reload unavailable"
        "":
            return ""
        _:
            return "Unknown command: %s" % cmd

## Basic unit tests to verify command parsing.
func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var log := ""

    var result := run("help")
    total += 1
    if result != "Available commands: help, stats, reload":
        failed += 1
        log += "help command failed\n"

    result = run("foo")
    total += 1
    if result != "Unknown command: foo":
        failed += 1
        log += "unknown command handling failed\n"

    return {"failed": failed, "total": total, "log": log}
