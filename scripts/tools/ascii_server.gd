extends SceneTree
## TCP server that exposes the ASCII console interface over the network.
## Clients receive periodic ASCII frames and may issue the same commands
## as the local console (`spawn`, `move_actor`, `action`, etc.).

var _gateway

var server := TCPServer.new()
var clients: Array[StreamPeerTCP] = []

const PORT := 3456
const FRAME_INTERVAL := 0.5

func _init() -> void:
    _gateway = get_tree().get_root().get_node_or_null("/root/AsciiGateway")
    var err := server.listen(PORT)
    if err != OK:
        push_error("Failed to listen on port %d" % PORT)
    call_deferred("_loop")

func _spawn_actor(name: String, pos: Vector2i) -> void:
    if _gateway:
        _gateway.spawn(name, pos)

func _move_actor(name: String, pos: Vector2i) -> void:
    if _gateway:
        _gateway.move_actor(name, pos)

func _remove_actor(name: String) -> void:
    if _gateway:
        _gateway.remove(name)

func _perform_action(name: String, id: String, payload) -> void:
    if _gateway:
        _gateway.perform(name, id, payload)

func _process_command(line: String) -> void:
    var parts := line.split(" ")
    if parts.size() >= 4 and parts[0] == "spawn":
        var pos := Vector2i(parts[2].to_int(), parts[3].to_int())
        _spawn_actor(parts[1], pos)
    elif parts.size() >= 4 and parts[0] == "move_actor":
        var pos := Vector2i(parts[2].to_int(), parts[3].to_int())
        _move_actor(parts[1], pos)
    elif parts.size() >= 5 and parts[0] == "action":
        var payload := Vector2i(parts[3].to_int(), parts[4].to_int())
        _perform_action(parts[1], parts[2], payload)
    elif parts.size() >= 3 and parts[0] == "action":
        _perform_action(parts[1], parts[2], null)
    elif parts.size() >= 2 and parts[0] == "remove":
        _remove_actor(parts[1])
    elif parts.size() >= 1 and parts[0] == "end_turn":
        if _gateway:
            _gateway.exec("end_turn")
    elif parts.size() >= 1 and parts[0] == "list":
        if _gateway:
            _send(_gateway.list())
    elif parts.size() >= 3:
        var pos := Vector2i(parts[1].to_int(), parts[2].to_int())
        match parts[0]:
            "select":
                if _gateway: _gateway.apply_input(pos, "select")
            "move":
                if _gateway: _gateway.apply_input(pos, "move")
            "target":
                if _gateway: _gateway.apply_input(pos, "target")
            "click":
                if _gateway: _gateway.apply_input(pos, "click")
            _:
                pass
    elif parts.size() >= 1 and parts[0] == "clear":
        if _gateway:
            _gateway.apply_input(Vector2i.ZERO, "clear")
    elif parts.size() >= 1 and parts[0] == "quit":
        _shutdown()

func _send(text: String) -> void:
    for i in range(clients.size() - 1, -1, -1):
        var c := clients[i]
        if c.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            c.put_utf8_line(text)
        else:
            clients.remove_at(i)

func _loop() -> void:
    while true:
        if server.is_connection_available():
            var c := server.take_connection()
            c.set_no_delay(true)
            clients.append(c)
        var frame := (_gateway.snapshot() if _gateway else "")
        _send(frame)
        for c in clients:
            var available := c.get_available_bytes()
            if available > 0:
                var data := c.get_utf8_string(available)
                for line in data.split("\n"):
                    line = line.strip_edges()
                    if line != "":
                        _process_command(line)
        await get_tree().create_timer(FRAME_INTERVAL).timeout

func _shutdown() -> void:
    for c in clients:
        c.disconnect_from_host()
    server.stop()
    quit()
