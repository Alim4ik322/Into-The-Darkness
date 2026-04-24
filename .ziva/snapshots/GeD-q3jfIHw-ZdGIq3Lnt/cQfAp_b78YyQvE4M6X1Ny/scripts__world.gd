extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	# Если мы сервер, спавним себя
	if multiplayer.is_server():
		spawn_player(1, Global.selected_class)
	else:
		# Если клиент, сообщаем серверу свой выбор
		inform_server.rpc_id(1, Global.selected_class)

@rpc("any_peer")
func inform_server(p_class: String):
	if multiplayer.is_server():
		var id = multiplayer.get_remote_sender_id()
		spawn_player(id, p_class)

func spawn_player(id: int, p_class: String):
	var player_scene: PackedScene
	if p_class == "Archer":
		player_scene = load("res://scenes/Archer.tscn")
	else:
		player_scene = load("res://scenes/Warrior.tscn")
	
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	new_player.position = player_marker.position
	
	add_child(new_player)
	
	# Устанавливаем владельца
	new_player.set_multiplayer_authority(id)
	
	# Если это мы, включаем камеру и UI
	if id == multiplayer.get_unique_id():
		new_player.get_node("CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D").current = true
		new_player.get_node("UI").visible = true
	else:
		new_player.get_node("CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D").current = false
		new_player.get_node("UI").visible = false
