extends Node
## Utility node that builds API documentation during runtime.
##
## The generator performs three steps:
## 1. Invokes the Godot editor in headless mode to dump XML API docs for all
##    project scripts under `docs/api`.
## 2. Uses the upstream `make_rst.py` helper to convert XML docs to
##    reStructuredText in `docs/api_rst`.
## 3. Converts the RST files to HTML using a lightweight docutils wrapper,
##    storing the final human-readable docs in `docs/html`.
##
## The original XML files remain in `docs/api` so other tooling can continue
## to consume them.
class_name DocGenerator

## Generate XML, RST and HTML documentation for the project.
func generate_docs() -> void:
    var project_path := ProjectSettings.globalize_path("res://")
    var xml_dir := ProjectSettings.globalize_path("docs/api")
    var rst_dir := ProjectSettings.globalize_path("docs/api_rst")
    var html_dir := ProjectSettings.globalize_path("docs/html")

    DirAccess.make_dir_recursive_absolute(rst_dir)
    DirAccess.make_dir_recursive_absolute(html_dir)

    var output := []
    var args := ["--headless", "--path", project_path, "--doctool", xml_dir, "--gdscript-docs", project_path]
    var code := OS.execute("godot4", args, output, true)
    if code != OK:
        push_error("XML generation failed:\n" + "\n".join(output))
        return

    var env_args := ["PYTHONPATH=" + project_path, "python3", ProjectSettings.globalize_path("tools/make_rst.py"), "-o", rst_dir, xml_dir]
    output.clear()
    code = OS.execute("env", env_args, output, true)
    if code != OK:
        push_error("RST conversion failed:\n" + "\n".join(output))
        return

    args = [ProjectSettings.globalize_path("tools/rst_to_html.py"), rst_dir, html_dir]
    output.clear()
    code = OS.execute("python3", args, output, true)
    if code != OK:
        push_error("HTML build failed:\n" + "\n".join(output))
        return

