extends Node3D

@onready var player_marker = $Player
@onready var player2_marker = $Player2

func _ready() -> void:
	print("[DEBUG] World _ready. Is server: ", multiplayer.is_server(), " Unique ID: ", multiplayer.get_unique_id())
	
	var spawner = $MultiplayerSpawner
	if spawner:
		# ПРИНУДИТЕЛЬНО ставим путь спавна на текущий узел (World)
		spawner.spawn_path = get_path()
		print("[DEBUG] MultiplayerSpawner configured to watch: ", spawner.spawn_path)
		
		spawner.add_spawnable_scene("res://scenes/Warrior.tscn")
		spawner.add_spawnable_scene("res://scenes/Archer.tscn")
		
		# Добавляем сигнал для отладки на клиенте
		spawner.spawned.connect(func(node): 
			print("[DEBUG] Client: RECEIVED SPAWNED NODE: ", node.name, " Authority: ", node.get_multiplayer_authority())
		)
	
	# Только Хост (Сервер) спавнит игроков
	if not multiplayer.is_server():
		print("[DEBUG] Client: I am in World. Waiting for server to spawn me.")
		# Сообщаем серверу, что мы готовы (необязательно, но полезно для отладки)
		rpc_id(1, "server_receive_ready", multiplayer.get_unique_id())
		return
	
	# Сервер ждет, пока игроки загрузят сцену
	print("[DEBUG] Server: Waiting for clients to load World scene...")
	await get_tree().create_timer(1.5).timeout
	
	_spawn_all_players()

@rpc("any_peer")
func server_receive_ready(peer_id: int):
	print("[DEBUG] Server: Peer ", peer_id, " confirmed they are in the World scene.")

func _spawn_all_players():
	print("[DEBUG] Server: Starting spawn for ", Global.players.size(), " players.")
	var index = 0
	for id in Global.players:
		spawn_player(id, Global.players[id].get("class", "Warrior"), index)
		index += 1

func spawn_player(id: int, p_class: String, index: int = 0):
	if has_node(str(id)):
		print("[DEBUG] Server: Node for player ", id, " already exists. Skipping.")
		return
		
	var player_scene: PackedScene
	if p_class == "Archer":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Warrior.tscn")
	
	var new_player = player_scene.instantiate()
	# Имя ноды ОБЯЗАТЕЛЬНО должно быть ID для правильной синхронизации власти
	new_player.name = str(id)
	
	# ВАЖНО: Ставим власть ДО добавления в дерево
	new_player.set_multiplayer_authority(id)
	
	# Добавляем в дерево. spawner автоматически подхватит
	add_child(new_player, true)
	
	# Устанавливаем позицию
	var pos = Vector3.ZERO
	if index == 0 and player_marker:
		pos = player_marker.global_position
	elif index == 1 and player2_marker:
		pos = player2_marker.global_position
	else:
		pos = Vector3(index * 3, 1, 0)
	
	new_player.global_position = pos
	print("[DEBUG] Server: Spawned player ", id, " at ", pos, " with name ", new_player.name)
