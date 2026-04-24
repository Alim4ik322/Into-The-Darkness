extends Node

var selected_class: String = "Warrior"
var is_host: bool = false

# Словарь для хранения данных игроков: { peer_id: { "class": "Warrior" } }
var players: Dictionary = {}
