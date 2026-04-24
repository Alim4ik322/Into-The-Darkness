extends Node3D

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_spawn)
		_spawn(1)

func _spawn(id):
	var p_class = Global.players.get(id, {}).get("class", "Warrior")
	var scene = load("res://scenes/Warrior.tscn") if p_class == "Warrior" else load("res://scenes/Archer.tscn")
	var p = scene.instantiate()
	p.name = str(id)
	
	# ПОРЯДОК ПО ГОДОТУ: add_child -> position
	add_child(p, true)
	
	var marker = $Player if id == 1 else $Player2
	p.global_position = marker.global_position
	print("[DEBUG] Spawned ", id, " at ", p.global_position)
@onready var player2_marker = $Player2

func _ready() -> void:
	print("[DEBUG] World _ready. Is server: ", multiplayer.is_server(), " Unique ID: ", multiplayer.get_unique_id())
	
	await get_tree().process_frame
	
	if not multiplayer.is_server():
		print("[DEBUG] Client: Notifying server that I am ready...")
		rpc_id(1, "server_receive_ready", multiplayer.get_unique_id())
		return
	
	# Хост спавнит себя сразу
	var my_class = Global.players.get(1, {}).get("class", "Warrior")
	spawn_player(1, my_class, 0)

@rpc("any_peer", "call_local")
func server_receive_ready(peer_id: int):
	if not multiplayer.is_server(): return
	print("[DEBUG] Server: Peer ", peer_id, " is ready. Spawning character...")
	var p_class = Global.players.get(peer_id, {}).get("class", "Warrior")
	spawn_player(peer_id, p_class, 1)

func spawn_player(id: int, p_class: String, index: int):
	if has_node(str(id)): return
	
	var player_scene = load("res://scenes/Archer.tscn") if p_class == "Archer" else load("res://scenes/Warrior.tscn")
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	
	# Ставим власть на сервере
	new_player.set_multiplayer_authority(id)
	add_child(new_player, true)
	
	# Позиция
	var marker = player_marker if index == 0 else player2_marker
	if marker:
		new_player.global_position = marker.global_position
	
	print("[DEBUG] Server: Spawned player ", id, " (", p_class, ")")
