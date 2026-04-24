extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	print("LOBBY SELECTED CLASS: ", Global.selected_class)
	var player_scene: PackedScene
	
	if Global.selected_class == "Archer":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Warrior.tscn")
	
	var new_player = player_scene.instantiate()
	new_player.position = player_marker.position
	new_player.rotation = player_marker.rotation
	
	# Add the player to the world
	add_child(new_player)
	
	# The marker is just a position now, we can hide it or leave it (it's a Marker3D)
	# But in our case player_marker is the node we found in _ready
