extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	# Каждый игрок спавнит всех участников из Global.players
	# Это гарантирует, что все видят всех.
	for id in Global.players:
		spawn_player(id, Global.players[id]["class"])

func spawn_player(id: int, p_class: String):
	if has_node(str(id)):
		return
		
	var player_scene: PackedScene
	if p_class == "Archer":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Warrior.tscn")
	
	var new_player = player_scene.instantiate()
	new_player.name = str(id) # Устанавливаем имя ДО добавления в дерево
	add_child(new_player)
	
	new_player.global_position = player_marker.global_position + Vector3(id * 2, 0, 0)
	new_player.set_multiplayer_authority(id)
	
	print("Spawned player ", id, " (", p_class, ") at ", new_player.global_position)
