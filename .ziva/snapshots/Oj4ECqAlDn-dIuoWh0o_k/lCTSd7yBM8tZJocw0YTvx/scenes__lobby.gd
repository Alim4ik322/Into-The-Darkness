extends Node2D
@onready var player_class_label = $CanvasLayer/Label2

func update_player_class(ClassName: String) -> void:
	player_class_label.text = ClassName
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
