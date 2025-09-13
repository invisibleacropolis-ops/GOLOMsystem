Headless Tooling & Runner Scripts
=================================

This repository includes a suite of wrapper scripts and helpers designed to enable headless execution of the Godot 4 editor and runtime. This capability is crucial for automated testing, continuous integration (CI), documentation generation, and even playing the game in a text-based (ASCII) console. Headless operation means running Godot without a graphical user interface, which is faster, more resource-efficient, and ideal for server environments or automated workflows.

## Quick Setup

Before running the headless tools, you need to configure the path to your Godot executable.

*   **Configuration File:**
    *   Copy `scripts/godot4-config.example.json` to `scripts/godot4-config.json`.
    *   Edit `scripts/godot4-config.json` and set the `win_exe` field to the absolute path of your Godot 4 executable for Windows (e.g., `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe`).
    *   If you are using Windows Subsystem for Linux (WSL) or a Linux environment, also set `wsl_exe` to the path of your Linux Godot executable (e.g., `/mnt/f/AIstuff/FILES-FOR-MODELS/Godot_v4.4.1-stable_mono_linux.x86_64`).
*   **Optional Environment Variables:**
    *   Alternatively, you can set environment variables: `GODOT4_WIN_EXE`, `GODOT4_LINUX_EXE`, and `GODOT4_MODE` (set to `auto`, `wsl`, or `win`). These will override settings in `godot4-config.json`.
*   **Optional Bash/WSL Environment:**
    *   For bash/WSL users, copy `scripts/godot4.env.example` to `scripts/godot4.env` and edit it to configure environment-specific settings.

## Unified Runner (`godot4`)

The `godot4.ps1` (PowerShell for Windows) and `godot4.sh` (bash for Linux/WSL) scripts provide a unified way to invoke the Godot executable with various arguments. They abstract away the complexities of platform-specific paths and commands.

*   **Windows (PowerShell/cmd):**
    *   `pwsh -File scripts/godot4.ps1 --version` (to check Godot version)
    *   `scripts\godot4.cmd --headless --path . --script scripts/test_runner.gd` (to run tests headlessly)
*   **Linux/WSL (bash):**
    *   `bash scripts/godot4.sh --version`

**Notes:**
*   **Mode Selection:** The runner automatically selects the appropriate Godot executable based on your `godot4-config.json` or environment variables. You can force a specific mode with `-Mode win` or `-Mode wsl` in PowerShell.
*   **WSL Mono Build Dependencies:** If using WSL with the Mono build of Godot, ensure you have `.NET SDK 8+`, `libasound2`, and `libpulse0` installed. Otherwise, use `-Mode win` to run the Windows executable from WSL.

## Headless Workflows

These scripts automate common development tasks in a headless environment.

### Doctool XML Generation

*   **Script:** `scripts/doc_regen.ps1` (PowerShell) or `scripts/doc_regen.sh` (bash)
*   **Purpose:** These scripts automate the process of generating the XML API documentation files (like `Abilities.xml`, `Attributes.xml`, etc.) from the Godot project's GDScript code. These XML files are then used to create the human-readable HTML API documents.
*   **Command:**
    *   `pwsh -File scripts/doc_regen.ps1`
    *   `bash scripts/doc_regen.sh`
*   **How it works:** It invokes Godot in headless mode with the `--doctool` and `--gdscript-docs` arguments, instructing Godot to parse the GDScript files and output their API structure as XML.

### Tests + ASCII Smoke Test

*   **Script:** `pwsh -File scripts/run_headless.ps1 -Strict`
*   **Purpose:** This script runs the full suite of module tests and then initiates an ASCII smoke test of the game. It's designed for CI environments to quickly verify core functionality.
*   **How it works:** It calls `scripts/test_runner.gd` to execute all module tests. If successful, it then launches the game in headless ASCII mode, leveraging the `GridRealtimeRenderer` to output the game state to the console. It also writes logs to the `logs/` directory.

### ASCII Play

This allows you to interact with the game in a text-based terminal.

*   **Interactive Mode:**
    *   **Script:** `pwsh -File scripts/ascii_play.ps1`
    *   **Purpose:** Launches the game in headless ASCII mode, allowing direct keyboard input (`w`, `a`, `s`, `d` for movement, `quit` to exit) to control the player character. This is useful for quick manual testing or demonstration without a GUI.
    *   **How it works:** It runs `scripts/tools/ascii_console.gd` (which internally uses `GridRealtimeRenderer`'s `update_input()` method) to process commands and display the ASCII grid.
*   **Piped (Non-Interactive) Mode:**
    *   **Purpose:** Enables automated interaction with the ASCII game by piping commands from a file. This is ideal for creating automated gameplay demonstrations or complex test scenarios.
    *   **Preparation:** Prepare your sequence of commands in a text file (e.g., `logs/ascii_commands.txt`). See `scripts/run_headless.ps1` for an example of command formatting.
    *   **Commands:**
        *   `pwsh -File scripts/ascii_play.ps1 -Pipe`
        *   `PIPE=1 bash scripts/ascii_play.sh < logs/ascii_commands.txt`
    *   **How it works:** The `ascii_play` script reads commands from standard input, feeding them to the headless game instance. This allows for precise, repeatable control over the game's actions.

## Direct Godot Executable Examples (for troubleshooting)

These commands show how to directly invoke the Godot executable with specific arguments, bypassing the runner scripts. This is useful for debugging setup issues or understanding the underlying commands.

*   `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --doctool docs/api --gdscript-docs res://scripts/modules`
    *   **Explanation:** Runs Godot headlessly, sets the project path, and generates XML API documentation for GDScript modules into `docs/api`.
*   `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --script scripts/test_runner.gd`
    *   **Explanation:** Runs Godot headlessly, sets the project path, and executes the `test_runner.gd` script, which in turn runs all module self-tests.
*   `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --script scripts/tools/ascii_console.gd`
    *   **Explanation:** Runs Godot headlessly, sets the project path, and directly executes the `ascii_console.gd` script, which provides the interactive ASCII game experience.

All generated logs and output from these headless operations are typically stored under the `logs/` directory, providing a record for review and debugging.