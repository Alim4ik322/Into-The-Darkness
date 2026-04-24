extends Node3D

@onready var player_marker = $Player
@onready var player2_marker = $Player2

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
	
	# ВАЖНО: сначала добавляем в дерево, потом ставим позицию
	add_child(new_player)
	
	# Ставим власть
	new_player.set_multiplayer_authority(id)
	
	# Устанавливаем позицию
	if index == 0:
		new_player.global_position = player_marker.global_position
	elif has_node("Player2"):
		new_player.global_position = $Player2.global_position
	else:
		new_player.global_position = player_marker.global_position + Vector3(index * 2, 0, 0)
	
	print("Spawned player ", id, " (", p_class, ") at index ", index)
