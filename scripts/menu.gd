extends Node

var ip_input: LineEdit

func _ready() -> void:
	OS.low_processor_usage_mode = false
	Engine.max_fps = 60
	# Добавляем поле ввода IP программно рядом с кнопкой Join
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "Enter IP..."
	ip_input.size = Vector2(200, 30)
	ip_input.position = Vector2(20, 20) # В углу, чтобы не мешать
	$UI.add_child(ip_input)
	
	# Добавляем надпись с вашим текущим IP
	var my_ip_label = Label.new()
	var current_ip = _get_local_ip()
	my_ip_label.text = "Ваш IP: " + current_ip
	my_ip_label.position = Vector2(20, 60) # Чуть ниже поля ввода
	my_ip_label.add_theme_color_override("font_color", Color.CYAN)
	$UI.add_child(my_ip_label)

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169."):
			return ip
	return "Unknown"

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
