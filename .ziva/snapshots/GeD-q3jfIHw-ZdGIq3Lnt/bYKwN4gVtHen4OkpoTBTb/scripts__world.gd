extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	# Только Хост (Сервер) спавнит игроков
	if not multiplayer.is_server():
		return
		
	var index = 0
	for id in Global.players:
		spawn_player(id, Global.players[id]["class"], index)
		index += 1

func spawn_player(id: int, p_class: String, index: int = 0):
	if has_node(str(id)):
		return
		
	var player_scene: PackedScene
	if p_class == "Archer":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Warrior.tscn")
	
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	add_child(new_player)
	
	# Используем индекс для небольшого смещения и поднимаем повыше, чтобы не провалиться
	new_player.global_position = player_marker.global_position + Vector3(index * 1.5, 0.2, 0)
	new_player.set_multiplayer_authority(id)
	
	print("Spawned player ", id, " (", p_class, ") at index ", index)
