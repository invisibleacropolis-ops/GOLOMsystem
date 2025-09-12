extends Node
## TCP server autoload that streams ASCII frames from the live game and
## accepts commands compatible with scripts/tools/ascii_console.gd.

var gateway: Node
var server := TCPServer.new()
var clients: Array[StreamPeerTCP] = []
var client_authed: Array = []

var port: int = 3456
var frame_interval: float = 5.0
var bind_localhost_only := true
var _accum := 0.0
var enabled := true
var _token: String = ""
var _connected_to_timespace := false

func _ready() -> void:
    # Resolve config from ProjectSettings if present.
    if ProjectSettings.has_setting("ascii_stream/port"):
        port = int(ProjectSettings.get_setting("ascii_stream/port"))
    if ProjectSettings.has_setting("ascii_stream/frame_interval"):
        frame_interval = float(ProjectSettings.get_setting("ascii_stream/frame_interval"))
    if ProjectSettings.has_setting("ascii_stream/localhost_only"):
        bind_localhost_only = bool(ProjectSettings.get_setting("ascii_stream/localhost_only"))
    if ProjectSettings.has_setting("ascii_stream/token"):
        _token = String(ProjectSettings.get_setting("ascii_stream/token"))

    # Attempt to bind the server.
    var bind_addr := ("127.0.0.1" if bind_localhost_only else "0.0.0.0")
    var err := server.listen(port, bind_addr)
    if err != OK:
        push_error("AsciiStreamServer: Failed to listen on %s:%d (err=%d)" % [bind_addr, port, err])
    else:
        print("AsciiStreamServer: listening on %s:%d" % [bind_addr, port])

    gateway = get_tree().get_root().get_node_or_null("/root/AsciiGateway")
    set_process(true)
    _try_connect_timespace()

func _process(delta: float) -> void:
    # Accept new connections
    if server and server.is_connection_available():
        var c := server.take_connection()
        if c:
            c.set_no_delay(true)
            clients.append(c)
            # mark authed true if no token, otherwise require AUTH
            client_authed.append(_token == "")
            _send_line(c, "OK welcome")

    # Read any pending commands from clients
    for i in range(clients.size() - 1, -1, -1):
        var c: StreamPeerTCP = clients[i]
        if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
            clients.remove_at(i)
            client_authed.remove_at(i)
            continue
        var avail := c.get_available_bytes()
        if avail > 0:
            var data := c.get_utf8_string(avail)
            for line in data.split("\n"):
                line = String(line).strip_edges()
                if line != "":
                    _handle_command(i, line)

    # Send frames periodically
    _accum += delta
    if enabled and _accum >= frame_interval:
        _accum = 0.0
        if clients.size() > 0:
            var frame := _snapshot()
            if frame != "":
                _broadcast(frame)
    if not _connected_to_timespace:
        _try_connect_timespace()

func _snapshot() -> String:
    if gateway and gateway.has_method("snapshot"):
        return String(gateway.snapshot())
    return ""

func _broadcast(text: String) -> void:
    var payload := text
    if not text.ends_with("\n"):
        payload += "\n"
    for i in range(clients.size() - 1, -1, -1):
        var c: StreamPeerTCP = clients[i]
        if c.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            c.put_utf8_string(payload)
        else:
            clients.remove_at(i)

func _send_line(c: StreamPeerTCP, text: String) -> void:
    c.put_utf8_string(String(text) + "\n")

