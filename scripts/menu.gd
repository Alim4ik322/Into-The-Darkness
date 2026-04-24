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
	# Принудительно очищаем старые соединения
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Ждем один кадр, чтобы сокет точно освободился (на всякий случай)
	await get_tree().process_frame
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(1234, 2)
	
	if error != OK:
		# Если порт занят, сообщаем об этом
		print("ERROR: Cannot host on port 1234. Is another game running?")
		print("Error code: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	Global.is_host = true
	# Инициализируем список игроков
	Global.players = {1: {"class": "Choosing..."}}
	get_tree().change_scene_to_file("res://scenes/UI/lobby.tscn")

func _on_join_button_pressed() -> void:
	print("[DEBUG] Join button pressed. IP: ", ip_input.text)
	# JOIN GAME
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_input.text, 1234)
	if error != OK:
		print("Cannot connect: ", error)
		return
	multiplayer.multiplayer_peer = peer
	Global.is_host = false
	get_tree().change_scene_to_file("res://scenes/UI/lobby.tscn")
