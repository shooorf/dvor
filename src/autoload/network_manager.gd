extends Node
## Сетевое ядро (ENet UDP Listen-Server + Offline Solo Sandbox).
## Управляет подключением друзей, профилями игроков, счётом и лентой событий.

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 16
const ARENA_SCENE_PATH: String = "res://src/world/arena_level.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://src/ui/main_menu.tscn"

signal players_updated()
signal connection_failed_msg(reason: String)
signal connection_status_msg(text: String)
signal killfeed_event(message: String, accent_color: Color)

## Локальные настройки игрока (редактируются в главном меню)
var local_profile: Dictionary = {
	"name": "Боец",
	"char_class": "knight", # knight | barbarian | rogue
	"color": Color(0.20, 0.58, 0.96),
}

## Словарь активных игроков: peer_id (int) -> Dictionary
var players: Dictionary = {}
var is_online_host: bool = false
var is_joining_client: bool = false
var active_port: int = DEFAULT_PORT
var disconnect_reason: String = ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_solo_sandbox() -> Error:
	shutdown_network()
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	is_online_host = false
	players.clear()
	players[1] = _make_player_entry(1, local_profile)
	players_updated.emit()
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
	return OK


func host_game(port: int = DEFAULT_PORT) -> Error:
	shutdown_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		connection_failed_msg.emit("Не удалось открыть UDP-порт %d (код ошибки: %d)" % [port, err])
		return err
	if peer.host != null:
		peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	is_online_host = true
	active_port = port
	players.clear()
	players[1] = _make_player_entry(1, local_profile)
	players_updated.emit()
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	shutdown_network()
	var clean_addr := address.strip_edges()
	if clean_addr.is_empty():
		clean_addr = "127.0.0.1"

	# Сначала загружаем сцену Арены на клиенте, чтобы PlayerSpawner и EntitySpawner
	# гарантированно существовали в /root/ArenaLevel до прихода первых пакетов репликации от Хоста.
	is_joining_client = true
	is_online_host = false
	active_port = port
	connection_status_msg.emit("Подключение к %s:%d..." % [clean_addr, port])
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
	_deferred_start_enet_client(clean_addr, port)
	return OK


func _deferred_start_enet_client(clean_addr: String, port: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_joining_client:
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(clean_addr, port)
	if err != OK:
		leave_to_main_menu("Не удалось создать клиент для %s:%d (код: %d)" % [clean_addr, port, err])
		return
	if peer.host != null:
		peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer


func shutdown_network() -> void:
	is_joining_client = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	is_online_host = false


func leave_to_main_menu(reason: String = "") -> void:
	disconnect_reason = reason
	shutdown_network()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func get_peer_ping_ms(peer_id: int) -> int:
	if peer_id == 1:
		return 0
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer is ENetMultiplayerPeer:
		var connected_peers := multiplayer.get_peers()
		var target_socket_id := peer_id if multiplayer.is_server() else (1 if peer_id == multiplayer.get_unique_id() else 0)
		if target_socket_id != 0 and target_socket_id in connected_peers:
			var enet_peer: ENetPacketPeer = (mp_peer as ENetMultiplayerPeer).get_peer(target_socket_id)
			if enet_peer != null and enet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
				return int(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return 0


func get_local_lan_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in IP.get_local_addresses():
		if ":" in addr or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		out.append(addr)
	return out


func _make_player_entry(peer_id: int, profile: Dictionary) -> Dictionary:
	var clean_name := String(profile.get("name", "Боец")).strip_edges().left(20)
	if clean_name.is_empty():
		clean_name = "Боец_%d" % peer_id
	var char_cls := String(profile.get("char_class", "knight"))
	if char_cls not in ["knight", "barbarian", "rogue"]:
		char_cls = "knight"
	var col: Color = profile.get("color", Color(0.25, 0.62, 0.96))
	return {
		"id": peer_id,
		"name": clean_name,
		"char_class": char_cls,
		"color": col,
		"kills": 0,
		"deaths": 0,
	}


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var left_name: String = "Игрок %d" % id
	if players.has(id):
		left_name = String(players[id].get("name", left_name))
		players.erase(id)
	_sync_players_rpc.rpc(players)
	broadcast_event("%s покинул арену" % left_name, Color(0.75, 0.75, 0.75))
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("server_despawn_player"):
		arena.call("server_despawn_player", id)


func _on_connected_to_server() -> void:
	is_joining_client = false
	connection_status_msg.emit("Соединение установлено! Вход на арену...")
	_server_register_player.rpc_id(1, local_profile)


func _on_connection_failed() -> void:
	leave_to_main_menu("Не удалось подключиться к серверу (проверьте IP, порт и VPN/брандмауэр).")


func _on_server_disconnected() -> void:
	leave_to_main_menu("Хост закрыл сервер или соединение было разорвано.")


@rpc("any_peer", "call_local", "reliable")
func _server_register_player(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		sender_id = 1
	var entry := _make_player_entry(sender_id, profile)
	players[sender_id] = entry
	_sync_players_rpc.rpc(players)
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("server_ensure_player_spawned"):
		arena.call("server_ensure_player_spawned", sender_id)
	broadcast_event("%s вошёл на арену!" % entry["name"], entry["color"])


@rpc("authority", "reliable")
func _client_load_arena() -> void:
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != ARENA_SCENE_PATH:
		get_tree().change_scene_to_file(ARENA_SCENE_PATH)


@rpc("any_peer", "reliable")
func notify_client_scene_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		sender_id = 1
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("server_ensure_player_spawned"):
		arena.call("server_ensure_player_spawned", sender_id)


@rpc("authority", "call_local", "reliable")
func _sync_players_rpc(new_players: Dictionary) -> void:
	players = new_players
	players_updated.emit()


func broadcast_event(message: String, color: Color = Color(0.95, 0.85, 0.55)) -> void:
	if multiplayer.is_server():
		_client_killfeed_rpc.rpc(message, color)


@rpc("authority", "call_local", "reliable")
func _client_killfeed_rpc(message: String, color: Color) -> void:
	killfeed_event.emit(message, color)


func server_record_kill(killer_id: int, victim_id: int, cause_label: String, victim_name_override: String = "") -> void:
	if not multiplayer.is_server():
		return

	var victim_name := victim_name_override
	if players.has(victim_id):
		players[victim_id]["deaths"] = int(players[victim_id]["deaths"]) + 1
		victim_name = String(players[victim_id]["name"])
	elif victim_name.is_empty():
		victim_name = "Манекен"

	var killer_name := ""
	var accent := Color(0.96, 0.62, 0.28)
	if killer_id > 0 and killer_id != victim_id and players.has(killer_id):
		if players.has(victim_id): # Фраги начисляем за реальных игроков (+ бонусом пишем и про манекен)
			players[killer_id]["kills"] = int(players[killer_id]["kills"]) + 1
		killer_name = String(players[killer_id]["name"])
		accent = players[killer_id]["color"]

	_sync_players_rpc.rpc(players)

	if killer_name.is_empty() or killer_id == victim_id:
		broadcast_event("%s погиб (%s)" % [victim_name, cause_label], Color(0.90, 0.42, 0.38))
	else:
		broadcast_event("%s -> %s [%s]" % [killer_name, victim_name, cause_label], accent)
