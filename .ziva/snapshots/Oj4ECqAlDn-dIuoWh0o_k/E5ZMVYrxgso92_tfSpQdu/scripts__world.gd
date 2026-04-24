extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	var player_scene: PackedScene
	
	if Global.selected_class == "Лучник":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Player.tscn")
	
	var new_player = player_scene.instantiate()
	new_player.position = player_marker.position
	new_player.rotation = player_marker.rotation
	
	# Replace the marker player with the actual selected class
	player_marker.queue_free()
	add_child(new_player)
