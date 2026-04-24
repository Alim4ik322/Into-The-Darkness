extends Node2D

@onready var player_class_label = $CanvasLayer/Label2
@onready var player_name_label = $CanvasLayer/Label
@onready var player_1_ui = $CanvasLayer/Player1 # Используем как общий заголовок или список
@onready var start_button = $CanvasLayer/StartButton

func _ready() -> void:
	if Global.is_host:
		start_button.disabled = false
		start_button.text = "START GAME"
	else:
		start_button.disabled = true
		start_button.text = "WAITING FOR HOST..."

	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	_update_lobby_ui()

func _on_player_connected(id: int):
	print("Player connected: ", id)
	if Global.is_host:
		# Хост отправляет новому игроку текущий список
		for p_id in Global.players:
			rpc_id(id, "set_player_class", p_id, Global.players[p_id]["class"])
	_update_lobby_ui()

func _on_player_disconnected(id: int):
	Global.players.erase(id)
	_update_lobby_ui()

func _update_lobby_ui():
	# Обновляем текст Player 1 и Player 2
	var text = "PLAYERS:\n"
	var count = 1
	# Сначала Хост (ID 1)
	if 1 in Global.players:
		text += "Player 1 (Host): " + Global.players[1].get("class", "Choosing...") + "\n"
	
	# Потом остальные
	for id in Global.players:
		if id != 1:
			count += 1
			text += "Player " + str(count) + ": " + Global.players[id].get("class", "Choosing...") + "\n"
	
	player_1_ui.text = text
	$CanvasLayer/PlayerCount.text = "Players: " + str(Global.players.size())

func update_player_class(ClassName: String) -> void:
	player_class_label.text = "You: " + ClassName
	Global.selected_class = ClassName
	rpc("set_player_class", multiplayer.get_unique_id(), ClassName)

@rpc("any_peer", "call_local")
func set_player_class(id: int, p_class: String):
	Global.players[id] = {"class": p_class}
	_update_lobby_ui()

func _on_exit_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _on_start_button_pressed() -> void:
	if Global.is_host:
		# Перед стартом убеждаемся, что у хоста тоже записан класс
		set_player_class(1, Global.selected_class)
		# Запускаем игру у всех
		rpc("start_game")

@rpc("any_peer", "call_local")
func start_game():
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_button_1_pressed() -> void:
	update_player_class("Warrior")

func _on_button_2_pressed() -> void:
	update_player_class("Mage")

func _on_button_3_pressed() -> void:
	update_player_class("Archer")

func _on_button_4_pressed() -> void:
	update_player_class("Bard")

func _on_button_5_pressed() -> void:
	update_player_class("Healer")

func _on_button_6_pressed() -> void:
	update_player_class("Monk")

func _on_button_7_pressed() -> void:
	update_player_class("Dark Mage")

func _on_button_8_pressed() -> void:
	update_player_class("Paladin")
