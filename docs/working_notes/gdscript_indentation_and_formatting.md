GDScript Indentation & Formatting — Working Notes
=================================================

Context
-------
We hit multiple parser errors while evolving the ASCII engine and tests. The root causes were mixed indentation (tabs vs spaces) and single‑line control flow that GDScript doesn’t accept. This document encodes the rules, examples, and a checklist to prevent regressions.

Rules (Project Policy)
----------------------
1) Tabs only for indentation in .gd files
   - Enforced via .editorconfig override: `indent_style = tab` for `*.gd`.
   - Do not indent blank lines; avoid stray spaces before or after tabs.
   - Never mix tabs and spaces within the same block.

2) Multi‑line blocks for control flow
   - Avoid single‑line `if ...: ... else: ...` constructs.
   - Always break after `if/elif/else` and indent the body with tabs.

3) Consistent dedent
   - Dedent must match the previous indentation level exactly (tabs count, not spaces).
   - Don’t leave invisible indentation on otherwise blank lines.

4) Prefer print() for terminal output
   - Avoid non‑portable `OS.stdout_write()` usage; use `print()` or structured logs.
   - For interactive console input, prefer `OS.read_string_from_stdin()` over raw stdin byte loops unless absolutely necessary.

5) Defer child adds during startup
   - During `_ready()` for autoloads or root‑level initializers, use `call_deferred("add_child", child)` to avoid “Parent is busy setting up children” warnings.

Errors Encountered and Fixes
----------------------------
1) “Used space character for indentation instead of tab as used before in the file.”
   - Where: `scripts/modules/turn_timespace.gd` and `scripts/tools/ascii_console.gd` while patching blocks.
   - Cause: editor inserted spaces due to root `.editorconfig` default.
   - Fix: Converted affected lines to tabs; added `.editorconfig` override for `*.gd` so editors keep tabs.

2) “Expected statement, found ‘Indent’ instead.”
   - Cause: blank line contained indentation or a block started with extra indentation.
   - Fix: Removed indentation from blank lines; ensured block starts match parent.

3) “Unindent doesn't match the previous indentation level.”
   - Cause: dedent didn’t align with prior tab level after an `if/match` body.
   - Fix: Normalized dedent to the exact tab level of the surrounding block.

4) “Expected end of statement after expression, found ‘else’ instead.”
   - Cause: single‑line `if ... else: ...` form.
   - Fix: Rewrote to multi‑line `if:` body; `else:` body blocks with proper indentation.

5) “Static function 'stdout_write()' not found in base 'GDScriptNativeClass'.”
   - Cause: Using `OS.stdout_write()` (not universally available); and using static call semantics.
   - Fix: Replaced with `print()` and simplified input loop to `OS.read_string_from_stdin()`.

6) “Parent node is busy setting up children, add_child() failed.”
   - Cause: Adding children during autoload `_ready()` while SceneTree is initializing.
   - Fix: Use `call_deferred("add_child", child)` in autoloads (see `ascii_gateway.gd`).

7) “There is already a variable named ‘X’ declared in this scope.”
   - Cause: Reusing an identifier (e.g., `actor_res`) in the same function when refactoring.
   - Fix: Renamed the inner variable (e.g., to `actor_class`) to avoid shadowing.

Examples (Right vs Wrong)
-------------------------
Tabs vs spaces
```
# Wrong (mixed spaces) — will trigger the ‘space vs tab’ error
if cond:\n····print("Hi")

# Right (tabs only)
if cond:\n\tprint("Hi")
```

Single‑line if/else
```
# Wrong
if ok: do_thing() else: do_other()

# Right
if ok:
\tdo_thing()
else:
\tdo_other()
```

Blank line with indentation
```
# Wrong (indented blank line)
if a:
\tdo_x()
\t\n\tdo_y()

# Right (no indent on blank)
if a:
\tdo_x()
\n\tdo_y()
```

Autoload child add
```
# Wrong
get_tree().get_root().add_child(renderer)

# Right
get_tree().get_root().call_deferred("add_child", renderer)
```

Checklist Before Commit
-----------------------
- [ ] Indentation in .gd files uses tabs only (no spaces at line start).
- [ ] No single‑line `if ... else:` constructs.
- [ ] No indented blank lines; dedents align with prior block level.
- [ ] New autoloads and root initializers use `call_deferred` for child adds.
- [ ] Console I/O uses `print()` and `OS.read_string_from_stdin()` (no `stdout_write`).
- [ ] Run headless tests: `pwsh -File scripts/run_headless.ps1 -Strict` (expect `TOTAL: 0/63 failed`).

Editor Configuration
--------------------
`.editorconfig` has been updated to enforce tabs for `*.gd`:
```
[*.gd]
indent_style = tab
indent_size = 4
```

