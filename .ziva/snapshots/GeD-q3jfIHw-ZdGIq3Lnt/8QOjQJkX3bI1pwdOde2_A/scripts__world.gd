extends Node3D

func _ready():
	# Только сервер спавнит игроков
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_spawn)
		_spawn(1) # Спавним хоста

func _spawn(id):
	# Получаем класс (по умолчанию Воин)
	var p_data = Global.players.get(id, {})
	var p_class = p_data.get("class", "Warrior")
	
	var scene_path = "res://scenes/Warrior.tscn" if p_class == "Warrior" else "res://scenes/Archer.tscn"
	var scene = load(scene_path)
	var p = scene.instantiate()
	
	# Имя узла = ID (для синхронизации)
	p.name = str(id)
	
	# Сначала добавляем в дерево
	add_child(p, true)
	
	# Потом ставим в позицию метки
	var marker = $Player if id == 1 else $Player2
	if marker:
		p.global_position = marker.global_position
