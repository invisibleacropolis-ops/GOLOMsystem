extends RichTextLabel
class_name EventLogUI

## UI helper for displaying runtime events.
##
## Attach this script to a `RichTextLabel` to turn it into a scrolling
## event log. Other systems can call `append_entry()` with a structured
## dictionary to display activity in real time. Entries are cached so
## filters can be applied after the fact.

var entries: Array = []
var type_filter: Array = []


## Append a new event dictionary to the log and render it if permitted
## by the current filter.
func append_entry(evt: Dictionary) -> void:
	entries.append(evt)
	if _passes_filter(evt):
		_append_formatted(evt)


## Replace the allowed event types. Passing an empty array shows all
## events.
func set_type_filter(types: Array) -> void:
	type_filter = types.duplicate()
	_rebuild()


## Clear all entries and filter settings.
func clear() -> void:
	entries.clear()
	type_filter.clear()
	text = ""


func _passes_filter(evt: Dictionary) -> bool:
	return type_filter.is_empty() or evt.get("t", "") in type_filter


func _append_formatted(evt: Dictionary) -> void:
	append_text(_format(evt) + "\n")
	# Scroll to show the most recent entry.
	scroll_to_line(get_line_count())


func _format(evt: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(evt.get("t", "event")))
	if evt.has("actor"):
		parts.append(str(evt.actor))
	if evt.has("pos"):
		parts.append(str(evt.pos))
	if evt.has("data"):
		parts.append(JSON.stringify(evt.data))
	return " | ".join(parts)


func _rebuild() -> void:
	text = ""
	for e in entries:
		if _passes_filter(e):
			_append_formatted(e)
