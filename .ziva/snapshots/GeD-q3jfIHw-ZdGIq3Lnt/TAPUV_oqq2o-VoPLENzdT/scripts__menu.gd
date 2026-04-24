extends Node

var ip_input: LineEdit

func _ready() -> void:
	# Добавляем поле ввода IP программно рядом с кнопкой Join
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "Enter IP..."
	ip_input.size = Vector2(200, 30)
	ip_input.position = Vector2(20, 20) # В углу, чтобы не мешать
	$UI.add_child(ip_input)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_start_button_pressed() -> void:
	# HOST GAME
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(1234, 2)
	if error != OK:
		print("Cannot host: ", error)
		return
	multiplayer.multiplayer_peer = peer
	Global.is_host = true
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_join_button_pressed() -> void:
	# JOIN GAME
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_input.text, 1234)
	if error != OK:
		print("Cannot join: ", error)
		return
	multiplayer.multiplayer_peer = peer
	Global.is_host = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
