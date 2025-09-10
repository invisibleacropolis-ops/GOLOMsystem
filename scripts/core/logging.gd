extends RefCounted
class_name EventLogger

## Shared helper for writing structured events into a log array.
##
## Each event is a `Dictionary` with at least a short type identifier `t`.
## Optional fields:
##   - `actor`: the object responsible for the event
##   - `pos`:   a relevant grid position (Vector2i)
##   - `data`:  any additional payload
##
## Modules pass their `event_log` array along with the event details and this
## helper constructs and appends the dictionary. Centralising the logic keeps
## the schema consistent across modules so tests and tooling can rely on it.
static func log(event_log: Array, t: String, actor: Object = null, pos = null, data = null) -> void:
    var evt: Dictionary = {"t": t}
    if actor != null:
        evt["actor"] = actor
    if pos != null:
        evt["pos"] = pos
    if data != null:
        evt["data"] = data
    event_log.append(evt)
