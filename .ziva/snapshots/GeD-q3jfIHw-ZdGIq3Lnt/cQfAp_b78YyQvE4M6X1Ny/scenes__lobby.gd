extends Node2D

@onready var player_class_label = $CanvasLayer/Label2

var host_btn: Button
var join_btn: Button
var ip_input: LineEdit

func _ready() -> void:
	# Программно добавляем кнопки для сетевой игры
	host_btn = Button.new()
	host_btn.text = "HOST GAME"
	host_btn.position = Vector2(800, 500)
	host_btn.size = Vector2(200, 50)
	host_btn.pressed.connect(_on_host_pressed)
	$CanvasLayer.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "JOIN GAME"
	join_btn.position = Vector2(800, 560)
	join_btn.size = Vector2(200, 50)
	join_btn.pressed.connect(_on_join_pressed)
	$CanvasLayer.add_child(join_btn)

	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.position = Vector2(800, 620)
	ip_input.size = Vector2(200, 30)
	$CanvasLayer.add_child(ip_input)
	
	# Скроем старую кнопку старта, чтобы не путаться
	if has_node("CanvasLayer/StartButton"):
		$CanvasLayer/StartButton.visible = false

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(1234, 2) # Макс 2 игрока
	if error != OK:
		print("Cannot host: ", error)
		return
	multiplayer.multiplayer_peer = peer
	# Добавляем себя (сервер) в список игроков
	Global.players[1] = {"class": Global.selected_class}
	# Переходим в мир сразу
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_join_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_input.text, 1234)
	if error != OK:
		print("Cannot join: ", error)
		return
	multiplayer.multiplayer_peer = peer
	
	# Ждем подключения, чтобы отправить свой класс
	multiplayer.connected_to_server.connect(_on_connected_ok)

func _on_connected_ok():
	# Отправляем серверу информацию о нашем классе через RPC
	# Но так как мы скоро сменим сцену, сделаем это в World.gd
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func update_player_class(ClassName: String) -> void:
	player_class_label.text = ClassName
	Global.selected_class = ClassName
func _on_exit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _on_start_button_pressed() -> void:
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