func _handle_command(idx: int, line: String) -> void:
    # Mirror ascii_console.gd commands
    var parts := line.split(" ")
    if parts.size() == 0:
        return
    var c: StreamPeerTCP = clients[idx]
    if parts[0].to_lower() == "help":
        _send_line(c, "OK commands: help|ping|rate HZ|pause on|off|auth TOKEN|spawn|move_actor|action|remove|end_turn|list|select|move|target|click|clear|quit")
        return
    if parts[0].to_lower() == "ping":
        _send_line(c, "OK pong")
        return
    if parts[0].to_lower() == "pause" and parts.size() >= 2:
        var on := parts[1].to_lower() in ["on","1","true","yes"]
        enabled = not on
        _send_line(c, "OK pause=" + ("on" if on else "off"))
        return
    if parts[0].to_lower() == "rate" and parts.size() >= 2:
        var hz := float(parts[1])
        set_frame_rate(max(0.01, hz))
        _send_line(c, "OK rate=" + parts[1])
        return
    if parts[0].to_lower() == "auth":
        if _token == "":
            _send_line(c, "OK no-auth-required")
            client_authed[idx] = true
        elif parts.size() >= 2 and parts[1] == _token:
            client_authed[idx] = true
            _send_line(c, "OK auth")
        else:
            _send_line(c, "ERR bad_token")
        return
    if parts[0] == "quit":
        # Client politely closes; no global shutdown
        _send_line(c, "OK bye")
        return
    # Require auth for game-affecting commands when token is set
    if not client_authed[idx]:
        _send_line(c, "ERR auth_required")
        return
    if gateway == null:
        gateway = get_tree().get_root().get_node_or_null("/root/AsciiGateway")
        if gateway == null:
            return

    if parts.size() >= 4 and parts[0] == "spawn":
        var pos := Vector2i(parts[2].to_int(), parts[3].to_int())
        gateway.spawn(parts[1], pos)
        _send_line(c, "OK spawn")
    elif parts.size() >= 4 and parts[0] == "move_actor":
        var pos2 := Vector2i(parts[2].to_int(), parts[3].to_int())
        gateway.move_actor(parts[1], pos2)
        _send_line(c, "OK move_actor")
    elif parts.size() >= 5 and parts[0] == "action":
        var payload := Vector2i(parts[3].to_int(), parts[4].to_int())
        gateway.perform(parts[1], parts[2], payload)
        _send_line(c, "OK action")
    elif parts.size() >= 3 and parts[0] == "action":
        gateway.perform(parts[1], parts[2], null)
        _send_line(c, "OK action")
    elif parts.size() >= 2 and parts[0] == "remove":
        gateway.remove(parts[1])
        _send_line(c, "OK remove")
    elif parts.size() >= 1 and parts[0] == "end_turn":
        gateway.exec("end_turn")
        _send_line(c, "OK end_turn")
    elif parts.size() >= 1 and parts[0] == "list":
        var out := String(gateway.list())
        _send_line(c, out)
    elif parts.size() >= 3:
        var pos3 := Vector2i(parts[1].to_int(), parts[2].to_int())
        match parts[0]:
            "select":
                gateway.apply_input(pos3, "select")
                _send_line(c, "OK select")
            "move":
                gateway.apply_input(pos3, "move")
                _send_line(c, "OK move")
            "target":
                gateway.apply_input(pos3, "target")
                _send_line(c, "OK target")
            "click":
                gateway.apply_input(pos3, "click")
                _send_line(c, "OK click")
            _:
                _send_line(c, "ERR unknown")
    elif parts.size() >= 1 and parts[0] == "clear":
        gateway.apply_input(Vector2i.ZERO, "clear")
        _send_line(c, "OK clear")

func _try_connect_timespace() -> void:
    if gateway == null:
        gateway = get_tree().get_root().get_node_or_null("/root/AsciiGateway")
    if gateway == null:
        return
    var runtime = null
    if gateway and gateway.get("runtime") != null:
        runtime = gateway.get("runtime")
    if runtime and runtime.timespace and not _connected_to_timespace:
        runtime.timespace.turn_ended.connect(_on_turn_event)
        runtime.timespace.round_started.connect(_on_turn_event)
        runtime.timespace.round_ended.connect(_on_turn_event)
        _connected_to_timespace = true

func _on_turn_event(arg = null) -> void:
    if not enabled:
        return
    var frame := _snapshot()
    if frame != "":
        _broadcast(frame)

func set_enabled(v: bool) -> void:
    enabled = v

func is_enabled() -> bool:
    return enabled

func get_port() -> int:
    return port

func set_frame_rate(hz: float) -> void:
    frame_interval = (1.0 / max(0.001, hz))

## Gracefully close any active client connections and stop the server.
func cleanup() -> void:
    for c in clients:
        c.disconnect_from_host()
    clients.clear()
    client_authed.clear()
    if server:
        server.stop()

func _exit_tree() -> void:
    cleanup()

