extends Node2D

@onready var p1_name_label = $CanvasLayer/Control/Player1_Name
@onready var p1_class_label = $CanvasLayer/Control/Player1_class
@onready var p_count_label = $CanvasLayer/Control/PlayerCount
@onready var start_button = $CanvasLayer/Control/StartButton

var p2_name_label: Label
var p2_class_label: Label

func _ready() -> void:
	# Настраиваем Player 2 labels программно
	if p1_name_label:
		p2_name_label = p1_name_label.duplicate()
		p2_class_label = p1_class_label.duplicate()
		
		# Сделаем их другого цвета для отличия
		p2_name_label.add_theme_color_override("font_color", Color.YELLOW)
		p2_class_label.add_theme_color_override("font_color", Color.YELLOW)
		
		$CanvasLayer/Control.add_child(p2_name_label)
		$CanvasLayer/Control.add_child(p2_class_label)
		
		# Сдвигаем вниз на 150 пикселей, чтобы точно не накладывались
		p2_name_label.position.y += 150
		p2_class_label.position.y += 150
		
		p2_name_label.text = "Waiting for Player 2..."
		p2_class_label.text = ""
	
	if Global.is_host:
		start_button.disabled = false
		start_button.text = "START GAME"
		# Хост добавляет себя
		Global.players[1] = {"class": Global.selected_class}
	else:
		start_button.disabled = true
		start_button.text = "WAITING FOR HOST..."

	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	_update_lobby_ui()

@rpc("any_peer")
func request_player_list(requester_id: int):
	if Global.is_host:
		for id in Global.players:
			rpc_id(requester_id, "set_player_class", id, Global.players[id]["class"])

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
	# Очистка перед обновлением
	p1_name_label.text = "Player 1 (Host)"
	p1_class_label.text = "Choosing..."
	p2_name_label.text = "Waiting for Player 2..."
	p2_class_label.text = ""
	
	# Обновляем Player 1 (Host всегда ID 1)
	if 1 in Global.players:
		p1_name_label.text = "Player 1 (Host)"
		p1_class_label.text = Global.players[1].get("class", "Choosing...")
	
	# Обновляем Player 2 (первый попавшийся в списке кроме 1)
	for id in Global.players:
		if id != 1:
			p2_name_label.text = "Player 2"
			p2_class_label.text = Global.players[id].get("class", "Choosing...")
			break
	
	p_count_label.text = "Players: " + str(Global.players.size())

func update_player_class(ClassName: String) -> void:
	Global.selected_class = ClassName
	# Если мы еще не создали сервер/клиент, просто выходим
	if multiplayer.multiplayer_peer == null:
		print("Сеть не создана, класс выбран локально: ", ClassName)
		return
		
	# Если сеть есть, шлем RPC
	rpc("set_player_class", multiplayer.get_unique_id(), ClassName)

@rpc("any_peer", "call_local")
func set_player_class(id: int, p_class: String):
	Global.players[id] = {"class": p_class}
	_update_lobby_ui()

func _on_exit_button_pressed() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/UI/Menu.tscn")

func _on_start_button_pressed() -> void:
	if Global.is_host:
		# Перед стартом убеждаемся, что у хоста тоже записан класс
		set_player_class(1, Global.selected_class)
		# Запускаем игру у всех
		rpc("start_game")

@rpc("any_peer", "call_local")
func start_game():
	print("[DEBUG] start_game RPC received! Unique ID: ", multiplayer.get_unique_id())
	get_tree().change_scene_to_file("res://scenes/Map/World.tscn")

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
