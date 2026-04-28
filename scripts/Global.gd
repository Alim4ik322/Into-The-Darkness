extends Node

var selected_class: String = "Warrior"
var is_host: bool = false

# Словарь для хранения данных игроков: { peer_id: { "class": "Warrior" } }
var players: Dictionary = {}

func _ready() -> void:
	# Предотвращаем падение FPS в фоновом окне (полезно для теста мультиплеера)
	OS.low_processor_usage_mode = false
