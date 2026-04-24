extends Node3D

@onready var player_marker = $Player

func _ready() -> void:
	# Каждый игрок спавнит всех участников из Global.players
	# Это гарантирует, что все видят всех.
	for id in Global.players:
		spawn_player(id, Global.players[id]["class"])

func spawn_player(id: int, p_class: String):
	# Если игрок уже существует, не спавним второй раз
	if has_node(str(id)):
		return
		
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
		# Пытаемся найти камеру (пути могут отличаться у воина и лучника, но я настроил их в скриптах)
		var camera = new_player.get_node_or_null("CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D")
		if camera: camera.current = true
		var ui = new_player.get_node_or_null("UI")
		if ui: ui.visible = true
	else:
		var camera = new_player.get_node_or_null("CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D")
		if camera: camera.current = false
		var ui = new_player.get_node_or_null("UI")
		if ui: ui.visible = false
