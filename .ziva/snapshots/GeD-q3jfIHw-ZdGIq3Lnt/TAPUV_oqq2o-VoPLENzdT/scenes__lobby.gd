extends Node2D

@onready var player_class_label = $CanvasLayer/Label2
@onready var start_button = $CanvasLayer/StartButton

func _ready() -> void:
	# Настраиваем видимость кнопки старта: только для хоста
	if Global.is_host:
		start_button.disabled = false
		start_button.text = "START GAME"
	else:
		start_button.disabled = true
		start_button.text = "WAITING FOR HOST..."

	# Сигналы сети
	multiplayer.peer_connected.connect(_on_player_connected)
	
	# Если мы хост, добавляем себя сразу
	if Global.is_host:
		_add_player_info(1, Global.selected_class)

func _on_player_connected(id: int):
	print("Player connected: ", id)
	# Если мы хост, отправляем новому игроку данные о текущих игроках
	if Global.is_host:
		for p_id in Global.players:
			rpc_id(id, "set_player_class", p_id, Global.players[p_id]["class"])

func _add_player_info(id: int, p_class: String):
	Global.players[id] = {"class": p_class}

func update_player_class(ClassName: String) -> void:
	player_class_label.text = ClassName
	Global.selected_class = ClassName
	# Синхронизируем свой выбор с другими (опционально для лобби, но важно для спавна)
	rpc("set_player_class", multiplayer.get_unique_id(), ClassName)

@rpc("any_peer", "call_local")
func set_player_class(id: int, p_class: String):
	Global.players[id] = {"class": p_class}
	print("Player ", id, " selected ", p_class)

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
